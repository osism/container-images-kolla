#!/usr/bin/env bash

set -e

# Script to check if images from images.lst exist on external registry
# and re-push missing images using docker

# Available environment variables
#
# IMAGES_FILE       - Path to the images list file (default: images.lst)
# DRY_RUN          - Set to 'true' to only check without pushing (default: false)
# VERBOSE          - Set to 'true' for verbose output (default: false)
# CHECK_DIGESTS    - Set to 'true' to compare layer digests (default: false)

# Set default values
IMAGES_FILE=${IMAGES_FILE:-images.lst}
DRY_RUN=${DRY_RUN:-false}
VERBOSE=${VERBOSE:-false}
CHECK_DIGESTS=${CHECK_DIGESTS:-false}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output with consistent alignment
log_info() {
    printf "${BLUE}%-9s${NC} %s\n" "[INFO]" "$1"
}

log_success() {
    printf "${GREEN}%-9s${NC} %s\n" "[SUCCESS]" "$1"
}

log_warning() {
    printf "${YELLOW}%-9s${NC} %s\n" "[WARNING]" "$1"
}

log_error() {
    printf "${RED}%-9s${NC} %s\n" "[ERROR]" "$1"
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        printf "${BLUE}%-9s${NC} %s\n" "[VERBOSE]" "$1"
    fi
}

# Function to check if an image exists on the registry
check_image_exists() {
    local image="$1"
    log_verbose "Checking if image exists: $image"

    # Use docker manifest inspect to check if image exists
    # This is more reliable than docker pull for just checking existence
    if docker manifest inspect "$image" >/dev/null 2>&1; then
        log_verbose "Image exists: $image"
        return 0
    else
        log_verbose "Image does not exist: $image"
        return 1
    fi
}

# Function to check if image exists locally
check_local_image_exists() {
    local image="$1"
    log_verbose "Checking if local image exists: $image"

    if docker image inspect "$image" >/dev/null 2>&1; then
        log_verbose "Local image exists: $image"
        return 0
    else
        log_verbose "Local image does not exist: $image"
        return 1
    fi
}

# Function to get manifest digest for comparison
get_manifest_digest() {
    local image="$1"

    # Get the manifest digest using docker manifest inspect
    # Note: this may not return .digest for all registry types
    local manifest_json
    manifest_json=$(docker manifest inspect "$image" 2>/dev/null)

    if [[ -n "$manifest_json" ]]; then
        # Try to get digest from manifest
        local digest
        digest=$(echo "$manifest_json" | jq -r '.digest // empty' 2>/dev/null)

        if [[ "$digest" != "empty" && "$digest" != "null" && -n "$digest" ]]; then
            echo "$digest"
        else
            # Calculate digest from manifest content itself
            echo "$manifest_json" | sha256sum | cut -d' ' -f1 | sed 's/^/sha256:/'
        fi
    fi
}

# Function to get repo digest from local image
get_local_repo_digest() {
    local image="$1"

    # Try to get the repo digest from the local image
    # This should match the manifest digest if the image was pulled from the same registry
    docker image inspect "$image" 2>/dev/null | jq -r '.[0].RepoDigests[]?' 2>/dev/null | grep -E "^${image%:*}@" | head -1 | cut -d'@' -f2
}

# Function to get detailed layer information for verbose output
get_layer_details() {
    local image="$1"
    local manifest_type="$2"  # "remote" or "local"

    if [[ "$manifest_type" == "remote" ]]; then
        # Get remote manifest layers with size and media type
        local manifest_json
        manifest_json=$(docker manifest inspect "$image" 2>/dev/null)

        if echo "$manifest_json" | jq -e '.manifests' >/dev/null 2>&1; then
            # This is a manifest list, get the first platform's manifest
            local platform_digest
            platform_digest=$(echo "$manifest_json" | jq -r '.manifests[0].digest' 2>/dev/null)
            if [[ -n "$platform_digest" && "$platform_digest" != "null" ]]; then
                # Get the actual manifest using the digest
                docker manifest inspect "${image%:*}@${platform_digest}" 2>/dev/null | jq -r '.layers[] | "  Layer: \(.digest) Size: \(.size) MediaType: \(.mediaType)"' 2>/dev/null
            fi
        else
            # This is a single manifest
            echo "$manifest_json" | jq -r '.layers[] | "  Layer: \(.digest) Size: \(.size) MediaType: \(.mediaType)"' 2>/dev/null
        fi
    else
        # Get local image layer information
        docker image inspect "$image" 2>/dev/null | jq -r '.[0].RootFS.Layers[] | "  DiffID: \(.)"' 2>/dev/null
        # Also show repo digests if available
        local repo_digests
        repo_digests=$(docker image inspect "$image" 2>/dev/null | jq -r '.[0].RepoDigests[]?' 2>/dev/null)
        if [[ -n "$repo_digests" ]]; then
            echo "$repo_digests" | while read -r digest; do
                echo "  RepoDigest: $digest"
            done
        fi
    fi
}

# Function to compare images by temporarily pulling and comparing image IDs
compare_layer_digests() {
    local image="$1"
    log_verbose "Comparing image content for: $image"

    # Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        log_warning "jq not available, skipping digest comparison for: $image"
        return 1
    fi

    # Get local image ID
    log_verbose "Getting local image ID..."
    local local_id
    local_id=$(docker image inspect "$image" --format '{{.Id}}' 2>/dev/null)

    if [[ -z "$local_id" ]]; then
        log_verbose "Local image not found: $image"
        return 1
    fi

    log_verbose "Local image ID: $local_id"

    # Create a temporary tag for the remote image with random ID
    local temp_remote_tag="${image%:*}:temp-remote-check-$$-$RANDOM"

    log_verbose "Pulling remote image to temporary tag: $temp_remote_tag"

    # Pull the remote image directly to temporary tag to avoid overwriting local
    if ! docker pull "$image" >/dev/null 2>&1; then
        log_verbose "Failed to pull remote image: $image"
        return 1
    fi

    # Tag the pulled image with temporary tag
    if ! docker tag "$image" "$temp_remote_tag" >/dev/null 2>&1; then
        log_verbose "Failed to create temporary tag: $temp_remote_tag"
        return 1
    fi

    # Add temporary tag to cleanup array
    temp_remote_tags+=("$temp_remote_tag")

    # Get the remote image ID from the temporary tag
    log_verbose "Getting remote image ID..."
    local remote_id
    remote_id=$(docker image inspect "$temp_remote_tag" --format '{{.Id}}' 2>/dev/null)

    log_verbose "Remote image ID: $remote_id"

    # Show detailed layer information in verbose mode
    if [[ "$VERBOSE" == "true" ]]; then
        log_verbose "=== REMOTE LAYER DETAILS (freshly pulled) ==="
        get_layer_details "$temp_remote_tag" "local"  # This is the freshly pulled remote image

        log_verbose "=== LOCAL LAYER DETAILS (original) ==="
        get_layer_details "$image" "local"  # This is the original local image

        log_verbose "=== END LAYER DETAILS ==="
    fi

    # Compare the image IDs
    if [[ "$local_id" == "$remote_id" ]]; then
        log_verbose "Image IDs match - images are identical: $image"
        return 0
    else
        log_verbose "Image IDs differ - images are different: $image"
        log_verbose "Local ID:  $local_id"
        log_verbose "Remote ID: $remote_id"
        return 1
    fi
}

# Function to push an image
push_image() {
    local image="$1"
    log_info "Pushing image: $image"

    if docker push "$image"; then
        log_success "Successfully pushed: $image"
        return 0
    else
        log_error "Failed to push: $image"
        return 1
    fi
}

# Main function
main() {
    log_info "Starting image registry check and re-push script"
    log_info "Images file: $IMAGES_FILE"
    log_info "Dry run mode: $DRY_RUN"
    log_info "Verbose mode: $VERBOSE"
    log_info "Check digests mode: $CHECK_DIGESTS"

    # Check if images file exists
    if [[ ! -f "$IMAGES_FILE" ]]; then
        log_error "Images file not found: $IMAGES_FILE"
        log_info "Expected format: one image per line, e.g.:"
        log_info "  osism.harbor.regio.digital/kolla/release/2025.1/sbom:7.2.0"
        log_info "  osism.harbor.regio.digital/kolla/release/2025.1/nova-compute:28.0.1.20251207"
        exit 1
    fi

    # Arrays to track images
    missing_images=()
    existing_images=()
    local_missing_images=()
    push_failed_images=()
    digest_mismatch_images=()
    temp_remote_tags=()

    log_info "Reading images from: $IMAGES_FILE"
    total_images=$(wc -l < "$IMAGES_FILE")
    log_info "Total images to check: $total_images"

    # Read and process each image
    current=0
    while IFS= read -r image || [[ -n "$image" ]]; do
        # Skip empty lines and comments
        [[ -z "$image" || "$image" =~ ^[[:space:]]*# ]] && continue

        # Remove any trailing whitespace
        image=$(echo "$image" | tr -d '[:space:]')

        current=$((current + 1))
        log_info "[$current/$total_images] Checking: $image"

        if check_image_exists "$image"; then
            log_success "[$current/$total_images] EXISTS: $image"

            # If digest checking is enabled, compare layer digests
            if [[ "$CHECK_DIGESTS" == "true" ]]; then
                if check_local_image_exists "$image"; then
                    if compare_layer_digests "$image"; then
                        existing_images+=("$image")
                        log_success "[$current/$total_images] DIGESTS MATCH: $image"
                    else
                        digest_mismatch_images+=("$image")
                        log_warning "[$current/$total_images] DIGEST MISMATCH: $image"

                        # Re-push due to digest mismatch
                        if [[ "$DRY_RUN" == "true" ]]; then
                            log_info "DRY RUN: Would push $image (digest mismatch)"
                        else
                            if push_image "$image"; then
                                log_success "Re-pushed due to digest mismatch: $image"
                            else
                                push_failed_images+=("$image")
                            fi
                        fi
                    fi
                else
                    existing_images+=("$image")
                    log_warning "[$current/$total_images] EXISTS but not available locally for digest check: $image"
                fi
            else
                existing_images+=("$image")
            fi
        else
            missing_images+=("$image")
            log_warning "[$current/$total_images] MISSING: $image"

            # Check if image exists locally before attempting to push
            if check_local_image_exists "$image"; then
                if [[ "$DRY_RUN" == "true" ]]; then
                    log_info "DRY RUN: Would push $image"
                else
                    if push_image "$image"; then
                        log_success "Re-pushed missing image: $image"
                    else
                        push_failed_images+=("$image")
                    fi
                fi
            else
                local_missing_images+=("$image")
                log_error "Image missing locally, cannot push: $image"
            fi
        fi
    done < "$IMAGES_FILE"

    # Summary report
    echo
    log_info "============== SUMMARY =============="
    log_info "Total images checked: $total_images"
    log_success "Images already on registry: ${#existing_images[@]}"
    log_info "Images missing from registry: ${#missing_images[@]}"

    if [[ "$CHECK_DIGESTS" == "true" ]]; then
        log_info "Images with digest mismatches: ${#digest_mismatch_images[@]}"
    fi

    if [[ ${#missing_images[@]} -gt 0 ]]; then
        echo
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "Images that would be pushed (missing):"
        else
            log_info "Images that needed re-pushing (missing):"
        fi
        for image in "${missing_images[@]}"; do
            echo "  - $image"
        done
    fi

    if [[ ${#digest_mismatch_images[@]} -gt 0 ]]; then
        echo
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "Images that would be pushed (digest mismatch):"
        else
            log_info "Images that needed re-pushing (digest mismatch):"
        fi
        for image in "${digest_mismatch_images[@]}"; do
            echo "  - $image"
        done
    fi

    if [[ ${#local_missing_images[@]} -gt 0 ]]; then
        echo
        log_error "Images missing locally (cannot push): ${#local_missing_images[@]}"
        for image in "${local_missing_images[@]}"; do
            echo "  - $image"
        done
    fi

    if [[ ${#push_failed_images[@]} -gt 0 ]]; then
        echo
        log_error "Images that failed to push: ${#push_failed_images[@]}"
        for image in "${push_failed_images[@]}"; do
            echo "  - $image"
        done
    fi

    # Cleanup temporary remote tags
    if [[ ${#temp_remote_tags[@]} -gt 0 ]]; then
        echo
        log_info "Cleaning up ${#temp_remote_tags[@]} temporary remote images..."
        for temp_tag in "${temp_remote_tags[@]}"; do
            log_verbose "Removing temporary tag: $temp_tag"
            docker rmi "$temp_tag" >/dev/null 2>&1 || log_verbose "Failed to remove: $temp_tag"
        done
        log_success "Cleanup completed"
    fi

    echo
    if [[ ${#push_failed_images[@]} -gt 0 || ${#local_missing_images[@]} -gt 0 ]]; then
        log_error "Script completed with errors"
        exit 1
    else
        log_success "Script completed successfully"
        exit 0
    fi
}

# Check if required tools are available
check_requirements() {
    local missing_tools=()

    if ! command -v docker >/dev/null 2>&1; then
        missing_tools+=("docker")
    fi

    if [[ "$CHECK_DIGESTS" == "true" ]] && ! command -v jq >/dev/null 2>&1; then
        missing_tools+=("jq")
    fi

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install the missing tools and try again"
        if [[ "$CHECK_DIGESTS" == "true" ]]; then
            log_error "Note: jq is required for digest comparison (-c/--check-digests)"
        fi
        exit 1
    fi
}

# Print usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Check if images from images.lst exist on external registry and re-push missing ones"
    echo
    echo "Options:"
    echo "  -f, --file FILE        Images file to process (default: images.lst)"
    echo "  -d, --dry-run          Only check, don't actually push images"
    echo "  -v, --verbose          Enable verbose output"
    echo "  -c, --check-digests    Compare layer digests between remote and local images"
    echo "  -h, --help             Show this help message"
    echo
    echo "Environment variables:"
    echo "  IMAGES_FILE           Path to images file"
    echo "  DRY_RUN              Set to 'true' for dry run mode"
    echo "  VERBOSE              Set to 'true' for verbose output"
    echo "  CHECK_DIGESTS        Set to 'true' to compare layer digests"
    echo
    echo "Example usage:"
    echo "  $0                           # Use default images.lst"
    echo "  $0 -f images.txt             # Use custom images file"
    echo "  $0 -d -v                     # Dry run with verbose output"
    echo "  $0 -c                        # Enable digest comparison"
    echo "  $0 -c -d -v                  # Digest check in dry run with verbose output"
    echo
    echo "Images file format:"
    echo "  One image per line, e.g.:"
    echo "  osism.harbor.regio.digital/kolla/release/2025.1/sbom:7.2.0"
    echo "  osism.harbor.regio.digital/kolla/release/2025.1/nova-compute:28.0.1.20251207"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file)
            IMAGES_FILE="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN="true"
            shift
            ;;
        -v|--verbose)
            VERBOSE="true"
            shift
            ;;
        -c|--check-digests)
            CHECK_DIGESTS="true"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Run the script
check_requirements
main

#!/usr/bin/env bash

set -x

# Available environment variables
#
# COSIGN_PARALLEL_JOBS - Number of parallel cosign signing jobs (default: 8)
# COSIGN_RETRIES      - Number of retries for failed signatures (default: 3)
# LSTFILE             - Images list file (default: images.lst)

# Set default values
COSIGN_PARALLEL_JOBS=${COSIGN_PARALLEL_JOBS:-8}
COSIGN_RETRIES=${COSIGN_RETRIES:-3}
LSTFILE=${LSTFILE:-images.lst}

# Check if images list file exists
if [[ ! -f "$LSTFILE" ]]; then
    echo "ERROR: Images list file not found: $LSTFILE"
    exit 1
fi

# Download cosign binary if not already present
if [[ ! -f "cosign-linux-amd64" ]]; then
    echo "Downloading cosign binary..."
    curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
    chmod +x cosign-linux-amd64
else
    echo "Using existing cosign binary"
fi

# Check if parallel is available for parallel processing
if command -v parallel >/dev/null 2>&1; then
    echo "Using parallel processing with $COSIGN_PARALLEL_JOBS jobs"

    # Sign images in parallel with retries and job logging
    cat "$LSTFILE" | \
        parallel --retries "$COSIGN_RETRIES" \
                 --joblog cosign-signing.log \
                 -j"$COSIGN_PARALLEL_JOBS" \
                 ./cosign-linux-amd64 sign --yes --key env://COSIGN_PRIVATE_KEY {} ">" /dev/null

    # Display the job log for monitoring
    echo "=== Cosign signing job log ==="
    cat cosign-signing.log

    # Check if any jobs failed
    if grep -q "^[^#].*\s[^0]\s*$" cosign-signing.log 2>/dev/null; then
        echo "WARNING: Some signatures may have failed. Check cosign-signing.log for details"
        # Extract failed images
        echo "=== Failed signatures ==="
        awk '$7!=0 {print $NF}' cosign-signing.log
        exit 1
    fi
else
    echo "WARNING: 'parallel' command not found. Falling back to sequential signing."
    echo "Install GNU parallel for faster parallel signing: apt-get install parallel or brew install parallel"

    # Fall back to sequential signing
    failed_images=()
    total_images=$(wc -l < "$LSTFILE")
    current=0

    while IFS= read -r image || [[ -n "$image" ]]; do
        # Skip empty lines and comments
        [[ -z "$image" || "$image" =~ ^[[:space:]]*# ]] && continue

        current=$((current + 1))
        echo "[$current/$total_images] Signing: $image"

        # Retry logic for sequential mode
        retry_count=0
        success=false

        while [[ $retry_count -lt $COSIGN_RETRIES ]]; do
            if ./cosign-linux-amd64 sign --yes --key env://COSIGN_PRIVATE_KEY "$image"; then
                echo "[$current/$total_images] Successfully signed: $image"
                success=true
                break
            else
                retry_count=$((retry_count + 1))
                if [[ $retry_count -lt $COSIGN_RETRIES ]]; then
                    echo "[$current/$total_images] Retry $retry_count/$COSIGN_RETRIES for: $image"
                    sleep 2
                fi
            fi
        done

        if [[ "$success" == "false" ]]; then
            echo "[$current/$total_images] Failed to sign after $COSIGN_RETRIES attempts: $image"
            failed_images+=("$image")
        fi
    done < "$LSTFILE"

    # Report results
    if [[ ${#failed_images[@]} -gt 0 ]]; then
        echo "=== Failed to sign the following images ==="
        for image in "${failed_images[@]}"; do
            echo "  - $image"
        done
        exit 1
    fi
fi

echo "=== Cosign signing completed successfully ==="

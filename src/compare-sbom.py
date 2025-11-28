#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0

"""
Compare SBOM (Software Bill of Materials) between last published and current build.

This script compares:
1. Image list differences (warnings for removed images, info for added images)
2. Version presence (warnings for removed components, info for added components)
3. Version downgrades (errors when current version < last version)

The script pulls the SBOM from a remote container registry and compares it
with a local SBOM file. The OpenStack version can be configured via
--openstack-version or the OPENSTACK_VERSION environment variable.

Alternatively, use --list-remote to only list the remote SBOM contents without
loading a local SBOM or performing any comparison.

Exit codes:
    0: Success (no failures based on configured fail conditions)
    1: One or more configured fail conditions triggered
    2: Fatal errors (Docker errors, file not found, etc.)
"""

import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Dict, List, Set, Tuple

from docker import DockerClient
from docker.errors import DockerException, ImageNotFound, APIError
from loguru import logger
from packaging.version import Version, InvalidVersion
from yaml import safe_load, YAMLError


# Configure logger
logger.remove()
log_fmt = (
    "<green>{time:YYYY-MM-DD HH:mm:ss}</green> | <level>{level: <8}</level> | "
    "<level>{message}</level>"
)
logger.add(sys.stderr, format=log_fmt)


def is_git_repository() -> bool:
    """
    Check if the current directory is inside a Git repository.

    Returns:
        True if inside a Git repository, False otherwise
    """
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--is-inside-work-tree"],
            capture_output=True,
            text=True,
            check=False,
        )
        return result.returncode == 0 and result.stdout.strip() == "true"
    except FileNotFoundError:
        return False


def get_excluded_images_from_commit() -> Set[str]:
    """
    Extract image names to exclude from SBOM check from the last commit message.

    Looks for lines in the format: NO-SBOM-CHECK: <image-name>

    The function first checks for the COMMIT_MESSAGE environment variable (useful
    for CI environments), then falls back to reading from git log.

    The function normalizes names by storing both hyphen and underscore variants,
    since image names use hyphens (e.g., prometheus-libvirt-exporter) while
    version keys use underscores (e.g., prometheus_libvirt_exporter).

    Returns:
        Set of image names to exclude from checking (both variants).
        Returns empty set if not in a Git repository and COMMIT_MESSAGE is not set.
    """
    commit_message = os.environ.get("COMMIT_MESSAGE")

    if commit_message:
        logger.info("Using commit message from COMMIT_MESSAGE environment variable")
    else:
        if not is_git_repository():
            logger.info("Not in a Git repository, skipping commit message parsing")
            return set()

        try:
            result = subprocess.run(
                ["git", "log", "-1", "--format=%B"],
                capture_output=True,
                text=True,
                check=True,
            )
            commit_message = result.stdout
        except (subprocess.CalledProcessError, FileNotFoundError) as e:
            logger.warning(f"Failed to get commit message: {e}")
            return set()

    excluded_images = set()
    excluded_count = 0
    for line in commit_message.splitlines():
        line = line.strip()
        if line.startswith("NO-SBOM-CHECK:"):
            image_name = line.split(":", 1)[1].strip()
            if image_name:
                # Add both hyphen and underscore variants for matching
                excluded_images.add(image_name.replace("_", "-"))
                excluded_images.add(image_name.replace("-", "_"))
                excluded_count += 1
                logger.info(f"Excluding image from SBOM check: {image_name}")

    if excluded_count > 0:
        logger.info(f"Found {excluded_count} image(s) excluded via NO-SBOM-CHECK")

    return excluded_images


def strip_date_postfix(version_string: str) -> str:
    """
    Strip date postfix from version string.

    Example: "20.0.0.20251020" -> "20.0.0"

    Args:
        version_string: Version string potentially with date postfix

    Returns:
        Version string without date postfix
    """
    parts = version_string.split(".")

    # Find first part that looks like a date (8 digits starting with 20)
    cleaned_parts = []
    for part in parts:
        if len(part) == 8 and part.startswith("20"):
            # This looks like a date (YYYYMMDD), stop here
            break
        cleaned_parts.append(part)

    return ".".join(cleaned_parts) if cleaned_parts else version_string


def extract_image_name(image_path: str) -> str:
    """
    Extract service name from full image path.

    Example: "osism.harbor.regio.digital/kolla/ovn-sb-db-relay:25.3.1.20251020"
             -> "ovn-sb-db-relay"

    Args:
        image_path: Full image path with registry, repository and tag

    Returns:
        Service name (between last '/' and ':')
    """
    # Split by '/' to get the last part (image:tag)
    image_with_tag = image_path.split("/")[-1]

    # Split by ':' to get just the image name
    image_name = image_with_tag.split(":")[0]

    return image_name


def load_sbom_from_file(file_path: Path) -> Dict:
    """
    Load SBOM data from YAML file.

    Args:
        file_path: Path to images YAML file

    Returns:
        Parsed SBOM data dictionary

    Raises:
        SystemExit: If file cannot be read or parsed
    """
    logger.info(f"Loading SBOM from file: {file_path}")

    if not file_path.exists():
        logger.error(f"File not found: {file_path}")
        sys.exit(2)

    try:
        with open(file_path, "r") as fp:
            sbom = safe_load(fp)

        if not isinstance(sbom, dict):
            logger.error(f"Invalid SBOM format in {file_path}: expected dict")
            sys.exit(2)

        logger.success(f"Successfully loaded SBOM from {file_path}")
        return sbom

    except YAMLError as e:
        logger.error(f"YAML parsing error in {file_path}: {e}")
        sys.exit(2)
    except Exception as e:
        logger.error(f"Error reading {file_path}: {e}")
        sys.exit(2)


def load_sbom_from_container(image_ref: str) -> Dict:
    """
    Pull container image and extract SBOM file.

    Args:
        image_ref: Container image reference (e.g., "registry.osism.cloud/kolla/sbom:2025.1")

    Returns:
        Parsed SBOM data dictionary

    Raises:
        SystemExit: If container operations fail
    """
    logger.info(f"Pulling container image: {image_ref}")

    try:
        client = DockerClient.from_env()
    except DockerException as e:
        logger.error(f"Failed to connect to Docker: {e}")
        logger.error("Is Docker running?")
        sys.exit(2)

    # Pull the image
    try:
        logger.info(f"Pulling image {image_ref}...")
        client.images.pull(image_ref)
        logger.success(f"Successfully pulled {image_ref}")
    except ImageNotFound:
        logger.error(f"Image not found: {image_ref}")
        sys.exit(2)
    except APIError as e:
        logger.error(f"Docker API error while pulling image: {e}")
        sys.exit(2)
    except Exception as e:
        logger.error(f"Unexpected error pulling image: {e}")
        sys.exit(2)

    # Create temporary container and copy the file
    container = None
    sbom = None

    try:
        logger.info("Creating temporary container...")
        container = client.containers.create(image_ref, command="true")

        with tempfile.NamedTemporaryFile(mode="w+b", delete=False) as tmp_file:
            logger.info("Extracting images.yml from container...")

            # Get the file from container
            bits, stat = container.get_archive("/images.yml")

            # Write tar archive to temp file
            for chunk in bits:
                tmp_file.write(chunk)
            tmp_file.flush()

            # Extract YAML from tar
            import tarfile

            tmp_file.seek(0)
            with tarfile.open(fileobj=tmp_file) as tar:
                yaml_file = tar.extractfile("images.yml")
                if yaml_file:
                    sbom = safe_load(yaml_file.read().decode("utf-8"))
                else:
                    raise FileNotFoundError("images.yml not found in tar archive")

        logger.success("Successfully extracted SBOM from container")

    except FileNotFoundError as e:
        logger.error(f"File not found in container: {e}")
        sys.exit(2)
    except YAMLError as e:
        logger.error(f"YAML parsing error: {e}")
        sys.exit(2)
    except Exception as e:
        logger.error(f"Error extracting SBOM from container: {e}")
        sys.exit(2)
    finally:
        # Cleanup: remove container
        if container:
            try:
                logger.info("Removing temporary container...")
                container.remove()
                logger.success("Container removed")
            except Exception as e:
                logger.warning(f"Failed to remove container: {e}")

        # Cleanup: remove image
        try:
            logger.info(f"Removing image {image_ref}...")
            client.images.remove(image_ref, force=True)
            logger.success("Image removed")
        except Exception as e:
            logger.warning(f"Failed to remove image: {e}")

    return sbom


def extract_image_names(sbom: Dict) -> Set[str]:
    """
    Extract set of image names from SBOM.

    Args:
        sbom: SBOM data dictionary

    Returns:
        Set of image names (without tags)
    """
    images = sbom.get("images", [])
    image_names = set()

    for item in images:
        if isinstance(item, dict) and "image" in item:
            image_path = item["image"]
            image_name = extract_image_name(image_path)
            image_names.add(image_name)

    return image_names


def compare_image_lists(
    remote_images: Set[str], local_images: Set[str]
) -> Tuple[Set[str], Set[str]]:
    """
    Compare image lists and identify differences.

    Args:
        remote_images: Set of image names from remote SBOM
        local_images: Set of image names from local SBOM

    Returns:
        Tuple of (removed_images, added_images)
    """
    removed = remote_images - local_images
    added = local_images - remote_images

    return removed, added


def compare_versions(
    remote_versions: Dict[str, str], local_versions: Dict[str, str]
) -> List[Tuple[str, str, str]]:
    """
    Compare version numbers and detect downgrades.

    Args:
        remote_versions: Version dict from remote SBOM
        local_versions: Version dict from local SBOM

    Returns:
        List of (service_name, remote_version, local_version) for downgrades
    """
    downgrades = []

    # Only check services that exist in both
    common_services = set(remote_versions.keys()) & set(local_versions.keys())

    for service in common_services:
        remote_ver_str = remote_versions[service]
        local_ver_str = local_versions[service]

        # Strip date postfix
        remote_ver_clean = strip_date_postfix(remote_ver_str)
        local_ver_clean = strip_date_postfix(local_ver_str)

        try:
            remote_ver = Version(remote_ver_clean)
            local_ver = Version(local_ver_clean)

            if local_ver < remote_ver:
                downgrades.append((service, remote_ver_clean, local_ver_clean))

        except InvalidVersion as e:
            logger.warning(
                f"Invalid version for {service}: remote={remote_ver_clean}, "
                f"local={local_ver_clean} - {e}"
            )
            continue

    return downgrades


def compare_version_presence(
    remote_versions: Dict[str, str], local_versions: Dict[str, str]
) -> Tuple[Set[str], Set[str]]:
    """
    Compare version presence and detect added/removed components.

    Args:
        remote_versions: Version dict from remote SBOM
        local_versions: Version dict from local SBOM

    Returns:
        Tuple of (removed_versions, added_versions)
        - removed_versions: Components in remote but not in local
        - added_versions: Components in local but not in remote
    """
    remote_components = set(remote_versions.keys())
    local_components = set(local_versions.keys())

    # Components that were removed (in remote but not in local)
    removed = remote_components - local_components

    # Components that were added (in local but not in remote)
    added = local_components - remote_components

    return removed, added


def list_sbom(sbom: Dict) -> None:
    """
    List contents of an SBOM.

    Args:
        sbom: SBOM data dictionary
    """
    # List images
    images = extract_image_names(sbom)
    logger.info("")
    logger.info(f"Images ({len(images)}):")
    for image in sorted(images):
        logger.info(f"  {image}")

    # List versions
    versions = sbom.get("versions", {})
    logger.info("")
    logger.info(f"Versions ({len(versions)}):")
    for component, version in sorted(versions.items()):
        logger.info(f"  {component}: {version}")


def main():
    """
    Main entry point for SBOM comparison.
    """
    parser = argparse.ArgumentParser(
        description="Compare SBOM between last published build and current build.\n"
        "Checks for removed images/versions (WARNING), added images/versions (INFO),\n"
        "and version downgrades (ERROR).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exit codes:
  0 - Success (no failures based on configured fail conditions)
  1 - One or more configured fail conditions triggered
  2 - Fatal errors (Docker errors, file not found, etc.)
""",
    )

    parser.add_argument(
        "--list-remote",
        action="store_true",
        default=False,
        help="Only list remote SBOM contents without comparing to local SBOM",
    )

    parser.add_argument(
        "--local-sbom",
        "-l",
        type=str,
        default="images.yml",
        help="Path to local SBOM file (default: images.yml)",
    )

    parser.add_argument(
        "--openstack-version",
        type=str,
        default=os.environ.get("OPENSTACK_VERSION", "2025.1"),
        help="OpenStack version for SBOM image tag (default: 2025.1, env: OPENSTACK_VERSION)",
    )

    parser.add_argument(
        "--remote-image",
        "-r",
        type=str,
        default=None,
        help="Remote SBOM container image reference (default: registry.osism.cloud/kolla/sbom:<openstack-version>)",
    )

    parser.add_argument(
        "--fail-on-image-removed",
        action="store_true",
        default=False,
        help="Exit with code 1 when images are removed",
    )

    parser.add_argument(
        "--fail-on-image-added",
        action="store_true",
        default=False,
        help="Exit with code 1 when images are added",
    )

    parser.add_argument(
        "--fail-on-version-removed",
        action="store_true",
        default=False,
        help="Exit with code 1 when versions are removed",
    )

    parser.add_argument(
        "--fail-on-version-added",
        action="store_true",
        default=False,
        help="Exit with code 1 when versions are added",
    )

    parser.add_argument(
        "--fail-on-version-downgrade",
        action="store_true",
        default=True,
        help="Exit with code 1 when version downgrades are detected (default: True)",
    )

    args = parser.parse_args()

    # If remote-image not explicitly set, construct it with openstack-version
    if args.remote_image is None:
        args.remote_image = f"registry.osism.cloud/kolla/sbom:{args.openstack_version}"

    # Handle --list-remote mode
    if args.list_remote:
        logger.info("Listing remote SBOM contents")
        logger.info(f"Using OpenStack version: {args.openstack_version}")
        logger.info(f"Remote image: {args.remote_image}")

        try:
            remote = load_sbom_from_container(args.remote_image)
        except SystemExit:
            raise
        except Exception as e:
            logger.error(f"Unexpected error loading remote SBOM: {e}")
            sys.exit(2)

        list_sbom(remote)
        logger.info("")
        logger.success("Remote SBOM listing complete")
        sys.exit(0)

    # Convert string to Path
    local_sbom_path = Path(args.local_sbom)

    logger.info("Starting SBOM comparison")
    logger.info(f"Using OpenStack version: {args.openstack_version}")
    logger.info(f"Local SBOM: {local_sbom_path}")
    logger.info(f"Remote image: {args.remote_image}")

    # Load SBOMs
    try:
        local = load_sbom_from_file(local_sbom_path)
        remote = load_sbom_from_container(args.remote_image)
    except SystemExit:
        raise
    except Exception as e:
        logger.error(f"Unexpected error loading SBOMs: {e}")
        sys.exit(2)

    # Get excluded images from commit message
    excluded_images = get_excluded_images_from_commit()

    # Extract data
    logger.info("")
    logger.info("Extracting image names...")
    remote_images = extract_image_names(remote)
    local_images = extract_image_names(local)

    # Remove excluded images from comparison
    if excluded_images:
        remote_images = remote_images - excluded_images
        local_images = local_images - excluded_images

    logger.info(f"Remote SBOM contains {len(remote_images)} images")
    logger.info(f"Local SBOM contains {len(local_images)} images")

    remote_versions_all = remote.get("versions", {})
    local_versions_all = local.get("versions", {})

    # Remove excluded images from version comparisons
    if excluded_images:
        remote_versions = {
            k: v for k, v in remote_versions_all.items() if k not in excluded_images
        }
        local_versions = {
            k: v for k, v in local_versions_all.items() if k not in excluded_images
        }
        # Keep excluded versions for info output
        remote_versions_excluded = {
            k: v for k, v in remote_versions_all.items() if k in excluded_images
        }
        local_versions_excluded = {
            k: v for k, v in local_versions_all.items() if k in excluded_images
        }
    else:
        remote_versions = remote_versions_all
        local_versions = local_versions_all
        remote_versions_excluded = {}
        local_versions_excluded = {}

    logger.info(f"Remote SBOM contains {len(remote_versions)} version entries")
    logger.info(f"Local SBOM contains {len(local_versions)} version entries")

    # Compare image lists
    logger.info("")
    logger.info("Comparing image lists...")
    removed_images, added_images = compare_image_lists(remote_images, local_images)

    if removed_images:
        log_level = logger.error if args.fail_on_image_removed else logger.warning
        log_level(f"Images removed from build ({len(removed_images)}):")
        for image in sorted(removed_images):
            log_level(f"  - {image}")

    if added_images:
        log_level = logger.error if args.fail_on_image_added else logger.info
        log_level(f"Images added to build ({len(added_images)}):")
        for image in sorted(added_images):
            log_level(f"  + {image}")

    if not removed_images and not added_images:
        logger.success("No image list differences found")

    # Compare versions (downgrades)
    logger.info("")
    logger.info("Comparing versions for downgrades...")
    downgrades = compare_versions(remote_versions, local_versions)

    if downgrades:
        log_level = logger.error if args.fail_on_version_downgrade else logger.warning
        log_level(f"Version downgrades detected ({len(downgrades)}):")
        for service, remote_ver, local_ver in sorted(downgrades):
            log_level(f"  {service}: {remote_ver} -> {local_ver} (DOWNGRADE)")
    else:
        logger.success("No version downgrades detected")

    # Show version changes for excluded images (info only, no failure)
    if remote_versions_excluded or local_versions_excluded:
        excluded_changes = compare_versions(
            remote_versions_excluded, local_versions_excluded
        )
        if excluded_changes:
            logger.info("")
            logger.info(
                f"Version changes in excluded images ({len(excluded_changes)}):"
            )
            for service, remote_ver, local_ver in sorted(excluded_changes):
                logger.info(f"  {service}: {remote_ver} -> {local_ver} (EXCLUDED)")

    # Compare version presence (added/removed components)
    logger.info("")
    logger.info("Comparing version presence...")
    removed_versions, added_versions = compare_version_presence(
        remote_versions, local_versions
    )

    if removed_versions:
        log_level = logger.error if args.fail_on_version_removed else logger.warning
        log_level(f"Versions removed from build ({len(removed_versions)}):")
        for component in sorted(removed_versions):
            log_level(f"  - {component}")

    if added_versions:
        log_level = logger.error if args.fail_on_version_added else logger.info
        log_level(f"Versions added to build ({len(added_versions)}):")
        for component in sorted(added_versions):
            log_level(f"  + {component}")

    if not removed_versions and not added_versions:
        logger.success("No version presence differences found")

    # Determine exit code based on configured fail conditions
    exit_code = 0
    failed_conditions = []

    # Check each fail condition flag and build list of failures
    if removed_images and args.fail_on_image_removed:
        exit_code = 1
        failed_conditions.append("images removed")

    if added_images and args.fail_on_image_added:
        exit_code = 1
        failed_conditions.append("images added")

    if removed_versions and args.fail_on_version_removed:
        exit_code = 1
        failed_conditions.append("versions removed")

    if added_versions and args.fail_on_version_added:
        exit_code = 1
        failed_conditions.append("versions added")

    if downgrades and args.fail_on_version_downgrade:
        exit_code = 1
        failed_conditions.append("version downgrades")

    # Summary
    logger.info("")
    logger.info("=" * 60)

    if failed_conditions:
        # Log failed conditions before exit
        logger.error(f"Failed conditions: {', '.join(failed_conditions)}")
        logger.error("COMPARISON FAILED: One or more fail conditions triggered")
        sys.exit(exit_code)
    else:
        logger.success("COMPARISON SUCCESSFUL: No issues found")
        sys.exit(0)


if __name__ == "__main__":
    main()

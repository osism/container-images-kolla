#!/usr/bin/env python3

import os
import shutil
import sys
import tempfile

from docker import APIClient, DockerClient
from loguru import logger

DOCKER_NAMESPACE = os.environ.get("DOCKER_NAMESPACE", "osism")
DOCKER_REGISTRY = os.environ.get("DOCKER_REGISTRY", "quay.io")

VERSION = os.environ.get("OPENSTACK_VERSION", "2024.1")
FILTERS = {"label": f"de.osism.release.openstack={VERSION}"}

SUPPORTED_IMAGES = ["keystone"]

level = "INFO"
log_fmt = (
    "<green>{time:YYYY-MM-DD HH:mm:ss}</green> | <level>{level: <8}</level> | "
    "<level>{message}</level>"
)

logger.remove()
logger.add(sys.stderr, format=log_fmt, level=level, colorize=True)

client = DockerClient()
client_api = APIClient()

for image in client.images.list(filters=FILTERS):
    # skip images without a tag
    if not image.tags:
        continue

    tag = image.tags[0]
    target_tag = f"{tag}-after-cleanup"

    # Check if the image is supported
    if not [x for x in SUPPORTED_IMAGES if x in image.labels["name"]]:
        logger.info(f"Image {tag} not supported")
        continue

    logger.info(f"Cleaning up image {tag}")

    # Image layers

    # 0: "sha256:59c56aee1fb4dbaeb334aef06088b49902105d1ea0c15a9e5a2a9ce560fa4c5d" <-- ubuntu:22.04
    # 1: "sha256:295ebbacd98b98d173f5fba0371e4fee8bbdf9ff0ad2676670ddb2b521482004" <-- base
    # 2: "sha256:bd9f5e1f11d685268d42d7bf3a7850fdd7b6767bfcfbdb1bcc0b31227dae8f91" <-- openstack-base
    # 3: "sha256:6ae01f1fd7a8c29837ddc7ed50e78ba70666f5967bdaf8438f07da2971d3d024" <-- service-base
    # 4: "sha256:591d1c8305854fabc586786673d87f55eb142f0efed7a002f696c6a1c4c26880" <-- service

    with tempfile.TemporaryDirectory() as d:
        shutil.copy("files/cleanup-base-sources.sh", d)

        dockerfile = os.path.join(d, "Dockerfile")
        logger.info(f"Generating Dockerfile in {d}")

        # Get current username
        result = client.containers.run(tag, "bash -c 'whoami'")
        username = result.decode("utf-8")

        with open(dockerfile, "w+") as fp:
            # Cleanup the sources
            fp.write(f"\nFROM {tag} as cleanup\n")
            fp.write("COPY cleanup-base-sources.sh /cleanup-base-sources.sh\n")
            fp.write("USER root\n")
            fp.write("RUN bash /cleanup-base-sources.sh\n")
            fp.write("RUN rm /cleanup-base-sources.sh\n")
            fp.write(f"USER {username}\n")
            fp.write("\n")

            # Rebase on openstack-base
            fp.write("FROM scratch\n")
            fp.write("COPY --from=cleanup / /\n")

        with open(dockerfile, "r+") as fp:
            logger.info(fp.read())

        logger.info(f"Building {target_tag}")
        client.images.build(path=d, tag=target_tag, squash=True)

        # Re-tag the image
        logger.info(f"Post processing {target_tag}")
        client.images.remove(tag, force=True)
        client.api.tag(target_tag, tag)
        client.api.tag(target_tag, "testing")
        client.images.remove(target_tag, force=True)

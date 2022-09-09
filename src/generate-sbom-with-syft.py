import logging
import subprocess
import os

from docker import DockerClient

IS_RELEASE = os.environ.get("IS_RELEASE", "false")

if IS_RELEASE == "true":
    VERSION = os.environ.get("VERSION", "xena")
else:
    VERSION = os.environ.get("OPENSTACK_VERSION", "xena")

logging.basicConfig(format='%(asctime)s %(levelname)s - %(message)s', level=logging.INFO, datefmt='%Y-%m-%d %H:%M:%S')

client = DockerClient()

for image in client.images.list():
    # skip images without a tag
    if not image.tags:
        continue

    name = None
    tag = image.tags[0]

    if "org.opencontainers.image.title" in image.labels:
        name = image.labels["org.opencontainers.image.title"]
    else:
        continue

    # skip base images
    if name[-4:] == "base":
        continue

    if tag[(-1 * len(VERSION)):] == VERSION:
        logging.info(f"Generating SBOM for {tag}")
        p = subprocess.Popen(f"/usr/local/bin/syft packages {tag} -o spdx-json > {name}.spdx", shell=True)
        p.wait()

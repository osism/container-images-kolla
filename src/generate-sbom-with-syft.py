# SPDX-License-Identifier: Apache-2.0

import subprocess

from loguru import logger
from yaml import safe_load, YAMLError

with open("images.yml", "r") as fp:
    try:
        images = safe_load(fp)
    except YAMLError as e:
        logger.error(e)

processes = []
for image in images:
    name = image.split("/")[-1].split(":")[0]
    logger.info(f"Generating SBOM for {image} as {name}.spdx")
    p = subprocess.Popen(
        f"/usr/local/bin/syft packages {image} -o spdx-json > {name}.spdx", shell=True
    )
    processes.append(p)

for p in processes:
    p.wait()

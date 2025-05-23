#!/usr/bin/env python3

# SPDX-License-Identifier: Apache-2.0

import io
import os
import subprocess
import sys

from loguru import logger
import json
import yaml

LIST = os.environ.get("LIST", "openstack")

level = "INFO"
log_fmt = (
    "<green>{time:YYYY-MM-DD HH:mm:ss}</green> | <level>{level: <8}</level> | "
    "<level>{message}</level>"
)

logger.remove()
logger.add(sys.stderr, format=log_fmt, level=level, colorize=True)

with open(f"{LIST}.yml") as fp:
    data = yaml.load(fp, Loader=yaml.SafeLoader)

images = data.get("images", {})
for image in images:
    logger.info(f"Processing {image['image']}")
    p = subprocess.Popen(
        f"skopeo inspect docker-daemon:{image['image']}",
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    p.wait()
    stdout = io.TextIOWrapper(p.stdout, encoding="utf-8")
    result = json.loads(stdout.read())
    image["digest"] = result["Digest"]

with open(f"{LIST}.yml", "w+") as fp:
    fp.write(yaml.dump(data))

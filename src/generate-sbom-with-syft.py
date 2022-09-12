import logging
import subprocess

from yaml import safe_load, YAMLError

logging.basicConfig(format='%(asctime)s %(levelname)s - %(message)s', level=logging.INFO, datefmt='%Y-%m-%d %H:%M:%S')

with open("images.yml", "r") as fp:
    try:
        images = safe_load(fp)
    except YAMLError as e:
        logging.error(e)

processes = []
for image in images:
    name = image.split("/")[-1].split(":")[0]
    logging.info(f"Generating SBOM for {image} as {name}.spdx")
    p = subprocess.Popen(f"/usr/local/bin/syft packages {image} -o spdx-json > {name}.spdx", shell=True)
    processes.append(p)

for p in processes:
    p.wait()

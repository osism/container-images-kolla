from docker import DockerClient
import logging
import os
from re import findall, sub
from tabulate import tabulate
from yaml import safe_load, YAMLError

IS_RELEASE = os.environ.get("IS_RELEASE", "false")

if IS_RELEASE == "true":
    VERSION = os.environ.get("VERSION", "xena")
else:
    VERSION = os.environ.get("OPENSTACK_VERSION", "xena")

logging.basicConfig(format='%(asctime)s %(levelname)s - %(message)s', level=logging.INFO, datefmt='%Y-%m-%d %H:%M:%S')

with open("etc/tag-images-with-the-version.yml", "r") as fp:
    try:
        configuration = safe_load(fp)
    except YAMLError as e:
        logging.error(e)

client = DockerClient()

list_of_images = []

for image in client.images.list():
    build_date = None
    name = None
    version = None

    # skip images without a tag
    if not image.tags:
        continue

    tag = image.tags[0]

    logging.info(f"Analysing {tag}")

    if "org.opencontainers.image.title" in image.labels:
        name = image.labels["org.opencontainers.image.title"]
    else:
        continue

    if "de.osism.release.openstack" in image.labels:
        version = image.labels["de.osism.release.openstack"]
    else:
        continue

    if "build-date" in image.labels:
        # NOTE: maybe it is better to use org.opencontainers.image.created here
        build_date = image.labels["build-date"]
    else:
        continue

    # skip base images
    if name[-4:] == "base":
        continue

    if tag[(-1 * len(version)):] == VERSION:

        best_key = None
        if name in configuration:
            best_key = name
        else:
            best_key = name.split("-")[0]

        if best_key not in configuration:
            logging.error(f"Configuration for {name} ({best_key}) not found")
            continue

        command = configuration[best_key]
        logging.info(f"Best match in configuration for {tag} is {best_key}, using {command}")

        logging.info(f"Checking {tag}")

        try:
            result = client.containers.run(image, command=command, remove=True, detach=False)
            result = result.decode("utf-8")

            # NOTE: the libvirt_export binary has no --version argument
            # https://github.com/osism/container-images-kolla/issues/143
            if best_key == "prometheus-libvirt-exporter":
                r = [VERSION]

            elif best_key == "kolla-toolbox":
                r = [image.labels["de.osism.commit.kolla_version"]]

            elif best_key == "kafka":
                # 2.0.1 (Commit:fa14705e51bd2ce5)
                r = findall(r"(.*) \(Commit:", result)

            elif best_key.split("-")[0] == "prometheus":
                # alertmanager, version 0.20.0 (branch: HEAD, revision: f74be0400a6243d10bb53812d6fa408ad71ff32d)
                r = findall(r", version (.*) \(branch:", result)

                if not r:
                    # cAdvisor version v0.38.7 (57a2c804)
                    r = findall(r"cAdvisor version v(.*) \(", result)

                if not r:
                    # mtail version v3.0.0-rc35 git revision a33283598c4b7a70fc2f113680318f29d5826cca go version go1.14 go arch amd64 go os linux
                    r = findall(r"mtail version v(.*) git revision", result)

            elif best_key == "storm":
                # Storm 1.2.2
                r = findall(r"Storm (.*)", result)

            elif best_key == "zookeeper":
                # /opt/zookeeper/zookeeper-3.4.13.jar
                r = findall(r"zookeeper-(.*)\.jar", result)

            # everything else is a pip3 or dpkg version
            else:
                r = findall(r"Version: (.*)\n", result)

            if r:
                target_version = r[0]

                # remove X: prefix from ubuntu package versions
                target_version = sub(r"[0-9]:", "", target_version)

                # remove -X postfix
                target_version = sub(r"-.*", "", target_version)

                # remove +X postfix
                target_version = sub(r"\+.*", "", target_version)

                logging.info(f"Found version '{target_version}' with build date '{build_date}' for {tag}")
                target_tag = f"{tag[:(-1 * len(version) - 1)]}:{target_version}.{build_date}"

                # Move release images to a release subproject
                if IS_RELEASE == "true":
                    target_tag = target_tag.replace("/osism/", "/osism/release/")

                logging.info(f"Re-tagging {tag} as {target_tag}")
                image.tag(target_tag)
                list_of_images.append([target_tag])
            else:
                logging.warning(f"Version not found for {tag}")
        except Exception as e:
            logging.error(f"Something went wrong while processing {tag}: {e}")

with open("tag-images-with-the-version.lst", "w+") as fp:
    for image in list_of_images:
        fp.write(f"{image[0]}\n")

print()
print(tabulate(list_of_images, headers=["image"], tablefmt="psql"))

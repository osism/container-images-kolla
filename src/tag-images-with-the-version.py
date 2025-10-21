# SPDX-License-Identifier: Apache-2.0

import os
from packaging import version as packaging_version
from re import findall, sub
import subprocess
import tempfile

from docker import DockerClient
from tabulate import tabulate
from loguru import logger
from yaml import dump, safe_load, YAMLError

IS_RELEASE = os.environ.get("IS_RELEASE", "False")
TAG_POSTFIX = os.environ.get("TAG_POSTFIX", None)

if IS_RELEASE == "True":
    VERSION = os.environ.get("VERSION", "zed")
    FILTERS = {"label": f"de.osism.version={VERSION}"}
else:
    VERSION = os.environ.get("OPENSTACK_VERSION", "zed")
    FILTERS = {"label": f"de.osism.release.openstack={VERSION}"}

with open("etc/tag-images-with-the-version.yml", "r") as fp:
    try:
        configuration = safe_load(fp)
    except YAMLError as e:
        logger.error(e)

client = DockerClient()

list_of_images = []

for image in client.images.list(filters=FILTERS):
    build_date = None
    name = None
    version = None

    # skip images without a tag
    if not image.tags:
        continue

    tag = image.tags[0]

    logger.info(f"Analysing {tag}")

    if "org.opencontainers.image.title" in image.labels:
        name = image.labels["org.opencontainers.image.title"]
    else:
        logger.info(f"Label org.opencontainers.image.title not found for {tag}")
        continue

    if IS_RELEASE == "True":
        if "de.osism.version" in image.labels:
            version = image.labels["de.osism.version"]
        else:
            logger.info(f"Label de.osism.version not found for {tag}")
            continue
    else:
        if "de.osism.release.openstack" in image.labels:
            version = image.labels["de.osism.release.openstack"]
        else:
            logger.info(f"Label de.osism.release.openstack not found for {tag}")
            continue

    if "build-date" in image.labels:
        # NOTE: maybe it is better to use org.opencontainers.image.created here
        build_date = image.labels["build-date"]
    else:
        logger.info(f"Label build-date not found for {tag}")
        continue

    # skip base images
    if name[-4:] == "base":
        logger.info(f"{tag} is a base image and not handled at the moment")
        continue

    if tag[(-1 * len(version)) :] == VERSION:  # noqa  E203 whitespace before ':'

        best_key = None
        if name in configuration:
            best_key = name
        else:
            best_key = name.split("-")[0]

        if best_key not in configuration:
            logger.error(f"Configuration for {name} ({best_key}) not found")
            continue

        if best_key == "ovn" and VERSION in ["2024.1", "2024.2"]:
            command = "ovn-controller --version"
        else:
            command = configuration[best_key]

        logger.info(
            f"Best match in configuration for {tag} is {best_key}, using {command}"
        )

        logger.info(f"Checking {tag}")

        try:
            result = client.containers.run(
                image, command=command, remove=True, detach=False
            )
            result = result.decode("utf-8")

            # NOTE: the libvirt_export binary has no --version argument
            # https://github.com/osism/container-images-kolla/issues/143
            if best_key == "prometheus-libvirt-exporter":
                r = [VERSION]

            elif best_key == "prometheus-openstack-exporter":
                r = [VERSION]

            elif best_key == "prometheus-ovn-exporter":
                # ovn-exporter 1.0.4
                # ovn-exporter 1.0.7, commit: 79cb6010e656fd6b24c9ccba29bde4cddcf832c2
                r = findall(r"ovn-exporter ([^,\n]+)", result)

            elif best_key == "kolla-toolbox":
                r = [image.labels["de.osism.commit.kolla_version"]]

            elif best_key == "kafka":
                # 2.0.1 (Commit:fa14705e51bd2ce5)
                r = findall(r"(.*) \(Commit:", result)

            elif best_key == "ovn" and VERSION in ["2024.1", "2024.2"]:
                # ovn-controller 22.03.0
                r = findall(r"ovn-controller (.*)\n", result)

            elif best_key.split("-")[0] == "prometheus":
                # alertmanager, version 0.20.0 (branch: HEAD, revision: f74be0400a6243d10bb53812d6fa408ad71ff32d)
                r = findall(r", version (.*) \(branch:", result)

                if not r:
                    # cAdvisor version v0.38.7 (57a2c804)
                    r = findall(r"cAdvisor version v(.*) \(", result)

                if not r:
                    # mtail version v3.0.0-rc35 git revision a33283598c4b7a70fc2f113680318f29d5826cca go version go1.14 go arch amd64 go os linux
                    r = findall(r"mtail version v?(.*) git revision", result)

                if not r:
                    # v1.5.1 (msteams)
                    r = findall(r"v(.*)", result)

            elif best_key == "storm":
                # Storm 1.2.2
                r = findall(r"Storm (.*)", result)

            elif best_key == "etcd":
                # etcd Version: 3.2.26
                r = findall(r"etcd Version: (.*)", result)

            elif best_key == "zookeeper":
                # /opt/zookeeper/zookeeper-3.4.13.jar
                r = findall(r"zookeeper-(.*)\.jar", result)

            # everything else is a pip3 or dpkg version
            else:
                r = findall(r"Version: (.*)\n", result)

            if r:
                target_version = r[0].strip()

                # remove X: prefix from ubuntu package versions
                target_version = sub(r"[0-9]:", "", target_version)

                # remove -X postfix
                target_version = sub(r"-.*", "", target_version)

                # remove +X postfix
                target_version = sub(r"\+.*", "", target_version)

                # remove pX postfix
                target_version = sub(r"p.*", "", target_version)

                # beautify version
                parsed_version = packaging_version.parse(target_version)

                # NOTE: We use only the first 3 places of the version. This prevents
                #       versions like 15.0.0.0.
                target_version = ".".join(
                    [str(x) for x in list(parsed_version.release)[0:3]]
                )

                logger.info(
                    f"Found version '{target_version}' with build date '{build_date}' for {tag}"
                )
                target_tag = (
                    f"{tag[:(-1 * len(version) - 1)]}:{target_version}.{build_date}"
                )

                if TAG_POSTFIX:
                    target_tag = f"{target_tag}.{TAG_POSTFIX}"
                    logger.info(
                        f"Tag postfix '{TAG_POSTFIX}. is defined, extended tag is {target_tag}."
                    )

                # Move release images to a release subproject
                if IS_RELEASE == "True":
                    target_tag = target_tag.replace("/kolla/", "/kolla/release/")

                logger.info(
                    f"Adding org.opencontainers.image.version='{target_version}' label to {tag}"
                )
                with tempfile.NamedTemporaryFile() as fp:
                    fp.write(f"FROM {tag}\n".encode())
                    fp.write(
                        f"LABEL org.opencontainers.image.version='{target_version}'\n".encode()
                    )
                    fp.seek(0)

                    client.images.build(fileobj=fp, tag=target_tag)

                logger.info(f"Remove old image {tag}")
                subprocess.run(["docker", "rmi", "-f", tag])

                logger.info(f"Add new image {tag}")
                subprocess.run(["docker", "tag", target_tag, tag])

                list_of_images.append([target_tag])
            else:
                logger.warning(f"Version not found for {tag}")
        except Exception as e:
            logger.error(f"Something went wrong while processing {tag}: {e}")

flat_list_of_images = [image[0] for image in list_of_images]
with open("images.lst", "w+") as fp:
    for image in flat_list_of_images:
        fp.write(f"{image}\n")

sbom = {"images": [], "versions": {}}

SBOM_IMAGE_TO_VERSION = {
    "aodh": "aodh-api",
    "barbican": "barbican-api",
    "bifrost": "bifrost-deploy",
    "ceilometer": "ceilometer-central",
    "cinder": "cinder-api",
    "cloudkitty": "cloudkitty-api",
    "collectd": "collectd",
    "cron": "cron",
    "designate": "designate-api",
    "dnsmasq": "dnsmasq",
    "elasticsearch": "elasticsearch",
    "elasticsearch_curator": "elasticsearch-curator",
    "etcd": "etcd",
    "fluentd": "fluentd",
    "glance": "glance-api",
    "gnocchi": "gnocchi-api",
    "grafana": "grafana",
    "haproxy": "haproxy",
    "haproxy_ssh": "haproxy-ssh",
    "horizon": "horizon",
    "influxdb": "influxdb",
    "ironic": "ironic-api",
    "ironic_inspector": "ironic-inspector",
    "iscsid": "iscsid",
    "kafka": "kafka",
    "keepalived": "keepalived",
    "keystone": "keystone",
    "kibana": "kibana",
    "kolla_toolbox": "kolla-toolbox",
    "kolla-toolbox": "kolla-toolbox",
    "kuryr": "kuryr-libnetwork",
    "logstash": "logstash",
    "magnum": "magnum-api",
    "manila": "manila-api",
    "mariadb": "mariadb-server",
    "masakari": "masakari-api",
    "memcached": "memcached",
    "mistral": "mistral-api",
    "multipathd": "multipathd",
    "neutron": "neutron-server",
    "nova": "nova-api",
    "nova_libvirt": "nova-libvirt",
    "octavia": "octavia-api",
    "opensearch": "opensearch",
    "opensearch_dashboards": "opensearch-dashboards",
    "openvswitch": "openvswitch-vswitchd",
    "ovn": "ovn-controller",
    "hacluster": "hacluster",
    "hacluster_corosync": "hacluster-corosync",
    "placement": "placement-api",
    "prometheus": "prometheus-v2-server",
    "prometheus_alertmanager": "prometheus-alertmanager",
    "prometheus_blackbox_exporter": "prometheus-blackbox-exporter",
    "prometheus_cadvisor": "prometheus-cadvisor",
    "prometheus_elasticsearch_exporter": "prometheus-elasticsearch-exporter",
    "prometheus_haproxy_exporter": "prometheus-haproxy-exporter",
    "prometheus_libvirt_exporter": "prometheus-libvirt-exporter",
    "prometheus_memcached_exporter": "prometheus-memcached-exporter",
    "prometheus_msteams": "prometheus-msteams",
    "prometheus_mtail": "prometheus-mtail",
    "prometheus_mysqld_exporter": "prometheus-mysqld-exporter",
    "prometheus_node_exporter": "prometheus-node-exporter",
    "prometheus_openstack_exporter": "prometheus-openstack-exporter",
    "prometheus_ovn_exporter": "prometheus-ovn-exporter",
    "proxysql": "proxysql",
    "rabbitmq": "rabbitmq",
    "redis": "redis",
    "senlin": "senlin-api",
    "skyline": "skyline-apiserver",
    "skyline_console": "skyline-console",
    "storm": "storm",
    "swift": "swift-object",
    "tgtd": "tgtd",
    "trove": "trove-api",
}

sbom_versions = {}
for image in flat_list_of_images:
    sbom["images"].append({"image": image})
    name, version = image.split("/")[-1].split(":")
    sbom_versions[name] = version

for name in SBOM_IMAGE_TO_VERSION:
    try:
        sbom["versions"][name] = sbom_versions[SBOM_IMAGE_TO_VERSION[name]]
    except KeyError:
        pass

with open("images.yml", "w+") as fp:
    dump(sbom, fp, default_flow_style=False, explicit_start=True)

print()
print(tabulate(list_of_images, headers=["image"], tablefmt="psql"))

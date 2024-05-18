# SPDX-License-Identifier: Apache-2.0

import os

import jinja2
import yaml

IS_RELEASE = os.environ.get("IS_RELEASE", "False")
OPENSTACK_VERSION = os.environ.get("OPENSTACK_VERSION", "latest")
VERSION = os.environ.get("VERSION", "latest")

KOLLA_BASE = os.environ.get("BASE", "ubuntu")
KOLLA_BASE_TAG = os.environ.get("BASE_VERSION", "22.04")
KOLLA_INSTALL_TYPE = "source"
KOLLA_NAMESPACE = os.environ.get("DOCKER_NAMESPACE", "osism")

TEMPLATE_FILE = "kolla-build.conf.j2"


# http://stackoverflow.com/questions/4984647/accessing-dict-keys-like-an-attribute-in-python
class AttrDict(dict):
    def __init__(self, *args, **kwargs):
        super(AttrDict, self).__init__(*args, **kwargs)
        self.__dict__ = self


versions = {}
projects = []

filename = "release/%s/openstack-%s.yml" % (VERSION, OPENSTACK_VERSION)
with open(filename, "rb") as fp:
    versions = yaml.load(fp, Loader=yaml.FullLoader)

for project in versions["openstack_projects"].keys():
    if project in ["gnocchi", "novajoin"]:
        continue

    repository = project

    if project == "neutron-lbaas-agent":
        repository = "neutron-lbaas"

    elif project == "neutron-vpnaas-agent":
        repository = "neutron-vpnaas"

    # NOTE: use stable branches for monasca for the moment
    elif project == "monasca":
        continue

    projects.append(
        {
            "name": project,
            "version": versions["openstack_projects"][project],
            "repository": repository,
        }
    )

loader = jinja2.FileSystemLoader(searchpath="templates/%s" % OPENSTACK_VERSION)
environment = jinja2.Environment(loader=loader)
template = environment.get_template(TEMPLATE_FILE)

projects_with_version = [
    x for x in projects if versions["openstack_projects"][x["name"]]
]

template_data = {
    "base": KOLLA_BASE,
    "base_tag": KOLLA_BASE_TAG,
    "gnocchi_version": versions["openstack_projects"].get("gnocchi", ""),
    "install_type": KOLLA_INSTALL_TYPE,
    "is_release": IS_RELEASE,
    "namespace": KOLLA_NAMESPACE,
    "openstack_release": versions["openstack_version"],
    "projects": projects_with_version,
    "versions": versions,
}

if "novajoin" in versions["openstack_projects"]:
    novajoin_version = versions["openstack_projects"]["novajoin"]
    template_data["novajoin_version"] = novajoin_version

result = template.render(template_data)

print(result)

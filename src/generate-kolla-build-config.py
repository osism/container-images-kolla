import os

import jinja2
import yaml

OPENSTACK_VERSION = os.environ.get("OPENSTACK_VERSION", "master")
OSISM_VERSION = os.environ.get("OSISM_VERSION", "latest")

KOLLA_BASE = "ubuntu"
KOLLA_BASE_TAG = os.environ.get("UBUNTU_VERSION", "18.04")
KOLLA_INSTALL_TYPE = "source"

TEMPLATE_FILE = "kolla-build.conf.j2"


# http://stackoverflow.com/questions/4984647/accessing-dict-keys-like-an-attribute-in-python
class AttrDict(dict):
    def __init__(self, *args, **kwargs):
        super(AttrDict, self).__init__(*args, **kwargs)
        self.__dict__ = self


versions = {}
ceilometer_base_plugins = []
neutron_server_plugins = []
neutron_base_plugins = []
horizon_plugins = []
projects = []

filename = "release/%s/openstack-%s.yml" % (OSISM_VERSION, OPENSTACK_VERSION)
with open(filename, "rb") as fp:
    versions = yaml.load(fp, Loader=yaml.FullLoader)

for project in versions['openstack_projects'].keys():
    if project in ['gnocchi', 'novajoin']:
        continue

    repository = project

    if project == "neutron-lbaas-agent":
        repository = "neutron-lbaas"
    elif project == "neutron-vpnaas-agent":
        repository = "neutron-vpnaas"

    projects.append({
        "name": project,
        "version": versions['openstack_projects'][project],
        "repository": repository
    })

if 'horizon_plugins' in versions:
    for project in versions['horizon_plugins'].keys():
        repository = project

        if project == "fwaas-dashboard":
            repository = "neutron-fwaas-dashboard"

        horizon_plugins.append({
            "name": project,
            "version": versions['horizon_plugins'][project],
            "repository": repository
        })

if 'ceilometer_base_plugins' in versions:
    for project in versions['ceilometer_base_plugins'].keys():
        repository = project

        ceilometer_base_plugins.append({
            "name": project,
            "version": versions['ceilometer_base_plugins'][project],
            "repository": repository
        })

if 'neutron_base_plugins' in versions:
    for project in versions['neutron_base_plugins'].keys():
        repository = project

        if project == "vpnaas-agent":
            repository = "neutron-vpnaas"

        neutron_base_plugins.append({
            "name": project,
            "version": versions['neutron_base_plugins'][project],
            "repository": repository
        })

if 'neutron_server_plugins' in versions:
    for project in versions['neutron_server_plugins'].keys():
        repository = project

        if project == "vpnaas-agent":
            repository = "neutron-vpnaas"
        elif project == "ovn-plugin-networking-ovn":
            repository = "networking-ovn"

        neutron_server_plugins.append({
            "name": project,
            "version": versions['neutron_server_plugins'][project],
            "repository": repository
        })

loader = jinja2.FileSystemLoader(searchpath="templates/%s" % OPENSTACK_VERSION)
environment = jinja2.Environment(loader=loader)
template = environment.get_template(TEMPLATE_FILE)

# NOTE: Starting with Victoria, only patched tarballs are included in the
#       kolla-build.conf file.

if versions['openstack_version'] in ["victoria", "wallaby", "master"]:
    patched_projects = os.listdir("patches/%s/" %
                                  versions['openstack_version'])
    projects = [x for x in projects if x['name'] in patched_projects]

template_data = {
    "base": KOLLA_BASE,
    "base_tag": KOLLA_BASE_TAG,
    "horizon_plugins":  horizon_plugins,
    "install_type": KOLLA_INSTALL_TYPE,
    "neutron_server_plugins":  neutron_server_plugins,
    "neutron_base_plugins":  neutron_base_plugins,
    "ceilometer_base_plugins":  ceilometer_base_plugins,
    "openstack_release": versions['openstack_version'],
    "projects": projects,
    "versions": versions,
    "horizon_version": versions['openstack_projects']['horizon'],
    "gnocchi_version": versions['openstack_projects']['gnocchi'],
    "integrated_projects": versions['integrated_projects']
}

if "novajoin" in versions['openstack_projects']:
    novajoin_version = versions['openstack_projects']['novajoin']
    template_data["novajoin_version"] = novajoin_version

result = template.render(template_data)

print(result)

import os
import sys

import yaml

OSISM_VERSION = os.environ.get("OSISM_VERSION", "latest")
OPENSTACK_VERSION = os.environ.get("OPENSTACK_VERSION", "stein")
BUILD_TYPE = os.environ.get("BUILD_TYPE", "all")

OPENSTACK_CORE_PROJECTS = [
    "cinder",
    "designate",
    "glance",
    "heat",
    "horizon",
    "keystone",
    "neutron",
    "nova",
    "octavia",
    "placement",
]

filename = "release/%s/openstack-%s.yml" % (OSISM_VERSION, OPENSTACK_VERSION)
with open(filename, "rb") as fp:
    versions = yaml.load(fp, Loader=yaml.FullLoader)

projects = []

# http://stackoverflow.com/questions/38987/how-to-merge-two-python-dictionaries-in-a-single-expression
if BUILD_TYPE in ["all", "base"]:
    all_projects = versions["openstack_projects"].copy()
    all_projects.update(versions["infrastructure_projects"])
elif BUILD_TYPE == "openstack-core":
    all_projects = [x for x in versions["openstack_projects"] if x in OPENSTACK_CORE_PROJECTS]  # noqa: E501
elif BUILD_TYPE == "openstack-additional":
    all_projects = [x for x in versions["openstack_projects"] if x not in OPENSTACK_CORE_PROJECTS]  # noqa: E501
elif BUILD_TYPE == "infrastructure":
    all_projects = versions["infrastructure_projects"]
    del(all_projects["openstack-base"])
else:
    print("BUILD_TYPE %s not supported" % BUILD_TYPE)
    sys.exit(1)

for project in all_projects:
    if "vpnaas" not in project and "lbaas" not in project:
        projects.append(project)

print("^" + " ^".join(sorted(projects)))

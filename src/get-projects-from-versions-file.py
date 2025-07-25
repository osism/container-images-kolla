# SPDX-License-Identifier: Apache-2.0

import os
import sys

import yaml

BUILD_TYPE = os.environ.get("BUILD_TYPE", "all")
IS_RELEASE = os.environ.get("IS_RELEASE", "False")
OPENSTACK_VERSION = os.environ.get("OPENSTACK_VERSION", "latest")
VERSION = os.environ.get("VERSION", "latest")

OPENSTACK_CORE_PROJECTS = [
    "cinder",
    "designate",
    "glance",
    "horizon",
    "keystone",
    "neutron",
    "nova",
    "octavia",
    "placement",
]

filename = "release/latest/openstack-%s.yml" % OPENSTACK_VERSION
with open(filename, "rb") as fp:
    versions = yaml.load(fp, Loader=yaml.FullLoader)

projects = []

# http://stackoverflow.com/questions/38987/how-to-merge-two-python-dictionaries-in-a-single-expression
if BUILD_TYPE in ["all", "base"]:
    all_projects = versions["openstack_projects"].copy()
    all_projects.update(versions["infrastructure_projects"])

elif BUILD_TYPE == "openstack-core":
    all_projects = [
        x for x in versions["openstack_projects"] if x in OPENSTACK_CORE_PROJECTS
    ]  # noqa: E501

elif BUILD_TYPE == "openstack-additional":
    all_projects = [
        x for x in versions["openstack_projects"] if x not in OPENSTACK_CORE_PROJECTS
    ]  # noqa: E501

elif BUILD_TYPE == "infrastructure":
    all_projects = versions["infrastructure_projects"]
    del all_projects["openstack-base"]

else:
    print("BUILD_TYPE %s not supported" % BUILD_TYPE)
    sys.exit(1)

if "openstack_projects_filter" in versions:
    openstack_projects_filter = versions["openstack_projects_filter"]
else:
    openstack_projects_filter = []

if IS_RELEASE == "True":
    next_filename = f"release/next/kolla-{VERSION}.yml"
    if os.path.exists(next_filename):
        with open(next_filename, "rb") as fp:
            next_overwrites = yaml.load(fp, Loader=yaml.FullLoader)
            if "openstack_projects_filter" in next_overwrites:
                openstack_projects_filter.extend(
                    next_overwrites["openstack_projects_filter"]
                )

# This allows us to only rebuild some images for minor releases and
# not to rebuild all images.
if openstack_projects_filter:
    for project in all_projects:
        if (
            "vpnaas" not in project
            and "lbaas" not in project
            and "dynamic-routing" not in project
            and project in versions["openstack_projects_filter"]
        ):
            projects.append(project)
else:
    for project in all_projects:
        if (
            "vpnaas" not in project
            and "lbaas" not in project
            and "dynamic-routing" not in project
        ):
            projects.append(project)

print("^" + " ^".join(sorted(projects)))

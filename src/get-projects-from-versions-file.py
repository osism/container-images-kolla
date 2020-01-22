import os

import yaml

OSISM_VERSION = os.environ.get("OSISM_VERSION", "latest")
OPENSTACK_VERSION = os.environ.get("OPENSTACK_VERSION", "rocky")

filename = "release/%s/openstack-%s.yml" % (OSISM_VERSION, OPENSTACK_VERSION)
with open(filename, "rb") as fp:
    versions = yaml.load(fp, Loader=yaml.FullLoader)

projects = []

# http://stackoverflow.com/questions/38987/how-to-merge-two-python-dictionaries-in-a-single-expression
all_projects = versions["openstack_projects"].copy()
all_projects.update(versions["infrastructure_projects"])

for project in all_projects:
    if "vpnaas" not in project and "lbaas" not in project:
        projects.append(project)

print(" ".join(sorted(projects)))

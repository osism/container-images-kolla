# SPDX-License-Identifier: Apache-2.0

import os

import jinja2
import yaml

OPENSTACK_VERSION = os.environ.get("OPENSTACK_VERSION", "latest")
VERSION = os.environ.get("VERSION", "latest")

if OPENSTACK_VERSION in ["2023.2", "2024.1"]:
    TEMPLATE_FILE = "apt_preferences.ubuntu.j2"
else:
    TEMPLATE_FILE = "apt_preferences.debian.j2"


# http://stackoverflow.com/questions/4984647/accessing-dict-keys-like-an-attribute-in-python
class AttrDict(dict):
    def __init__(self, *args, **kwargs):
        super(AttrDict, self).__init__(*args, **kwargs)
        self.__dict__ = self


filename = "release/%s/openstack-%s.yml" % (VERSION, OPENSTACK_VERSION)
with open(filename, "rb") as fp:
    versions = yaml.load(fp, Loader=yaml.FullLoader)

loader = jinja2.FileSystemLoader(searchpath="templates/%s" % OPENSTACK_VERSION)
environment = jinja2.Environment(loader=loader)
template = environment.get_template(TEMPLATE_FILE)

template_data = {"infrastructure_projects": versions["infrastructure_projects"]}

result = template.render(template_data)
print(result)

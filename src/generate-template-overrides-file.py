import datetime
import os

from mako.template import Template
import yaml

HASH_DOCKER_IMAGES_KOLLA = os.environ.get("HASH_DOCKER_IMAGES_KOLLA", "none")
HASH_KOLLA = os.environ.get("HASH_KOLLA", "none")
HASH_RELEASE = os.environ.get("HASH_RELEASE", "none")
KOLLA_VERSION = os.environ.get("KOLLA_VERSION", "none")
OPENSTACK_VERSION = os.environ.get("OPENSTACK_VERSION", "latest")
VERSION = os.environ.get("VERSION", "latest")

filename = "release/%s/openstack-%s.yml" % (VERSION, OPENSTACK_VERSION)
with open(filename, "rb") as fp:
    versions = yaml.load(fp, Loader=yaml.FullLoader)

filename = "templates/%s/template-overrides.mako" % OPENSTACK_VERSION
template = Template(filename=filename)
data = {
    "created": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "hash_docker_images_kolla": HASH_DOCKER_IMAGES_KOLLA,
    "hash_kolla": HASH_KOLLA,
    "hash_release": HASH_RELEASE,
    "infrastructure_projects": versions["infrastructure_projects"],
    "kolla_version": KOLLA_VERSION,
    "openstack_version": OPENSTACK_VERSION,
    "version": VERSION,
}
result = template.render(**data)
print(result)

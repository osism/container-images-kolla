import datetime
import os

from mako.template import Template
import yaml

HASH_DOCKER_KOLLA_DOCKER = os.environ.get("HASH_DOCKER_KOLLA_DOCKER", "none")
HASH_KOLLA = os.environ.get("HASH_KOLLA", "none")
HASH_RELEASE = os.environ.get("HASH_RELEASE", "none")
OPENSTACK_VERSION = os.environ.get("OPENSTACK_VERSION", "stein")
OSISM_VERSION = os.environ.get("OSISM_VERSION", "latest")

filename = "release/%s/openstack-%s.yml" % (OSISM_VERSION, OPENSTACK_VERSION)
with open(filename, "rb") as fp:
    versions = yaml.load(fp, Loader=yaml.FullLoader)

filename = "templates/%s/template-overrides.mako" % OPENSTACK_VERSION
template = Template(filename=filename)
data = {
    'created': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'hash_docker_kolla_docker': HASH_DOCKER_KOLLA_DOCKER,
    'hash_kolla': HASH_KOLLA,
    'hash_release': HASH_RELEASE,
    'infrastructure_projects': versions['infrastructure_projects'],
    'integrated_projects': versions['integrated_projects'],
    'openstack_version': OPENSTACK_VERSION,
    'osism_version': OSISM_VERSION,
}
result = template.render(**data)
print(result)

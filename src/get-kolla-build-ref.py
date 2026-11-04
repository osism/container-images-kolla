# SPDX-License-Identifier: Apache-2.0

# Print one kolla_build ref for OPENSTACK_VERSION from the release manifest.
#
# osism/release declares in latest/openstack-<version>.yml which openstack/kolla
# ref the build checks out (kolla, a git ref) and which openstack/requirements
# tarball it uses (requirements, a tarball ref like the openstack_projects
# refs). Its kolla_source_ref_phase drift check flags either one once upstream
# publishes a later lifecycle phase, so the refs are switched there.

import os
import sys

import yaml

KEYS = ("kolla", "requirements")


def main(argv):
    if len(argv) != 2 or argv[1] not in KEYS:
        print(f"usage: {argv[0]} {{{'|'.join(KEYS)}}}", file=sys.stderr)
        return 2
    key = argv[1]
    openstack_version = os.environ.get("OPENSTACK_VERSION", "latest")
    filename = "release/latest/openstack-%s.yml" % openstack_version
    with open(filename, "rb") as fp:
        versions = yaml.safe_load(fp) or {}
    ref = (versions.get("kolla_build") or {}).get(key)
    if not ref:
        print(f"ERROR: {filename} declares no kolla_build.{key}", file=sys.stderr)
        return 1
    print(ref)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

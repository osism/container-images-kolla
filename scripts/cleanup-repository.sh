#!/usr/bin/env bash

# Available environment variables
#
# OPENSTACK_VERSION

# Set default values

OPENSTACK_VERSION=${OPENSTACK_VERSION:-master}

rm -f images.txt*
rm -f kolla-build-*.log
rm -f kolla-build.conf
rm -f overlays/$OPENSTACK_VERSION/base/apt_preferences.ubuntu
rm -f apt_preferences.ubuntu
rm -f templates/$OPENSTACK_VERSION/template-overrides.j2
rm -f template-overrides.j2
rm -f versions.txt*

rm -rf release tarballs kolla

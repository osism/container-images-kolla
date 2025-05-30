#!/usr/bin/env bash

set -x

# Available environment variables
#
# BASE
# BASE_VERSION
# DOCKER_NAMESPACE
# DOCKER_REGISTRY
# OPENSTACK_VERSION
# VERSION

# Set default values

BASE=${BASE:-ubuntu}
BASE_VERSION=${BASE_VERSION:-22.04}
BUILD_ID=${BUILD_ID:-$(date +%Y%m%d)}
DOCKER_NAMESPACE=${DOCKER_NAMESPACE:-osism}
DOCKER_REGISTRY=${DOCKER_REGISTRY:-quay.io}
OPENSTACK_VERSION=${OPENSTACK_VERSION:-latest}
VERSION=${VERSION:-latest}

# NOTE: For builds for a specific release, the OpenStack version is taken from the release repository.
if [[ $VERSION != "latest" ]]; then
    OPENSTACK_VERSION=$(grep "openstack_version:" release/latest/openstack.yml | awk -F': ' '{ print $2 }' | tr -d '"')
fi

. defaults/all.sh
. defaults/$OPENSTACK_VERSION.sh

export VERSION
export OPENSTACK_VERSION

DOCKER_TAG=build-$BUILD_ID
KOLLA_BASE=$BASE
KOLLA_BASE_TAG=$BASE_VERSION
KOLLA_CONF_FILE=kolla-build.conf
KOLLA_INSTALL_TYPE=source

# Generate configuration

python3 src/generate-kolla-build-config.py > $KOLLA_CONF_FILE

# Prepare configuration

setini () {
    ansible localhost -i localhost, -c local -e ansible_python_interpreter=/usr/bin/python3 -m ini_file -a "path=kolla-build.conf section=$1 option=$2 value=$3"
}

setini DEFAULT namespace $DOCKER_NAMESPACE
setini DEFAULT tag $DOCKER_TAG
setini DEFAULT base $KOLLA_BASE
setini DEFAULT base_tag $KOLLA_BASE_TAG
setini DEFAULT install_type $KOLLA_INSTALL_TYPE
setini openstack-base location https://tarballs.opendev.org/openstack/requirements/requirements-stable-$OPENSTACK_VERSION.tar.gz

if [[ -n $DOCKER_REGISTRY ]]; then
    setini DEFAULT registry $DOCKER_REGISTRY
fi

echo DEBUG kolla-build.conf
cat kolla-build.conf

#!/usr/bin/env bash
set -x

# Available environment variables
#
# DOCKER_NAMESPACE
# DOCKER_REGISTRY
# OPENSTACK_VERSION
# UBUNTU_VERSION

# Set default values

BUILD_ID=${BUILD_ID:-$(date +%Y%m%d)}
DOCKER_NAMESPACE=${DOCKER_NAMESPACE:-osism}
DOCKER_REGISTRY=${DOCKER_REGISTRY:-quay.io}
OPENSTACK_VERSION=${OPENSTACK_VERSION:-rocky}
UBUNTU_VERSION=${UBUNTU_VERSION:-18.04}

DOCKER_TAG=build-$BUILD_ID
KOLLA_BASE=ubuntu
KOLLA_BASE_TAG=$UBUNTU_VERSION
KOLLA_CONF_FILE=kolla-build.conf
KOLLA_INSTALL_TYPE=source

# Prepare environment

source venv/bin/activate

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
setini openstack-base location http://tarballs.openstack.org/requirements/requirements-stable-$OPENSTACK_VERSION.tar.gz

if [[ -n $DOCKER_REGISTRY ]]; then
    setini DEFAULT registry $DOCKER_REGISTRY
fi

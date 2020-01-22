#!/usr/bin/env bash
set -x

# Available environment variables
#
# BUILD_ID
# DOCKER_NAMESPACE
# OPENSTACK_VERSION
# OSISM_VERSION

# Set default values

BUILD_ID=${BUILD_ID:-$(date +%Y%m%d)}
DOCKER_NAMESPACE=${DOCKER_NAMESPACE:-osism}
OPENSTACK_VERSION=${OPENSTACK_VERSION:-rocky}
OSISM_VERSION=${OSISM_VERSION:-latest}

KOLLA_TYPE=ubuntu-source
SOURCE_DOCKER_TAG=build-$BUILD_ID

HASH_DOCKER_KOLLA_DOCKER=$(git rev-parse --short HEAD)
HASH_RELEASE=$(cd release; git rev-parse --short HEAD)

if [[ $(git rev-parse --abbrev-ref HEAD) == "master" ]]; then
    OSISM_VERSION=latest
else
    tag=$(git describe --exact-match HEAD)
    OSISM_VERSION=${tag:1}
fi

docker system prune \
  --all \
  --force \
  --filter "label=io.osism.docker_kolla_docker=$HASH_DOCKER_KOLLA_DOCKER" \
  --filter "label=io.osism.openstack=$OPENSTACK_VERSION" \
  --filter "label=io.osism.release=$HASH_RELEASE"

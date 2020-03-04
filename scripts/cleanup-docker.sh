#!/usr/bin/env bash

# Available environment variables
#
# OPENSTACK_VERSION

# Set default values

OPENSTACK_VERSION=${OPENSTACK_VERSION:-master}

HASH_DOCKER_KOLLA_DOCKER=$(git rev-parse --short HEAD)
HASH_RELEASE=$(cd release; git rev-parse --short HEAD)

docker system prune \
  --all \
  --force \
  --filter "label=de.osism.commit.docker_kolla_docker=$HASH_DOCKER_KOLLA_DOCKER" \
  --filter "label=de.osism.commit.release=$HASH_RELEASE" \
  --filter "label=de.osism.release.openstack=$OPENSTACK_VERSION"

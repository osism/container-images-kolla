#!/usr/bin/env bash

# Available environment variables
#
# OPENSTACK_VERSION

# Set default values

OPENSTACK_VERSION=${OPENSTACK_VERSION:-latest}

HASH_DOCKER_IMAGES_KOLLA=$(git rev-parse --short HEAD)
HASH_RELEASE=$(cd release; git rev-parse --short HEAD)

docker system prune \
  --all \
  --force \
  --filter "label=de.osism.commit.docker_images_kolla=$HASH_DOCKER_IMAGES_KOLLA" \
  --filter "label=de.osism.commit.release=$HASH_RELEASE" \
  --filter "label=de.osism.release.openstack=$OPENSTACK_VERSION"

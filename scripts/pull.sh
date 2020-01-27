#!/usr/bin/env bash
set -x

# Available environment variables
#
# BUILD_ID
# BUILD_TYPE
# DOCKER_NAMESPACE
# DOCKER_REGISTRY
# KOLLA_IMAGES
# OPENSTACK_VERSION
# OSISM_VERSION

# Set default values

BUILD_ID=${BUILD_ID:-$(date +%Y%m%d)}
BUILD_TYPE=${BUILD_TYPE:-all}
DOCKER_NAMESPACE=${DOCKER_NAMESPACE:-osism}
DOCKER_REGISTRY=${DOCKER_REGISTRY:-quay.io}
OPENSTACK_VERSION=${OPENSTACK_VERSION:-rocky}
OSISM_VERSION=${OSISM_VERSION:-latest}

KOLLA_TYPE=ubuntu-source
SOURCE_DOCKER_TAG=build-$BUILD_ID

if [[ $(git name-rev --name-only HEAD) == "master" ]]; then
    OSISM_VERSION=latest
else
    tag=$(git describe --exact-match HEAD)
    OSISM_VERSION=${tag:1}
fi

if [[ -z "$KOLLA_IMAGES" || $KOLLA_IMAGES == "all" ]]; then
    KOLLA_IMAGES+=" $(python3 src/get-projects-from-versions-file.py)"
fi

docker pull $DOCKER_REGISTRY/$DOCKER_NAMESPACE/base:$OPENSTACK_VERSION-$OSISM_VERSION
docker pull $DOCKER_REGISTRY/$DOCKER_NAMESPACE/openstack-base:$OPENSTACK_VERSION-$OSISM_VERSION

docker tag $DOCKER_REGISTRY/$DOCKER_NAMESPACE/base:$OPENSTACK_VERSION-$OSISM_VERSION $DOCKER_REGISTRY/$DOCKER_NAMESPACE/$KOLLA_TYPE-base:$SOURCE_DOCKER_TAG
docker tag $DOCKER_REGISTRY/$DOCKER_NAMESPACE/openstack-base:$OPENSTACK_VERSION-$OSISM_VERSION $DOCKER_REGISTRY/$DOCKER_NAMESPACE/$KOLLA_TYPE-openstack-base:$SOURCE_DOCKER_TAG

for baseimage in $(find kolla/docker -name '*-base' | sort | xargs -n1 basename | awk -F - '{print $1}'); do
    if [[ $KOLLA_IMAGES == *"$baseimage"* ]]; then
        docker pull $DOCKER_REGISTRY/$DOCKER_NAMESPACE/${baseimage}-base:$OPENSTACK_VERSION-$OSISM_VERSION
        docker tag $DOCKER_REGISTRY/$DOCKER_NAMESPACE/${baseimage}-base:$OPENSTACK_VERSION-$OSISM_VERSION $DOCKER_REGISTRY/$DOCKER_NAMESPACE/$KOLLA_TYPE-${baseimage}-base:$SOURCE_DOCKER_TAG
    fi
done

echo
docker images
echo

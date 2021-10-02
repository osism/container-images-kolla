#!/usr/bin/env bash

set -x

# Available environment variables
#
# DOCKER_NAMESPACE
# DOCKER_REGISTRY
# OPENSTACK_VERSION
# VERSION

# Set default values

DOCKER_NAMESPACE=${DOCKER_NAMESPACE:-osism}
DOCKER_REGISTRY=${DOCKER_REGISTRY:-quay.io}
OPENSTACK_VERSION=${OPENSTACK_VERSION:-latest}
VERSION=${VERSION:-latest}

# NOTE: For builds for a specific release, the OpenStack version is taken from the release repository.
if [[ $VERSION != "latest" ]]; then
    filename=$(curl -L https://raw.githubusercontent.com/osism/release/master/$VERSION/openstack.yml)
    OPENSTACK_VERSION=$(curl -L https://raw.githubusercontent.com/osism/release/master/$VERSION/$filename | grep "openstack_version:" | awk -F': ' '{ print $2 }')
fi

. defaults/$OPENSTACK_VERSION.sh

pushd contrib/horizon

docker buildx build \
    --load \
    --build-arg "DOCKER_NAMESPACE=$DOCKER_NAMESPACE" \
    --build-arg "DOCKER_REGISTRY=$DOCKER_REGISTRY" \
    --build-arg "OPENSTACK_VERSION=$OPENSTACK_VERSION" \
    --tag "${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/horizon:finalized" \
    $BUILD_OPTS .

docker rmi -f "${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/horizon:${OPENSTACK_VERSION}"
docker tag "${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}:horizon:finalized" "${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/horizon:${OPENSTACK_VERSION}"

popd

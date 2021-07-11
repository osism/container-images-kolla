#!/usr/bin/env bash

set -x

# Available environment variables
#
# BUILD_ID
# BUILD_OPTS
# BUILD_TYPE
# KOLLA_IMAGES
# OPENSTACK_VERSION
# SQUASH
# VERSION

# Set default values

BUILD_ID=${BUILD_ID:-$(date +%Y%m%d)}
BUILD_TYPE=${BUILD_TYPE:-all}
OPENSTACK_VERSION=${OPENSTACK_VERSION:-latest}
VERSION=${VERSION:-latest}
SQUASH=${SQUASH:-false}

KOLLA_CONF=kolla-build.conf

# NOTE: For builds for a specific release, the OpenStack version is taken from the release repository.
if [[ $VERSION != "latest" ]]; then
    filename=$(curl -L https://raw.githubusercontent.com/osism/release/master/$VERSION/openstack.yml)
    OPENSTACK_VERSION=$(curl -L https://raw.githubusercontent.com/osism/release/master/$VERSION/$filename | grep "openstack_version:" | awk -F': ' '{ print $2 }')
fi

. defaults/$OPENSTACK_VERSION.sh

if [[ $SQUASH == "true" ]]; then
    BUILD_OPTS+=" --squash"
fi

if [[ -z "$KOLLA_IMAGES" ]]; then
    KOLLA_IMAGES="$(python3 src/get-projects-from-versions-file.py)"
fi

# Build images

if [[ $BUILD_TYPE == "base" ]]; then
    KOLLA_IMAGES_BASE=""
    for baseimage in $(find kolla/docker -name '*-base' | sort | xargs -n1 basename | awk -F - '{print $1}'); do
        if [[ $KOLLA_IMAGES == *"$baseimage"* ]]; then
            KOLLA_IMAGES_BASE+=" ${baseimage}-base"
        fi
    done

    kolla-build \
      --template-override templates/$OPENSTACK_VERSION/template-overrides.j2 \
      --config-file $KOLLA_CONF \
      --pull \
      $BUILD_OPTS \
      $KOLLA_IMAGES_BASE 2>&1 | tee kolla-build-$BUILD_ID.log
else
    kolla-build \
      --template-override templates/$OPENSTACK_VERSION/template-overrides.j2 \
      --config-file $KOLLA_CONF \
      --skip-existing \
      $BUILD_OPTS \
      $KOLLA_IMAGES 2>&1 | tee kolla-build-$BUILD_ID.log
fi

docker images

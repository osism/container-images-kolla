#!/usr/bin/env bash

# Available environment variables
#
# BUILD_ID
# BUILD_TYPE
# KOLLA_IMAGES
# OPENSTACK_VERSION
# SQUASH

# Set default values

BUILD_ID=${BUILD_ID:-$(date +%Y%m%d)}
BUILD_TYPE=${BUILD_TYPE:-all}
OPENSTACK_VERSION=${OPENSTACK_VERSION:-master}
SQUASH=${SQUASH:-true}

KOLLA_CONF=kolla-build.conf

if [[ $(git name-rev --name-only HEAD) == "master" ]]; then
    SQUASH=false
fi

if [[ $SQUASH == "true" ]]; then
    extraopts+=" --squash"
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
      $extraopts \
      $KOLLA_IMAGES_BASE 2>&1 | tee kolla-build-$BUILD_ID.log
else
    kolla-build \
      --template-override templates/$OPENSTACK_VERSION/template-overrides.j2 \
      --config-file $KOLLA_CONF \
      --skip-existing \
      $extraopts \
      $KOLLA_IMAGES 2>&1 | tee kolla-build-$BUILD_ID.log
fi

docker images

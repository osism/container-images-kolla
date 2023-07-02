#!/usr/bin/env bash

set -x

# Available environment variables
#
# BUILD_ID
# BUILD_OPTS
# KOLLA_IMAGES
# OPENSTACK_VERSION
# VERSION

# Set default values

BUILD_ID=${BUILD_ID:-$(date +%Y%m%d)}
OPENSTACK_VERSION=${OPENSTACK_VERSION:-latest}
VERSION=${VERSION:-latest}

KOLLA_CONF=kolla-build.conf

# NOTE: For builds for a specific release, the OpenStack version is taken from the release repository.
if [[ $VERSION != "latest" ]]; then
    OPENSTACK_VERSION=$(grep "openstack_version:" release/$VERSION/openstack.yml | awk -F': ' '{ print $2 }')
fi

. defaults/all.sh
. defaults/$OPENSTACK_VERSION.sh

export VERSION
export OPENSTACK_VERSION

if [[ -z "$KOLLA_IMAGES" ]]; then
    KOLLA_IMAGES="$(python3 src/get-projects-from-versions-file.py)"
fi

KOLLA_IMAGES_BASE=""
for baseimage in $(find kolla/docker -name '*-base' | sort | xargs -n1 basename | awk -F - '{print $1}'); do
    if [[ $KOLLA_IMAGES == *"$baseimage"* ]]; then
        KOLLA_IMAGES_BASE+=" ${baseimage}-base"
    fi
done

# Build & squash base images

kolla-build \
  --template-override templates/$OPENSTACK_VERSION/template-overrides.j2 \
  --config-file $KOLLA_CONF \
  --pull \
  --squash \
  $BUILD_OPTS \
  $KOLLA_IMAGES_BASE 2>&1 | tee kolla-build-$BUILD_ID.log

# Build images

kolla-build \
  --template-override templates/$OPENSTACK_VERSION/template-overrides.j2 \
  --config-file $KOLLA_CONF \
  --skip-existing \
  $BUILD_OPTS \
  $KOLLA_IMAGES 2>&1 | tee kolla-build-$BUILD_ID.log

if grep -q "Failed with status: error" kolla-build-$BUILD_ID.log; then
    echo "ERROR: Not all the required images could be built."
    exit 1
fi

docker images

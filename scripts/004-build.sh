#!/usr/bin/env bash

set -x

# Available environment variables
#
# BASE_ARCH
# BUILD_ID
# BUILD_OPTS
# BUILD_TYPE
# KOLLA_IMAGES
# OPENSTACK_VERSION
# VERSION

# Set default values

BASE_ARCH=${BASE_ARCH:-x86_64}
BUILD_ID=${BUILD_ID:-$(date +%Y%m%d)}
BUILD_TYPE=${BUILD_TYPE:-all}
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

# For ARM64 we currently only support the images that are required on the compute plane.
if [[ "$BASE_ARCH" == "aarch64" ]]; then
    KOLLA_IMAGES="^fluentd ^cron ^nova-libvirt ^nova-ssh ^nova-compute ^neutron-metadata-agent ^ceilometer-compute ^ovn-controller ^openvswitch-vswitchd ^openvswitch-db-server ^kolla-toolbox ^nova-conductor"
    PLATFORM="linux/arm64"
    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
elif [[ -z "$KOLLA_IMAGES" ]]; then
    KOLLA_IMAGES="$(python3 src/get-projects-from-versions-file.py)"
    PLATFORM="linux/amd64"
fi

if [[ "$OPENSTACK_VERSION" == "2024.1" || "$OPENSTACK_VERSION" == "2024.2" ]]; then
    PLATFORM_OPTS="--platform $PLATFORM"
fi

KOLLA_IMAGES="^openvswitch"

# Build images

if [[ $BUILD_TYPE == "base" ]]; then
    KOLLA_IMAGES_BASE=""
    for baseimage in $(find kolla/docker -name '*-base' | sort | xargs -n1 basename | awk -F - '{print $1}'); do
        if [[ $KOLLA_IMAGES == *"$baseimage"* ]]; then
            KOLLA_IMAGES_BASE+=" ${baseimage}-base"
        fi
    done

    kolla-build \
      --base-arch $BASE_ARCH \
      --debug \
      --template-override templates/$OPENSTACK_VERSION/template-overrides.j2 \
      --config-file $KOLLA_CONF \
      --pull \
      $PLATFORM_OPTS \
      $BUILD_OPTS \
      $KOLLA_IMAGES_BASE 2>&1 | tee kolla-build-$BUILD_ID.log
else
    kolla-build \
      --base-arch $BASE_ARCH \
      --debug \
      --template-override templates/$OPENSTACK_VERSION/template-overrides.j2 \
      --config-file $KOLLA_CONF \
      --skip-existing \
      $PLATFORM_OPTS \
      $BUILD_OPTS \
      $KOLLA_IMAGES 2>&1 | tee kolla-build-$BUILD_ID.log
fi

if grep -q "Failed with status: error" kolla-build-$BUILD_ID.log; then
    echo "ERROR: Not all the required images could be built."
    exit 1
fi

docker images

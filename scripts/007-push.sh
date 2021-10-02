#!/usr/bin/env bash

set -x

# Available environment variables
#
# BUILD_TYPE
# DOCKER_PUSH_JOBS
# PUSH
# VERSION

# Set default values

BUILD_TYPE=${BUILD_TYPE:-all}
DOCKER_PUSH_JOBS=${DOCKER_PUSH_JOBS:-2}
PUSH=${PUSH:-true}
VERSION=${VERSION:-latest}

LSTFILE=images.txt

# NOTE: For builds for a specific release, the OpenStack version is taken from the release repository.
if [[ $VERSION != "latest" ]]; then
    filename=$(curl -L https://raw.githubusercontent.com/osism/release/master/$VERSION/openstack.yml)
    OPENSTACK_VERSION=$(curl -L https://raw.githubusercontent.com/osism/release/master/$VERSION/$filename | grep "openstack_version:" | awk -F': ' '{ print $2 }')
fi

. defaults/$OPENSTACK_VERSION.sh

export VERSION
export OPENSTACK_VERSION

if [[ $BUILD_TYPE == "base" ]]; then
    # push the base image
    while read image; do
        if [[ $(echo $image | grep '\/base:') ]]; then
            docker push $image
        fi
    done < $LSTFILE

    # push the openstack-base image
    while read image; do
        if [[ $(echo $image | grep '\/openstack-base:') ]]; then
            docker push $image
        fi
    done < $LSTFILE

    # push all other base images
    cat $LSTFILE | grep base | grep -v '\/openstack-base:' | grep -v '\/base:' | \
        parallel --load 100% --progress --retries 3 --joblog base.log -j$DOCKER_PUSH_JOBS docker push {} ">" /dev/null

    cat base.log

fi

if [[ $PUSH == "true" ]]; then
    # push all other images
    cat $LSTFILE | grep -v base | \
        parallel --load 100% --progress --retries 3 --joblog other.log -j$DOCKER_PUSH_JOBS docker push {} ">" /dev/null

    cat other.log
fi

#!/usr/bin/env bash

# Available environment variables
#
# BUILD_TYPE
# DOCKER_PUSH_JOBS
# PUSH

# Set default values

BUILD_TYPE=${BUILD_TYPE:-all}
DOCKER_PUSH_JOBS=${DOCKER_PUSH_JOBS:-4}
PUSH=${PUSH:-true}

LSTFILE=images.txt

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

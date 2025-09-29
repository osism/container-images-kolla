#!/usr/bin/env bash

set -x

# Available environment variables
#
# BUILD_TYPE
# DOCKER_PUSH_JOBS

# Set default values

BUILD_TYPE=${BUILD_TYPE:-all}
DOCKER_PUSH_JOBS=${DOCKER_PUSH_JOBS:-8}

LSTFILE=images.txt

# push base images
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
        parallel --retries 3 --joblog base.log -j$DOCKER_PUSH_JOBS docker push {} ">" /dev/null

    cat base.log

fi

# push all other images
cat $LSTFILE | grep -v base > images.lst
cat images.lst | \
  parallel --retries 3 --joblog other.log -j$DOCKER_PUSH_JOBS docker push {} ">" /dev/null
cat other.log

#!/usr/bin/env bash
set -x

# Available environment variables
#
# BASEPUSH
# DOCKER_PUSH_JOBS
# PUSH

# Set default values

BASEPUSH=${BASEPUSH:-true}
DOCKER_PUSH_JOBS=${DOCKER_PUSH_JOBS:-8}
PUSH=${PUSH:-true}

LSTFILE=images.txt

if [[ $BASEPUSH == "true" ]]; then
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
        grep -v prometheus | grep -v ironic-neutron-agent | \
        parallel -j$DOCKER_PUSH_JOBS docker push
fi

if [[ $PUSH == "true" ]]; then
    # push all other images
    cat $LSTFILE | grep -v base | \
        grep -v prometheus | grep -v ironic-neutron-agent | \
        parallel -j$DOCKER_PUSH_JOBS docker push
fi

#!/usr/bin/env bash

set -x

# Available environment variables
#
# BUILD_TYPE
# DOCKER_PUSH_JOBS
# PUSH_LOG_DIR

# Set default values

BUILD_TYPE=${BUILD_TYPE:-all}
DOCKER_PUSH_JOBS=${DOCKER_PUSH_JOBS:-8}

LSTFILE=images.txt

PUSH_LOG_DIR=${PUSH_LOG_DIR:-push-logs}
export PUSH_LOG_DIR

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PUSH_ONE=$SCRIPT_DIR/push-one.sh

# Header for the per-attempt record push-one.sh appends to. Written once
# here rather than by the workers, which would race.
mkdir -p "$PUSH_LOG_DIR" 2>/dev/null || true
printf 'event\timage\ttime\tduration\texit\tsize\tlayers\n' \
    > "$PUSH_LOG_DIR/attempts.tsv" 2>/dev/null || true

RETRIES=3

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
        parallel --retries $RETRIES --joblog base.log -j$DOCKER_PUSH_JOBS "$PUSH_ONE" {}

    cat base.log

fi

# push all other images
cat $LSTFILE | grep -v base > images.lst
cat images.lst | \
  parallel --retries $RETRIES --joblog other.log -j$DOCKER_PUSH_JOBS "$PUSH_ONE" {}
cat other.log

# Exit 0 even when pushes failed, deliberately. build.yml runs this under
# set -e, so a non-zero exit here would skip 120-check-and-repush.sh --
# the pass that re-pushes what is missing, and the one that actually fails
# the job on incomplete publication. Do not "fix" this into set -e.
exit 0

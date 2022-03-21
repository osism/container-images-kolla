#!/usr/bin/env bash

set -x

# Available environment variables
#
# DOCKER_PUSH_JOBS

DOCKER_PUSH_JOBS=${DOCKER_PUSH_JOBS:-4}

cat images.lst | \
    parallel --load 100% --progress --retries 3 --joblog images.log -j$DOCKER_PUSH_JOBS docker push {} ">" /dev/null
cat images.log

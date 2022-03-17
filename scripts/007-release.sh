#!/usr/bin/env bash

set -x

# Available environment variables
#
# DOCKER_PUSH_JOBS

DOCKER_PUSH_JOBS=${DOCKER_PUSH_JOBS:-4}

cat tag-images-with-the-version.lst | \
    parallel --load 100% --progress --retries 3 --joblog tag-images-with-the-version.log -j$DOCKER_PUSH_JOBS docker push {} ">" /dev/null
cat tag-images-with-the-version.log

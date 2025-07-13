#!/usr/bin/env bash

set -x

# Available environment variables
#
# DOCKER_PUSH_JOBS

DOCKER_PUSH_JOBS=${DOCKER_PUSH_JOBS:-4}

cat images.lst | \
    parallel --load 100% --progress --retries 3 --joblog images.log -j$DOCKER_PUSH_JOBS docker push {} ">" /dev/null
cat images.log

for image in $(cat images.lst); do
    curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
    chmod +x cosign-linux-amd64
    ./cosign-linux-amd64 sign --yes --key env://COSIGN_PRIVATE_KEY "$image"
done

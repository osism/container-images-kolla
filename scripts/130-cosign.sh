#!/usr/bin/env bash

set -x

LSTFILE=images.lst

curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
chmod +x cosign-linux-amd64

for image in $(cat $LSTFILE); do
    ./cosign-linux-amd64 sign --yes --key env://COSIGN_PRIVATE_KEY "$image"
done

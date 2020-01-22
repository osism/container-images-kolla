#!/usr/bin/env bash
#set -x
source venv/bin/activate

# Available environment variables
#
# KOLLA_IMAGES
# OPENSTACK_VERSION
# OSISM_VERSION

# Set default values

OPENSTACK_VERSION=${OPENSTACK_VERSION:-rocky}
OSISM_VERSION=${OSISM_VERSION:-latest}

if [[ $(git rev-parse --abbrev-ref HEAD) == "master" && -z "$KOLLA_IMAGES" ]]; then
    KOLLA_IMAGES=horizon
fi

if [[ $(git rev-parse --abbrev-ref HEAD) == "master" ]]; then
    OSISM_VERSION=latest
else
    tag=$(git describe --exact-match HEAD)
    OSISM_VERSION=${tag:1}
fi

if [[ -z "$KOLLA_IMAGES" || $KOLLA_IMAGES == "all" ]]; then
    KOLLA_IMAGES+=" $(python3 src/get-projects-from-versions-file.py)"
fi

docker pull osism/base:$OPENSTACK_VERSION-$OSISM_VERSION

for baseimage in $(find kolla/docker -name '*-base' | sort | xargs -n1 basename | awk -F - '{print $1}'); do
    if [[ $KOLLA_IMAGES == *"$baseimage"* ]]; then
        docker pull osism/${baseimage}-base:$OPENSTACK_VERSION-$OSISM_VERSION
    fi
done

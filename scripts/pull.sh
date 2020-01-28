#!/usr/bin/env bash

# Available environment variables
#
# BUILD_ID
# BUILD_TYPE
# DOCKER_NAMESPACE
# DOCKER_PULL_JOBS
# DOCKER_REGISTRY
# KOLLA_IMAGES
# OPENSTACK_VERSION
# OSISM_VERSION

# Set default values

BUILD_ID=${BUILD_ID:-$(date +%Y%m%d)}
BUILD_TYPE=${BUILD_TYPE:-all}
DOCKER_NAMESPACE=${DOCKER_NAMESPACE:-osism}
DOCKER_PULL_JOBS=${DOCKER_PULL_JOBS:-4}
DOCKER_REGISTRY=${DOCKER_REGISTRY:-quay.io}
OPENSTACK_VERSION=${OPENSTACK_VERSION:-master}
OSISM_VERSION=${OSISM_VERSION:-latest}

KOLLA_TYPE=ubuntu-source
SOURCE_DOCKER_TAG=build-$BUILD_ID

if [[ $(git name-rev --name-only HEAD) == "master" ]]; then
    OSISM_VERSION=latest
else
    tag=$(git describe --exact-match HEAD)
    OSISM_VERSION=${tag:1}
fi

if [[ -z "$KOLLA_IMAGES" || $KOLLA_IMAGES == "all" ]]; then
    KOLLA_IMAGES+=" $(python3 src/get-projects-from-versions-file.py)"
fi

if [[ "$OPENSTACK_VERSION" == "master" ]]; then
    tag=latest
else
    tag=$OPENSTACK_VERSION-$OSISM_VERSION
fi

for baseimage in base openstack-base; do
    echo "$DOCKER_REGISTRY/$DOCKER_NAMESPACE/$baseimage:$tag" >> pull.lst
    echo $baseimage >> tag.lst
done

for baseimage in $(find kolla/docker -name '*-base' | sort | xargs -n1 basename | awk -F - '{print $1}'); do
    if [[ $KOLLA_IMAGES == *"$baseimage"* ]]; then
        echo "$DOCKER_REGISTRY/$DOCKER_NAMESPACE/${baseimage}-base:$tag" >> pull.lst
        echo ${baseimage}-base >> tag.lst
    fi
done

cat pull.lst | parallel --load 100% --progress --retries 3 --joblog pull.log -j$DOCKER_PULL_JOBS docker pull {} ">" /dev/null
cat pull.log

while read image; do
    docker tag $DOCKER_REGISTRY/$DOCKER_NAMESPACE/${image}:$tag $DOCKER_REGISTRY/$DOCKER_NAMESPACE/$KOLLA_TYPE-${image}:$SOURCE_DOCKER_TAG
done < tag.lst

docker images

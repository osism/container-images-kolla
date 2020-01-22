#!/usr/bin/env bash
set -x

# Available environment variables
#
# BUILD_ID
# DOCKER_NAMESPACE
# DOCKER_REGISTRY
# OPENSTACK_VERSION
# OSISM_VERSION

# Set default values

BUILD_ID=${BUILD_ID:-$(date +%Y%m%d)}
DOCKER_NAMESPACE=${DOCKER_NAMESPACE:-osism}
DOCKER_REGISTRY=${DOCKER_REGISTRY:-quay.io}
OPENSTACK_VERSION=${OPENSTACK_VERSION:-rocky}
OSISM_VERSION=${OSISM_VERSION:-latest}

KOLLA_TYPE=ubuntu-source
LSTFILE=images.txt
SOURCE_DOCKER_TAG=build-$BUILD_ID

if [[ $(git rev-parse --abbrev-ref HEAD) == "master" ]]; then
    OSISM_VERSION=latest
else
    tag=$(git describe --exact-match HEAD)
    OSISM_VERSION=${tag:1}
fi

rm -f $LSTFILE
touch $LSTFILE

docker images | grep $DOCKER_NAMESPACE | grep $KOLLA_TYPE | grep $SOURCE_DOCKER_TAG | awk '{ print $1 }' | while read image; do
    imagename=$(echo $image | awk -F/ '{ print $NF }')
    new_imagename=${imagename#${KOLLA_TYPE}-}

    # http://stackoverflow.com/questions/12766406/how-to-get-the-first-part-of-the-string-in-bash
    project=${new_imagename%%-*}

    new_imagename="$DOCKER_NAMESPACE/$new_imagename"
    if [[ ! -z $DOCKER_REGISTRY ]]; then
        new_imagename="$DOCKER_REGISTRY/$new_imagename"
    fi

    docker tag $image:$SOURCE_DOCKER_TAG $new_imagename:$OPENSTACK_VERSION-$OSISM_VERSION
    echo "$new_imagename:$OPENSTACK_VERSION-$OSISM_VERSION" >> $LSTFILE
done

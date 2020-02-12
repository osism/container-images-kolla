#!/usr/bin/env bash

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
OPENSTACK_VERSION=${OPENSTACK_VERSION:-master}
OSISM_VERSION=${OSISM_VERSION:-latest}

KOLLA_TYPE=ubuntu-source
LSTFILE=images.txt
SOURCE_DOCKER_TAG=build-$BUILD_ID

if [[ $(git name-rev --name-only HEAD) == "master" ]]; then
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

    if [[ "$OPENSTACK_VERSION" == "master" ]]; then
        tag=latest
        docker tag $image:$SOURCE_DOCKER_TAG $new_imagename:$tag
        echo "$new_imagename:$tag" >> $LSTFILE
    else
        tag=$OPENSTACK_VERSION-$OSISM_VERSION
        docker tag $image:$SOURCE_DOCKER_TAG $new_imagename:$tag
        echo "$new_imagename:$tag" >> $LSTFILE

        tag=$OPENSTACK_VERSION
        docker tag $image:$SOURCE_DOCKER_TAG $new_imagename:$tag
        echo "$new_imagename:$tag" >> $LSTFILE
    fi

done

docker images

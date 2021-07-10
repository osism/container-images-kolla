#!/usr/bin/env bash

set -x

# Available environment variables
#
# BUILD_ID
# DOCKER_NAMESPACE
# DOCKER_REGISTRY
# OPENSTACK_VERSION
# OSISM_VERSION
# VERSION

# Set default values

BUILD_ID=${BUILD_ID:-$(date +%Y%m%d)}
DOCKER_NAMESPACE=${DOCKER_NAMESPACE:-osism}
DOCKER_REGISTRY=${DOCKER_REGISTRY:-quay.io}
OPENSTACK_VERSION=${OPENSTACK_VERSION:-latest}
OSISM_VERSION=${OSISM_VERSION:-latest}
VERSION=${VERSION:-latest}

KOLLA_TYPE=ubuntu-source
LSTFILE=images.txt
SOURCE_DOCKER_TAG=build-$BUILD_ID

# NOTE: For builds for a specific release, the OpenStack version is taken from the release repository.
if [[ $VERSION != "latest" ]]; then
    filename=$(curl -L https://raw.githubusercontent.com/osism/release/master/$VERSION/openstack.yml)
    OPENSTACK_VERSION=$(curl -L https://raw.githubusercontent.com/osism/release/master/$VERSION/$filename | grep "openstack_version:" | awk -F': ' '{ print $2 }')
fi

. defaults/$OPENSTACK_VERSION.sh

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

    if [[ "$OPENSTACK_VERSION" == "latest" ]]; then
        tag=latest
        docker tag $image:$SOURCE_DOCKER_TAG $new_imagename:$tag
        echo "$new_imagename:$tag" >> $LSTFILE
    else

        # NOTE: Push no longer the X-Y tags
        #
        # tag=$OPENSTACK_VERSION-$OSISM_VERSION
        # docker tag $image:$SOURCE_DOCKER_TAG $new_imagename:$tag
        # echo "$new_imagename:$tag" >> $LSTFILE

        tag=$OPENSTACK_VERSION
        docker tag $image:$SOURCE_DOCKER_TAG $new_imagename:$tag
        echo "$new_imagename:$tag" >> $LSTFILE
    fi
done

docker images

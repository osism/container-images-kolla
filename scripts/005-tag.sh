#!/usr/bin/env bash

set -x

# Available environment variables
#
# BUILD_ID
# DOCKER_NAMESPACE
# DOCKER_REGISTRY
# IS_RELEASE
# OPENSTACK_VERSION
# VERSION

# Set default values

BUILD_ID=${BUILD_ID:-$(date +%Y%m%d)}
DOCKER_NAMESPACE=${DOCKER_NAMESPACE:-osism}
DOCKER_REGISTRY=${DOCKER_REGISTRY:-quay.io}
IS_RELEASE=${IS_RELEASE:-false}
OPENSTACK_VERSION=${OPENSTACK_VERSION:-latest}
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

export IS_RELEASE
export OPENSTACK_VERSION
export VERSION

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
        if [[ $VERSION == "latest" ]]; then
             tag=$OPENSTACK_VERSION
         else
             tag=$VERSION
         fi
        docker tag $image:$SOURCE_DOCKER_TAG $new_imagename:$tag
        echo "$new_imagename:$tag" >> $LSTFILE
    fi
done

python3 src/tag-images-with-the-version.py
docker images

# NOTE: The generation of SBOMs requires a lot of time and memory.
#       Therefore, SBOMs are currently only created for release images.

# if [[ $IS_RELEASE == "true" ]]; then
#     curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sudo sh -s -- -b /usr/local/bin
#     python3 src/generate-sbom-with-syft.py
# fi

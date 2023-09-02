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
IS_RELEASE=${IS_RELEASE:-False}
OPENSTACK_VERSION=${OPENSTACK_VERSION:-latest}
VERSION=${VERSION:-latest}

LSTFILE=images.txt
SOURCE_DOCKER_TAG=build-$BUILD_ID

# NOTE: For builds for a specific release, the OpenStack version is taken from the release repository.
if [[ $VERSION != "latest" ]]; then
    OPENSTACK_VERSION=$(grep "openstack_version:" release/$VERSION/openstack.yml | awk -F': ' '{ print $2 }')
fi

. defaults/all.sh
. defaults/$OPENSTACK_VERSION.sh

export IS_RELEASE
export OPENSTACK_VERSION
export VERSION

rm -f $LSTFILE
touch $LSTFILE

docker images

# change build_id tags to openstack version tags
docker images -f label="de.osism.release.openstack=${OPENSTACK_VERSION}" | tail -n +2 | awk '{ print $1 }' | while read image; do
    imagename=$(echo $image | awk -F/ '{ print $NF }')
    new_imagename=${imagename#${KOLLA_TYPE}}

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

    # remove the build_id tag
    docker rmi $image:$SOURCE_DOCKER_TAG
done
docker images

python3 src/tag-images-with-the-version.py
docker images

if [[ $IS_RELEASE == "True" ]]; then
    mkdir -p $VERSION
    cp images.yml $VERSION/openstack.yml
    python3 add-image-checksum.py
    cat $VERSION/openstack.yml
fi

# NOTE: The generation of SBOMs requires a lot of time and memory.
#       Therefore, SBOMs are currently only created for release images.

# if [[ $IS_RELEASE == "True" ]]; then
#     curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sudo sh -s -- -b /usr/local/bin
#     python3 src/generate-sbom-with-syft.py
# fi

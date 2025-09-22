#!/usr/bin/env bash

set -x

# Available environment variables
#
# BUILD_ID
# DOCKER_NAMESPACE
# OPENSTACK_VERSION
# VERSION

# Set default values

BUILD_ID=${BUILD_ID:-$(date +%Y%m%d)}
DOCKER_NAMESPACE=${DOCKER_NAMESPACE:-osism}
OPENSTACK_VERSION=${OPENSTACK_VERSION:-latest}
VERSION=${VERSION:-latest}

PROJECT_REPOSITORY=https://github.com/openstack/kolla
PROJECT_REPOSITORY_PATH=kolla
RELEASE_REPOSITORY=https://github.com/osism/release
RELEASE_REPOSITORY_PATH=release
SOURCE_DOCKER_TAG=build-$BUILD_ID

. defaults/all.sh
. defaults/$OPENSTACK_VERSION.sh

export VERSION
export OPENSTACK_VERSION

# Clone release repository

if [[ ! -e $RELEASE_REPOSITORY_PATH ]]; then
    git clone $RELEASE_REPOSITORY $RELEASE_REPOSITORY_PATH
fi

# NOTE: For builds for a specific release, the OpenStack version is taken from the release repository.
if [[ $VERSION != "latest" ]]; then
    ( cd $RELEASE_REPOSITORY_PATH || exit; git fetch --all --force; git checkout "kolla-$VERSION" )
    OPENSTACK_VERSION=$(grep "openstack_version:" release/latest/openstack.yml | awk -F': ' '{ print $2 }' | tr -d '"')
fi

# Clone repository

if [[ ! -e $PROJECT_REPOSITORY_PATH ]]; then
    git clone $PROJECT_REPOSITORY $PROJECT_REPOSITORY_PATH
fi

# Use required kolla release for dockerfiles

pushd $PROJECT_REPOSITORY_PATH > /dev/null
if [[ "$OPENSTACK_VERSION" != "latest" ]]; then
    git checkout origin/stable/$OPENSTACK_VERSION
fi
export HASH_KOLLA=$(git rev-parse --short HEAD)
popd > /dev/null

# Do not build rabbitmq-4-1 image

rm -rf $PROJECT_REPOSITORY_PATH/docker/rabbitmq/rabbitmq-4-1

# Apply patches

for patch in $(find patches/kolla-build/$OPENSTACK_VERSION -type f -name '*.patch'); do
    pushd $PROJECT_REPOSITORY_PATH > /dev/null
    echo "APPLY PATCH $patch"
    patch --forward --batch -p1 --dry-run < ../$patch || exit 1
    patch --forward --batch -p1 < ../$patch
    popd > /dev/null
done

# Prepare repos.yaml

if [[ -f templates/$OPENSTACK_VERSION/repos.yaml ]]; then
    python3 src/merge-repos-yaml.py templates/$OPENSTACK_VERSION/repos.yaml $PROJECT_REPOSITORY_PATH/kolla/template/repos.yaml
fi

# Prepare apt_preferences.ubuntu

python3 src/generate-apt-preferences-files.py > overlays/$OPENSTACK_VERSION/base/apt_preferences.ubuntu

echo DEBUG apt_preferences.ubuntu
cat overlays/$OPENSTACK_VERSION/base/apt_preferences.ubuntu

# Copy overlay files

for image in $(find overlays/$OPENSTACK_VERSION -maxdepth 1 -mindepth 1 -type d); do
    image_name=$(basename $image)
    cp -r overlays/$OPENSTACK_VERSION/$image_name/* $PROJECT_REPOSITORY_PATH/docker/$image_name
done

# Apply patches

find patches/$OPENSTACK_VERSION -mindepth 1 -type d
for project in $(find patches/$OPENSTACK_VERSION -mindepth 1 -type d | grep kolla | grep -v kolla-build); do
    project=$(basename $project)
    for patch in $(find patches/$OPENSTACK_VERSION/$project -type f -name '*.patch' | sort); do
        pushd $project > /dev/null
        echo "APPLY PATCH $patch"
        patch --forward --batch -p1 --dry-run < ../$patch || exit 1
        patch --forward --batch -p1 < ../$patch
        popd > /dev/null
    done
done

# Install kolla

pip3 install -r $PROJECT_REPOSITORY_PATH/requirements.txt
pip3 install $PROJECT_REPOSITORY_PATH/

export KOLLA_VERSION=$(kolla-build --version)

# Prepare template-overrides.j2

export HASH_DOCKER_IMAGES_KOLLA=$(git rev-parse --short HEAD)
export HASH_RELEASE=$(cd $RELEASE_REPOSITORY_PATH; git rev-parse --short HEAD)
python3 src/generate-template-overrides-file.py > templates/$OPENSTACK_VERSION/template-overrides.j2

echo DEBUG template-overrides.j2
cat templates/$OPENSTACK_VERSION/template-overrides.j2

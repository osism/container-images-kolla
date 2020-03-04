#!/usr/bin/env bash

# Available environment variables
#
# BUILD_ID
# DOCKER_NAMESPACE
# OPENSTACK_VERSION
# OSISM_VERSION

# Set default values

BUILD_ID=${BUILD_ID:-$(date +%Y%m%d)}
DOCKER_NAMESPACE=${DOCKER_NAMESPACE:-osism}
OPENSTACK_VERSION=${OPENSTACK_VERSION:-master}
OSISM_VERSION=${OSISM_VERSION:-latest}

PROJECT_REPOSITORY=https://github.com/openstack/kolla
PROJECT_REPOSITORY_PATH=kolla
KOLLA_TYPE=ubuntu-source
SOURCE_DOCKER_TAG=build-$BUILD_ID

if [[ $(git name-rev --name-only HEAD) == "master" ]]; then
    OSISM_VERSION=latest
else
    tag=$(git describe --exact-match HEAD)
    OSISM_VERSION=${tag:1}
fi

git submodule update --remote

if [[ ! -e release/$OSISM_VERSION/base.yml ]]; then
    echo "release $OSISM_VERSION does not exist"
    exit 1
fi

# Clone repository

git clone $PROJECT_REPOSITORY $PROJECT_REPOSITORY_PATH

# Use required kolla release for dockerfiles

pushd $PROJECT_REPOSITORY_PATH
if [[ "$OPENSTACK_VERSION" != "master" ]]; then
    git checkout origin/stable/$OPENSTACK_VERSION
fi
export HASH_KOLLA=$(git rev-parse --short HEAD)
popd

# Apply patches

for patch in $(find patches/kolla-build/$OPENSTACK_VERSION -type f -name '*.patch'); do
    pushd $PROJECT_REPOSITORY_PATH
    echo "APPLY PATCH $patch"
    patch --forward --batch -p1 --dry-run < ../$patch || exit 1
    patch --forward --batch -p1 < ../$patch
    popd
done

# Prepare repos.yaml

# NOTE: was introduced with Ussuri, therefore currently only for master

if [[ "$OPENSTACK_VERSION" == "master" ]]; then
    cp templates/$OPENSTACK_VERSION/repos.yaml $PROJECT_REPOSITORY_PATH/kolla/template/repos.yaml
fi

# Prepare template-overrides.j2

export HASH_DOCKER_KOLLA_DOCKER=$(git rev-parse --short HEAD)
export HASH_RELEASE=$(cd release; git rev-parse --short HEAD)
python3 src/generate-template-overrides-file.py > templates/$OPENSTACK_VERSION/template-overrides.j2
cp templates/$OPENSTACK_VERSION/template-overrides.j2 template-overrides.j2

echo DEBUG template-overrides.j2
cat template-overrides.j2

# Prepare apt_preferences.ubuntu

python3 src/generate-apt-preferences-files.py > overlays/$OPENSTACK_VERSION/base/apt_preferences.ubuntu
cp overlays/$OPENSTACK_VERSION/base/apt_preferences.ubuntu apt_preferences.ubuntu

echo DEBUG apt_preferences.ubuntu
cat apt_preferences.ubuntu

# Copy overlay files

for image in $(find overlays/$OPENSTACK_VERSION -maxdepth 1 -mindepth 1 -type d); do
    image_name=$(basename $image)
    cp -r overlays/$OPENSTACK_VERSION/$image_name/* $PROJECT_REPOSITORY_PATH/docker/$image_name
done

# Apply patches

find patches/$OPENSTACK_VERSION -mindepth 1 -type d
for project in $(find patches/$OPENSTACK_VERSION -mindepth 1 -type d | grep kolla | grep -v kolla-build); do
    project=$(basename $project)
    for patch in $(find patches/$OPENSTACK_VERSION/$project -type f -name '*.patch'); do
        pushd $project
        echo "APPLY PATCH $patch"
        patch --forward --batch -p1 --dry-run < ../$patch || exit 1
        patch --forward --batch -p1 < ../$patch
        popd
    done
done

# Install kolla

pip3 install -r $PROJECT_REPOSITORY_PATH/requirements.txt
pip3 install $PROJECT_REPOSITORY_PATH/

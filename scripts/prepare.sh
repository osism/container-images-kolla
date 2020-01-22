#!/usr/bin/env bash
set -x

# Available environment variables
#
# BASEPULL
# BUILD_ID
# DOCKER_NAMESPACE
# OPENSTACK_VERSION
# OSISM_VERSION

# Set default values

BASEPULL=${BASEPULL:-false}
BUILD_ID=${BUILD_ID:-$(date +%Y%m%d)}
DOCKER_NAMESPACE=${DOCKER_NAMESPACE:-osism}
OPENSTACK_VERSION=${OPENSTACK_VERSION:-rocky}
OSISM_VERSION=${OSISM_VERSION:-latest}

PROJECT_REPOSITORY=https://github.com/openstack/kolla
PROJECT_REPOSITORY_PATH=kolla
KOLLA_TYPE=ubuntu-source
SOURCE_DOCKER_TAG=build-$BUILD_ID
VENV_PATH=$(pwd)/venv

if [[ $(git rev-parse --abbrev-ref HEAD) == "master" ]]; then
    OSISM_VERSION=latest
else
    tag=$(git describe --exact-match HEAD)
    OSISM_VERSION=${tag:1}
fi

if [[ ! -e release ]]; then
    git clone https://github.com/osism/release
fi

if [[ ! -e release/$OSISM_VERSION/base.yml ]]; then
    echo "release $OSISM_VERSION does not exist"
    exit 1
fi

# Prepare installation

virtualenv -p python3 --no-site-packages $VENV_PATH
source $VENV_PATH/bin/activate

# Install requirements

pip3 install -r requirements.txt
pip3 install -r test-requirements.txt

# Lint python files

flake8 src/*.py

# Clone repository

git clone $PROJECT_REPOSITORY $PROJECT_REPOSITORY_PATH

# Use required kolla release for dockerfiles

pushd $PROJECT_REPOSITORY_PATH
git checkout origin/stable/$OPENSTACK_VERSION
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

# Install kolla
pip3 install -r $PROJECT_REPOSITORY_PATH/requirements.txt
pip3 install $PROJECT_REPOSITORY_PATH/

# prepare template-overrides.j2

export HASH_DOCKER_KOLLA_DOCKER=$(git rev-parse --short HEAD)
export HASH_RELEASE=$(cd release; git rev-parse --short HEAD)
python3 src/generate-template-overrides-file.py > templates/$OPENSTACK_VERSION/template-overrides.j2
cp templates/$OPENSTACK_VERSION/template-overrides.j2 template-overrides.j2

# prepare apt_preferences.ubuntu

python3 src/generate-apt-preferences-files.py > overlays/$OPENSTACK_VERSION/base/apt_preferences.ubuntu
cp overlays/$OPENSTACK_VERSION/base/apt_preferences.ubuntu apt_preferences.ubuntu

# Copy overlay files
for image in $(find overlays/$OPENSTACK_VERSION -maxdepth 1 -mindepth 1 -type d); do
    image_name=$(basename $image)
    cp -r overlays/$OPENSTACK_VERSION/$image_name/* $PROJECT_REPOSITORY_PATH/docker/$image_name
done

# Apply patches
for project in $(find patches/$OPENSTACK_VERSION -maxdepth 1 -mindepth 1 -type d | grep kolla | grep -v kolla-build); do project=$(basename $project)
    for patch in $(find patches/$OPENSTACK_VERSION/$project -type f -name '*.patch'); do
        pushd $project
        echo "APPLY PATCH $patch"
        patch --forward --batch -p1 --dry-run < ../$patch || exit 1
        patch --forward --batch -p1 < ../$patch
        popd
    done
done

# Copy dockerfiles
rm -rf $VENV_PATH/share/kolla/docker
cp -r $PROJECT_REPOSITORY_PATH/docker $VENV_PATH/share/kolla/

# Pull base images
if [[ $BASEPULL == "true" ]]; then
    docker pull $DOCKER_NAMESPACE/base:$OPENSTACK_VERSION-$OSISM_VERSION
    docker pull $DOCKER_NAMESPACE/openstack-base:$OPENSTACK_VERSION-$OSISM_VERSION

    docker tag $DOCKER_NAMESPACE/base:$OPENSTACK_VERSION-$OSISM_VERSION $DOCKER_NAMESPACE/$KOLLA_TYPE-base:$SOURCE_DOCKER_TAG
    docker tag $DOCKER_NAMESPACE/openstack-base:$OPENSTACK_VERSION-$OSISM_VERSION $DOCKER_NAMESPACE/$KOLLA_TYPE-openstack-base:$SOURCE_DOCKER_TAG
fi

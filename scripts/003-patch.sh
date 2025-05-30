#!/usr/bin/env bash

set -x

# Available environment variables
#
# OPENSTACK_VERSION
# VERSION

# Set default values

OPENSTACK_VERSION=${OPENSTACK_VERSION:-latest}
VERSION=${VERSION:-latest}

KOLLA_CONF_FILE=kolla-build.conf

# NOTE: For builds for a specific release, the OpenStack version is taken from the release repository.
if [[ $VERSION != "latest" ]]; then
    OPENSTACK_VERSION=$(grep "openstack_version:" release/latest/openstack.yml | awk -F': ' '{ print $2 }' | tr -d '"')
fi

. defaults/all.sh
. defaults/$OPENSTACK_VERSION.sh

export VERSION
export OPENSTACK_VERSION

mkdir -p tarballs

for tarball in $(grep '# tarball' $KOLLA_CONF_FILE | awk '{ print $4 }'); do
    pushd tarballs > /dev/null

    filename=$(basename $tarball)
    if [[ -e $filename ]]; then
        popd > /dev/null
        continue
    fi

    echo Download $tarball
    wget --no-verbose $tarball

    if [[ $tarball == *"gnocchi"* && ! $filename == *"gnocchi"* ]]; then
        mv $filename gnocchi-$filename
        filename="gnocchi-$filename"
    fi

    echo Process $filename
    directory=$(tar -tzf $filename | head -1 | cut -f1 -d"/")

    echo Check patches for $filename
    if [[ -e ../patches/$OPENSTACK_VERSION/${directory%-*} ]]; then
        tar xzf $filename
        rm $filename
        pushd $directory > /dev/null
        for patch in $(find ../../patches/$OPENSTACK_VERSION/${directory%-*} -type f -name '*.patch' | sort); do
            echo "APPLY PATCH $patch"
            patch --forward --batch -p1 --dry-run < $patch || exit 1
            patch --forward --batch -p1 < $patch
        done
        popd > /dev/null
        tar czf $filename $directory
        rm -r $directory
    fi

    echo Check overlays for $filename
    if [[ -e ../overlays/$OPENSTACK_VERSION/${directory%-*}/source ]]; then
        tar xzf $filename
        rm $filename
        rsync -avz ../overlays/$OPENSTACK_VERSION/${directory%-*}/source/ $directory
        tar czf $filename $directory
        rm -r $directory
    fi
    popd > /dev/null
done

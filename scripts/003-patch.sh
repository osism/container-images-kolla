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

# NOTE: The sdist tarballs ship a pre-generated <project>.egg-info/SOURCES.txt.
# When pip builds a wheel from the patched tree inside the image build, pbr
# reuses this manifest as-is (the tree is not a git repository) and setuptools
# copies package data files (e.g. alembic migrations) into the wheel only if
# they are listed there. Files added by patches or overlays therefore have to
# be appended here, otherwise they are missing in the venv of the images.
append_new_files_to_sources_txt () {
    local directory=$1
    local before=$2
    local after=$3

    local sources_txt
    sources_txt=$(find $directory -maxdepth 2 -type f -path '*.egg-info/SOURCES.txt' | head -1)
    if [[ -z $sources_txt ]]; then
        return
    fi

    local new_files
    new_files=$(comm -13 $before $after)
    if [[ -z $new_files ]]; then
        return
    fi

    # NOTE: SOURCES.txt is written without a trailing newline
    if [[ -n $(tail -c1 $sources_txt) ]]; then
        echo >> $sources_txt
    fi

    local file
    for file in $new_files; do
        # NOTE: patch leaves *.orig backup files behind when hunks apply
        # with fuzz, those must not be installed into the images
        case $file in
            *.orig|*.rej) continue ;;
        esac
        echo "APPEND ${file#$directory/} TO $sources_txt"
        echo "${file#$directory/}" >> $sources_txt
    done
}

mkdir -p tarballs

ping -c2 tarballs.opendev.org

for tarball in $(grep '# tarball' $KOLLA_CONF_FILE | awk '{ print $4 }'); do
    pushd tarballs > /dev/null

    filename=$(basename $tarball)
    if [[ -e $filename ]]; then
        popd > /dev/null
        continue
    fi

    echo Download $tarball
    wget --no-verbose --tries=3 $tarball || exit 2

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
        find $directory -type f | sort > files-before
        pushd $directory > /dev/null
        for patch in $(find ../../patches/$OPENSTACK_VERSION/${directory%-*} -type f -name '*.patch' | sort); do
            echo "APPLY PATCH $patch"
            patch --forward --batch -p1 --dry-run < $patch || exit 1
            patch --forward --batch -p1 < $patch
        done
        popd > /dev/null
        find $directory -type f | sort > files-after
        append_new_files_to_sources_txt $directory files-before files-after
        rm files-before files-after
        tar czf $filename $directory
        rm -r $directory
    fi

    echo Check overlays for $filename
    if [[ -e ../overlays/$OPENSTACK_VERSION/${directory%-*}/source ]]; then
        tar xzf $filename
        rm $filename
        find $directory -type f | sort > files-before
        rsync -avz ../overlays/$OPENSTACK_VERSION/${directory%-*}/source/ $directory
        find $directory -type f | sort > files-after
        append_new_files_to_sources_txt $directory files-before files-after
        rm files-before files-after
        tar czf $filename $directory
        rm -r $directory
    fi
    popd > /dev/null
done

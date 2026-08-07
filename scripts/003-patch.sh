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
. scripts/patch-lib.sh

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

# NOTE: The generated config repeats a tarball's `# tarball` line for
# projects that produce more than one kolla image section (e.g.
# neutron-dynamic-routing, which also has a
# neutron-server-plugin-neutron-dynamic-routing section). Each tarball
# must be processed exactly once, so dedupe while preserving the
# generated config's order; `sort -u` would reorder processing instead.
for tarball in $(awk '/# tarball/ && !seen[$4]++ { print $4 }' $KOLLA_CONF_FILE); do
    pushd tarballs > /dev/null

    filename=$(basename $tarball)
    if [[ -e $filename ]]; then
        # A cached tarball has already been repacked with its patches applied,
        # so re-applying them would trip the reversed-patch guard. It may also
        # predate a change to the patch set. Re-download anything the
        # verification at the end of this script covers; keep the rest cached.
        directory=$(tar -tzf $filename | head -1 | cut -f1 -d"/")
        if resolve_project_dir "patches/$OPENSTACK_VERSION" "$directory" > /dev/null \
            || resolve_project_dir "overlays/$OPENSTACK_VERSION" "$directory" "/source" > /dev/null; then
            echo "Re-download $filename: cached tarball belongs to a patched project"
            rm $filename
        else
            popd > /dev/null
            continue
        fi
    fi

    echo Download $tarball
    wget --no-verbose --tries=3 $tarball || exit 2

    if [[ $tarball == *"gnocchi"* && ! $filename == *"gnocchi"* ]]; then
        mv $filename gnocchi-$filename
        filename="gnocchi-$filename"
    fi

    echo Process $filename
    directory=$(tar -tzf $filename | head -1 | cut -f1 -d"/")
    patch_dir=$(resolve_project_dir "patches/$OPENSTACK_VERSION" "$directory") || patch_dir=""
    overlay_dir=$(resolve_project_dir "overlays/$OPENSTACK_VERSION" "$directory" "/source") || overlay_dir=""

    echo Check patches for $filename
    if [[ -n $patch_dir ]]; then
        tar xzf $filename
        rm $filename
        find $directory -type f | sort > files-before
        pushd $directory > /dev/null
        for patch in $(find "$PATCH_ROOT/$patch_dir" -type f -name '*.patch' | sort); do
            apply_patch "${patch#$PATCH_ROOT/}"
        done
        popd > /dev/null
        find $directory -type f | sort > files-after
        append_new_files_to_sources_txt $directory files-before files-after
        rm files-before files-after
        tar czf $filename $directory
        rm -r $directory
    fi

    echo Check overlays for $filename
    if [[ -n $overlay_dir ]]; then
        tar xzf $filename
        rm $filename
        find $directory -type f | sort > files-before
        rsync -avz "$PATCH_ROOT/$overlay_dir/" $directory
        find $directory -type f | sort > files-after
        append_new_files_to_sources_txt $directory files-before files-after
        rm files-before files-after
        tar czf $filename $directory
        rm -r $directory
    fi
    popd > /dev/null
done

verify_all_patches_applied "$PATCH_MANIFEST" \
    "patches/$OPENSTACK_VERSION" \
    "patches/kolla-build/$OPENSTACK_VERSION" || exit 3

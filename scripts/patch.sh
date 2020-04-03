#!/usr/bin/env bash

# Available environment variables
#
# OPENSTACK_VERSION

# Set default values

OPENSTACK_VERSION=${OPENSTACK_VERSION:-master}

KOLLA_CONF_FILE=kolla-build.conf
LSTFILE=versions.txt

mkdir -p tarballs

for tarball in $(grep '# tarball' $KOLLA_CONF_FILE | awk '{ print $4 }'); do
    pushd tarballs > /dev/null

    filename=$(basename $tarball)
    if [[ -e $filename ]]; then
        popd > /dev/null
        continue
    fi

    echo Download $tarball
    wget --quiet $tarball

    if [[ $tarball == *"gnocchi"* && ! $filename == *"gnocchi"* ]]; then
        mv $filename gnocchi-$filename
        filename="gnocchi-$filename"
    fi

    echo Process $filename
    tar xzf $filename
    directory=$(tar -tzf $filename | head -1 | cut -f1 -d"/")
    echo $directory >> $LSTFILE
    rm $filename
    if [[ -e ../patches/$OPENSTACK_VERSION/${directory%-*} ]]; then
        pushd $directory > /dev/null
        for patch in $(find ../../patches/$OPENSTACK_VERSION/${directory%-*} -type f -name '*.patch'); do
            echo "APPLY PATCH $patch"
            patch --forward --batch -p1 --dry-run < $patch || exit 1
            patch --forward --batch -p1 < $patch
        done
        popd > /dev/null
    fi
    tar czf $filename $directory
    rm -r $directory
    popd > /dev/null
done

cat tarballs/$LSTFILE | sort | uniq > $LSTFILE

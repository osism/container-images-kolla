#!/usr/bin/env bash

export BUILD_TYPE=${BUILD_TYPE:-base}
source scripts/defaults.sh

echo BUILD_TYPE = $BUILD_TYPE
echo OPENSTACK_VERSION = $OPENSTACK_VERSION
echo UBUNTU_VERSION = $UBUNTU_VERSION

echo run prepare.sh
bash scripts/prepare.sh || exit 1

echo run generate.sh
bash scripts/generate.sh || exit 1

echo run patch.sh
bash scripts/patch.sh || exit 1

echo run build.sh
bash scripts/build.sh || exit 1

echo run tag.sh
bash scripts/tag.sh || exit 1

echo run push.sh
bash scripts/push.sh || exit 1

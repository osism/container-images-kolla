#!/usr/bin/env bash
set -x
source venv/bin/activate

# Available environment variables
#
# BUILD_ID
# KOLLA_IMAGES
# OPENSTACK_VERSION
# SQUASH

# Set default values

BUILD_ID=${BUILD_ID:-$(date +%Y%m%d)}
OPENSTACK_VERSION=${OPENSTACK_VERSION:-rocky}
SQUASH=${SQUASH:-true}

KOLLA_CONF=kolla-build.conf

# Set default images if KOLLA_IMAGES not set

if [[ $(git rev-parse --abbrev-ref HEAD) == "master" ]]; then
    SQUASH=false
fi

if [[ -z "$KOLLA_IMAGES" || $KOLLA_IMAGES == "all" ]]; then
    KOLLA_IMAGES+=" $(python3 src/get-projects-from-versions-file.py)"
fi

if [[ $SQUASH == "true" ]]; then
    extraopts+=" --squash"
fi

# Build images

kolla-build \
  --template-override templates/$OPENSTACK_VERSION/template-overrides.j2 \
  --config-file $KOLLA_CONF \
  --nopush \
  --pull \
  $extraopts \
  $KOLLA_IMAGES 2>&1 | tee kolla-build-$BUILD_ID.log

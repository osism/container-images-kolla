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

. scripts/patch-lib.sh

reset_patch_manifest

export VERSION
export OPENSTACK_VERSION

# ===========================================================================
# THROWAWAY DIAGNOSTIC BRANCH -- never merge. Validates the transport probe
# that is destined for zuul-config's diagnose-network role.
#
# zuul-config is a TRUSTED config-project, so its playbooks always run from
# the branch tip and its changes are never executed speculatively from a PR.
# A DNM PR there would run merged main and the probe would simply not fire.
# container-images-kolla is untrusted, so speculative execution works here --
# hence validating the snippet in this repo first and porting it afterwards.
#
# The probe uses GIT, not curl. That is not a style preference: curl POSTs to
# /git-upload-pack returned 200 on 24 of 24 probes while git was failing ~84%
# of attempts on the same node in the same seconds, so a curl-based probe is a
# verified NON-reproducer and would report healthy through an active fault.
# `git ls-remote` with protocol v2 does reproduce (measured 2/5).
#
# Both axes are set explicitly in every cell so the measurement is unaffected
# by any node-level `http.version` pin (verified: `-c` overrides the pin).
#
# Run AFTER the build's own clones on purpose. These probes issue ~30 extra
# requests; if the fault has any per-client rate component, running them first
# could induce the very refusals we are trying to observe and corrupt the
# clone-loop counts this is meant to correlate against.
# ===========================================================================

# Every git call is wrapped in `timeout`, and the loop honours an overall
# deadline. Both are required, not defensive habit: in the buildset that
# validated this probe, one node stalled diagnose-network's "Snapshot
# dual-stack" task to ~308s and blew its `async: 300` budget. An unguarded
# probe on such a node would hang on each of its calls and could consume that
# whole budget by itself -- the diagnostic becoming the cause of the timeout it
# exists to observe. Per-call 10s x 10 trials would still be 100s worst case,
# hence the aggregate deadline too.
#
# Timeouts are counted SEPARATELY from refusals. Collapsing them would make a
# stalled node report `ok=0/10` and read as a severe 401 event, which is a
# different fault with a different owner.
diag_probe_default_transport () {
    local url=$1
    local trials=${2:-10}
    local budget=${3:-30}
    local ok=0 refused=0 timedout=0 attempted=0
    local deadline=$(( $(date +%s) + budget ))
    local i rc

    for ((i = 1; i <= trials; i++)); do
        if (( $(date +%s) >= deadline )); then
            break
        fi
        attempted=$((attempted + 1))
        GIT_TERMINAL_PROMPT=0 timeout 10 git -c http.version=HTTP/2 \
            -c protocol.version=2 ls-remote "$url" HEAD >/dev/null 2>&1
        rc=$?
        case $rc in
            0)   ok=$((ok + 1)) ;;
            124) timedout=$((timedout + 1)) ;;
            *)   refused=$((refused + 1)) ;;
        esac
    done
    echo "DIAG-PROBE: default-transport ls-remote url=$url" \
        "ok=$ok attempted=$attempted/$trials refused=$refused timedout=$timedout"
}

# Same guards as the probe. This one stays in the throwaway branch -- at ~18s
# it would double diagnose-network's healthy runtime for a one-off experiment.
diag_probe_matrix () {
    local url=$1
    local budget=${2:-120}
    local deadline=$(( $(date +%s) + budget ))
    local label ok timedout attempted i d rc

    for label in h2+v2 http1.1+v2 h2+v0 http1.1+v0; do
        ok=0; timedout=0; attempted=0
        for ((i = 1; i <= 5; i++)); do
            if (( $(date +%s) >= deadline )); then
                break
            fi
            d=$(mktemp -d) || continue
            attempted=$((attempted + 1))
            case $label in
                h2+v2)      GIT_TERMINAL_PROMPT=0 timeout 30 git -c http.version=HTTP/2 \
                                -c protocol.version=2 clone --depth=1 "$url" "$d/c" ;;
                http1.1+v2) GIT_TERMINAL_PROMPT=0 timeout 30 git -c http.version=HTTP/1.1 \
                                -c protocol.version=2 clone --depth=1 "$url" "$d/c" ;;
                h2+v0)      GIT_TERMINAL_PROMPT=0 timeout 30 git -c http.version=HTTP/2 \
                                -c protocol.version=0 clone --depth=1 "$url" "$d/c" ;;
                http1.1+v0) GIT_TERMINAL_PROMPT=0 timeout 30 git -c http.version=HTTP/1.1 \
                                -c protocol.version=0 clone --depth=1 "$url" "$d/c" ;;
            esac >/dev/null 2>&1
            rc=$?
            case $rc in
                0)   ok=$((ok + 1)) ;;
                124) timedout=$((timedout + 1)) ;;
            esac
            rm -rf "$d"
        done
        echo "DIAG-MATRIX: clone --depth=1 [$label]" \
            "ok=$ok attempted=$attempted/5 timedout=$timedout"
    done
}

# clone_repository <url> <path>
#
# Clones <url> and aborts the build when it cannot. Retrying first is
# deliberate: an anonymous clone from a public forge is a single HTTPS call
# that the far side rejects or drops often enough to take a whole nightly
# build with it. A clone that still fails after the retries is fatal, because
# every later step assumes the checkout is there -- the `git checkout` below
# picks the wrong tree, the patch loop runs `patch` in this repository instead
# of the clone, and the build dies reporting "No file to patch", which reads
# like a patch that was merged upstream rather than a failed clone.
clone_repository () {
    local url=$1
    local path=$2
    local attempts=3
    local attempt

    for ((attempt = 1; attempt <= attempts; attempt++)); do
        if git clone "$url" "$path"; then
            return 0
        fi
        echo "WARNING: cloning $url failed (attempt $attempt of $attempts)" >&2
        rm -rf "$path"
        sleep $((attempt * 10))
    done

    # TEMPORARY WORKAROUND for a GitHub-side fault -- see "Retiring this"
    # below. Retry once over HTTP/1.1.
    #
    # Since 2026-09-02, anonymous clones of public github.com repositories are
    # intermittently refused: the `GET .../info/refs` succeeds with 200, then
    # the `POST .../git-upload-pack` that follows returns 401 with
    # `www-authenticate: Basic realm="GitHub"`, so git tries to prompt for a
    # password, finds no terminal, and aborts. The transport decides it.
    # Measured on nodes while they were being refused: git's default
    # (HTTP/2 with git protocol v2) took 15 refusals in one buildset, while
    # HTTP/1.1 succeeded 9 times out of 9, four of those on the first attempt
    # immediately after three consecutive default refusals of the same URL.
    #
    # This is a fallback and NOT a global `http.version` pin. A pin would work
    # equally well, but it would also make the fault invisible the moment it
    # recurs, and it is not understood well enough to stop watching. Reaching
    # this code is the signal, so both markers below are stable, greppable
    # strings with machine-readable `url=` and `after=` fields.
    #
    # Retiring this:
    #
    #   Judge it on REFUSALS, not on these markers. A marker only appears when
    #   the default transport fails all $attempts times; if the fault merely
    #   becomes rarer, a plain retry recovers and no marker is emitted at all
    #   (observed: two jobs in the validating buildset took a refusal each and
    #   recovered without reaching the fallback). Zero markers therefore does
    #   NOT mean the fault is gone.
    #
    #   Retire when `could not read Username for 'https://github.com'` stops
    #   appearing across CI for a sustained window -- not merely when
    #   FALLBACK-HTTP11 stops appearing. Then revert this commit; the retry
    #   loop and fail-fast behaviour above are independent of it and stay.
    #
    #   Note both markers are echoed under `set -x`, so each appears twice in
    #   the job log. Halve any count.
    echo "WARNING: FALLBACK-HTTP11 url=$url after=$attempts refused attempts" >&2
    if git -c http.version=HTTP/1.1 clone "$url" "$path"; then
        echo "WARNING: FALLBACK-HTTP11-SUCCEEDED url=$url after=$attempts refused attempts" >&2
        return 0
    fi
    rm -rf "$path"

    echo "ERROR: cloning $url into $path failed (HTTP/1.1 fallback also failed)" >&2
    exit 1
}

# Clone release repository

if [[ ! -e $RELEASE_REPOSITORY_PATH ]]; then
    clone_repository "$RELEASE_REPOSITORY" "$RELEASE_REPOSITORY_PATH"
fi

# NOTE: For builds for a specific release, the OpenStack version is taken from the release repository.
if [[ $VERSION != "latest" ]]; then
    ( cd $RELEASE_REPOSITORY_PATH || exit 1; git fetch --all --force || exit 1; git checkout "kolla-$VERSION" || exit 1 ) || exit 1
    OPENSTACK_VERSION=$(grep "openstack_version:" release/latest/openstack.yml | awk -F': ' '{ print $2 }' | tr -d '"')
fi

# Clone repository

if [[ ! -e $PROJECT_REPOSITORY_PATH ]]; then
    clone_repository "$PROJECT_REPOSITORY" "$PROJECT_REPOSITORY_PATH"
fi

# THROWAWAY -- unconditional, so it reports on green builds too. The whole
# point is a time series plus a same-build correlation against any refusals
# the clone loop logged above.
echo "DIAG: ==== transport diagnostics ($(git --version 2>&1)) ===="
diag_probe_default_transport "$RELEASE_REPOSITORY" 10
diag_probe_matrix "$RELEASE_REPOSITORY"
echo "DIAG: ==== end transport diagnostics ===="

# Use required kolla release for dockerfiles

pushd $PROJECT_REPOSITORY_PATH > /dev/null || exit 1
# An unresolvable ref is fatal as well: without this the checkout stays on the
# default branch and the release gets built from the wrong kolla tree.
if [[ "$OPENSTACK_VERSION" != "latest" ]]; then
    if [[ "$OPENSTACK_VERSION" == "2024.1" ]]; then
        git checkout origin/unmaintained/$OPENSTACK_VERSION || exit 1
    elif [[ "$OPENSTACK_VERSION" == "2024.2" ]]; then
        git checkout 2024.2-eol || exit 1
    else
        git checkout origin/stable/$OPENSTACK_VERSION || exit 1
    fi
fi
export HASH_KOLLA=$(git rev-parse --short HEAD)
popd > /dev/null

# Do not build rabbitmq-4-1 image

rm -rf $PROJECT_REPOSITORY_PATH/docker/rabbitmq/rabbitmq-4-1

# Apply patches

for patch in $(find patches/kolla-build/$OPENSTACK_VERSION -type f -name '*.patch' | sort); do
    pushd $PROJECT_REPOSITORY_PATH > /dev/null
    apply_patch "$patch"
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
        apply_patch "$patch"
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

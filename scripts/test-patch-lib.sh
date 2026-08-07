#!/usr/bin/env bash
# Fixture tests for scripts/patch-lib.sh. No network, no tarballs.

set -u

cd "$(dirname "$0")/.." || exit 1
. scripts/patch-lib.sh

# Parent directory for every fixture minted below. Removed on exit so
# fixtures never leak into /tmp, and the trap re-exits with whatever
# status the script was about to exit with (0 pass, 1 fail).
tmp_parent=$(mktemp -d)
cleanup () {
    local status=$?
    rm -rf "$tmp_parent"
    exit $status
}
trap cleanup EXIT

failures=0

ok () { echo "PASS: $1"; }
fail () { echo "FAIL: $1"; failures=$((failures + 1)); }

check_status () {
    local name=$1 expected=$2 actual=$3
    if [[ $actual -eq $expected ]]; then
        ok "$name"
    else
        fail "$name (expected status $expected, got $actual)"
    fi
}

# Builds a throwaway repository root with one patch directory holding one
# patch file, and repoints the library at it.
new_fixture () {
    PATCH_ROOT=$(mktemp -d "$tmp_parent/fixture.XXXXXX")
    PATCH_MANIFEST=$PATCH_ROOT/.patches-applied
    mkdir -p "$PATCH_ROOT/patches/2025.1/keystone"
    echo "dummy" > "$PATCH_ROOT/patches/2025.1/keystone/0001-x.patch"
}

# --- verify_all_patches_applied ---------------------------------------------

new_fixture
echo "patches/2025.1/keystone/0001-x.patch" > "$PATCH_MANIFEST"
verify_all_patches_applied "$PATCH_MANIFEST" "patches/2025.1" > /dev/null
check_status "all patches applied returns 0" 0 $?

new_fixture
: > "$PATCH_MANIFEST"
verify_all_patches_applied "$PATCH_MANIFEST" "patches/2025.1" > /dev/null 2>&1
check_status "unapplied patch returns 3" 3 $?

new_fixture
echo "patches/2025.1/keystone/0001-x.patch" > "$PATCH_MANIFEST"
echo "stray" > "$PATCH_ROOT/patches/2025.1/keystone/fix.diff"
verify_all_patches_applied "$PATCH_MANIFEST" "patches/2025.1" > /dev/null 2>&1
check_status "stray non-patch file returns 3" 3 $?

new_fixture
rm -f "$PATCH_MANIFEST"
missing_manifest_stderr=$(verify_all_patches_applied "$PATCH_MANIFEST" "patches/2025.1" 2>&1 >/dev/null)
check_status "missing manifest returns 3" 3 $?
# A regression that dropped the explicit "manifest is missing" check
# would still return 3 here: sort -u on a nonexistent file yields
# nothing, comm -23 then reports the whole expected set as missing,
# and missing_count -gt 0 triggers the same exit status. Pin the
# assertion to the distinguishing stderr text, not just the status,
# and confirm the fall-through path's file listing is absent.
if [[ $missing_manifest_stderr == *"is missing; run 001-prepare.sh first"* ]]; then
    ok "missing manifest prints explicit error"
else
    fail "missing manifest prints explicit error (got: $missing_manifest_stderr)"
fi
if [[ $missing_manifest_stderr != *"0001-x.patch"* ]]; then
    ok "missing manifest does not fall through to a file listing"
else
    fail "missing manifest does not fall through to a file listing (got: $missing_manifest_stderr)"
fi

new_fixture
: > "$PATCH_MANIFEST"
verify_all_patches_applied "$PATCH_MANIFEST" "patches/9999.9" > /dev/null
check_status "no patch directory for release returns 0" 0 $?

# --- apply_patch ------------------------------------------------------------

# Builds a fixture with a real, appliable patch against a one-line target file.
new_apply_fixture () {
    new_fixture
    mkdir -p "$PATCH_ROOT/target"
    echo "old" > "$PATCH_ROOT/target/file.txt"
    cat > "$PATCH_ROOT/patches/2025.1/keystone/0001-x.patch" <<'EOF'
--- a/file.txt
+++ b/file.txt
@@ -1 +1 @@
-old
+new
EOF
}

new_apply_fixture
: > "$PATCH_MANIFEST"
( cd "$PATCH_ROOT/target" && apply_patch "patches/2025.1/keystone/0001-x.patch" ) > /dev/null 2>&1
check_status "apply_patch succeeds on a clean target" 0 $?
if grep -qx "patches/2025.1/keystone/0001-x.patch" "$PATCH_MANIFEST"; then
    ok "apply_patch records the patch in the manifest"
else
    fail "apply_patch records the patch in the manifest"
fi

if [[ $(id -u) -eq 0 ]]; then
    echo "SKIP: read-only apply test (running as root)"
else
    new_apply_fixture
    : > "$PATCH_MANIFEST"
    chmod a-w "$PATCH_ROOT/target"
    ( cd "$PATCH_ROOT/target" && apply_patch "patches/2025.1/keystone/0001-x.patch" ) > /dev/null 2>&1
    check_status "apply_patch aborts when the real apply fails" 1 $?
    chmod u+w "$PATCH_ROOT/target"
    if [[ -s $PATCH_MANIFEST ]]; then
        fail "failed apply must not be recorded in the manifest"
    else
        ok "failed apply is not recorded in the manifest"
    fi
fi

# --- resolve_project_dir ----------------------------------------------------

new_fixture
mkdir -p "$PATCH_ROOT/overlays/2025.1/cinder/source"
resolved=$(resolve_project_dir "patches/2025.1" "keystone-27.0.3.dev4")
check_status "resolve_project_dir finds an exact patch directory" 0 $?
if [[ $resolved == "patches/2025.1/keystone" ]]; then
    ok "resolve_project_dir returns a root-relative path"
else
    fail "resolve_project_dir returns a root-relative path (got '$resolved')"
fi

resolved=$(resolve_project_dir "overlays/2025.1" "cinder-30.0.0.dev1" "/source")
check_status "resolve_project_dir honours the suffix" 0 $?
if [[ $resolved == "overlays/2025.1/cinder/source" ]]; then
    ok "resolve_project_dir appends the suffix"
else
    fail "resolve_project_dir appends the suffix (got '$resolved')"
fi

resolved=$(resolve_project_dir "patches/2025.1" "nosuchproject-1.0.0")
check_status "resolve_project_dir returns 1 when nothing matches" 1 $?
if [[ -z $resolved ]]; then
    ok "resolve_project_dir emits no output when nothing matches"
else
    fail "resolve_project_dir emits no output when nothing matches (got '$resolved')"
fi

# --- resolve_project_dir: PEP 625 spelling variants -------------------------

# opendev now ships neutron-dynamic-routing as an underscore-normalized sdist,
# so the tarball's top directory no longer matches the hyphenated patch
# directory in this repository. Both spellings must resolve, in both
# directions.

new_fixture
mkdir -p "$PATCH_ROOT/patches/2025.1/neutron-dynamic-routing"
resolved=$(resolve_project_dir "patches/2025.1" "neutron_dynamic_routing-26.0.0.0rc2.dev2")
check_status "underscore tarball finds a hyphenated directory" 0 $?
if [[ $resolved == "patches/2025.1/neutron-dynamic-routing" ]]; then
    ok "underscore tarball resolves to the hyphenated directory"
else
    fail "underscore tarball resolves to the hyphenated directory (got '$resolved')"
fi

new_fixture
mkdir -p "$PATCH_ROOT/patches/2025.1/neutron_dynamic_routing"
resolved=$(resolve_project_dir "patches/2025.1" "neutron-dynamic-routing-24.0.1.dev3")
check_status "hyphenated tarball finds an underscore directory" 0 $?
if [[ $resolved == "patches/2025.1/neutron_dynamic_routing" ]]; then
    ok "hyphenated tarball resolves to the underscore directory"
else
    fail "hyphenated tarball resolves to the underscore directory (got '$resolved')"
fi

new_fixture
mkdir -p "$PATCH_ROOT/overlays/2025.1/neutron-dynamic-routing/source"
resolved=$(resolve_project_dir "overlays/2025.1" "neutron_dynamic_routing-26.0.0.0rc2.dev2" "/source")
check_status "spelling variants also apply to overlays" 0 $?
if [[ $resolved == "overlays/2025.1/neutron-dynamic-routing/source" ]]; then
    ok "overlay variant resolves independently of the patch tree"
else
    fail "overlay variant resolves independently of the patch tree (got '$resolved')"
fi

echo
if [[ $failures -gt 0 ]]; then
    echo "$failures test(s) failed"
    exit 1
fi
echo "all tests passed"

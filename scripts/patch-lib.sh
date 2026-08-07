# Shared helpers for applying patches and for verifying that every patch file
# in the repository was actually applied.
#
# Sourced by scripts/001-prepare.sh and scripts/003-patch.sh, both of which are
# started from the repository root. PATCH_ROOT and PATCH_MANIFEST honour a
# pre-set value so scripts/test-patch-lib.sh can repoint them at a fixture.

PATCH_ROOT=${PATCH_ROOT:-$(pwd)}
PATCH_MANIFEST=${PATCH_MANIFEST:-$PATCH_ROOT/.patches-applied}

# Start a new, empty manifest. Called once, at the top of 001-prepare.sh.
reset_patch_manifest () {
    : > "$PATCH_MANIFEST"
}

# apply_patch <path relative to the repository root>
#
# Both patch invocations read through an absolute path, so the caller may be
# inside any directory. Gating the real apply as well as the dry-run is
# deliberate: previously only the dry-run was checked, so a real apply that
# failed after a passing dry-run left the build running. `exit` inside a
# sourced function terminates the whole script, which is what we want even in
# 001-prepare.sh, which does not set -e.
apply_patch () {
    local rel=$1
    local abs=$PATCH_ROOT/$rel

    echo "APPLY PATCH $rel"
    patch --forward --batch -p1 --dry-run < "$abs" || exit 1
    patch --forward --batch -p1 < "$abs" || exit 1
    echo "$rel" >> "$PATCH_MANIFEST"
}

# resolve_project_dir <root-relative root> <tarball top directory> [suffix]
#
# Derives the project name from the tarball's top-level directory and echoes
# the matching directory under <root>, root-relative, when it exists.
# Returns 1 when it does not.
resolve_project_dir () {
    local root=$1
    local directory=$2
    local suffix=${3:-}
    local name=${directory%-*}
    local candidate path

    # opendev emits PEP 625-normalized sdists, so a tarball may use underscores
    # where the directory in this repository uses hyphens, or the reverse. Each
    # tree is probed independently: a project may have only an overlay, spelled
    # differently from its patch directory. If both spellings exist in one tree
    # the first wins and the loser's files show up as unapplied, which the
    # verification at the end of 003-patch.sh reports.
    for candidate in "$name" "${name//_/-}" "${name//-/_}"; do
        path=$root/$candidate$suffix
        if [[ -d $PATCH_ROOT/$path ]]; then
            echo "$path"
            return 0
        fi
    done

    return 1
}

# verify_all_patches_applied <manifest> <root-relative directory>...
#
# Fails when a file exists under one of the given directories but is not
# recorded in the manifest. Directories that do not exist are ignored: a
# release may legitimately have no patches at all.
verify_all_patches_applied () {
    local manifest=$1
    shift

    if [[ ! -e $manifest ]]; then
        echo "ERROR: patch manifest $manifest is missing; run 001-prepare.sh first" >&2
        return 3
    fi

    local roots=() dir
    for dir in "$@"; do
        if [[ -d $PATCH_ROOT/$dir ]]; then
            roots+=("$PATCH_ROOT/$dir")
        fi
    done

    if [[ ${#roots[@]} -eq 0 ]]; then
        echo "VERIFIED: no patch directories for this release"
        return 0
    fi

    local tmp
    tmp=$(mktemp -d)
    find "${roots[@]}" -type f | sed "s|^$PATCH_ROOT/||" | sort > "$tmp/expected"
    sort -u "$manifest" > "$tmp/applied"
    comm -23 "$tmp/expected" "$tmp/applied" > "$tmp/missing"

    local expected_count missing_count
    expected_count=$(wc -l < "$tmp/expected")
    missing_count=$(wc -l < "$tmp/missing")

    if [[ $missing_count -gt 0 ]]; then
        echo "ERROR: patch files present in the repository but never applied:" >&2
        sed 's/^/  /' "$tmp/missing" >&2
        rm -rf "$tmp"
        return 3
    fi

    rm -rf "$tmp"
    echo "VERIFIED: $expected_count patch files, all applied"
    return 0
}

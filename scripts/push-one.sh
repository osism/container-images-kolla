#!/usr/bin/env bash

# Push one image and record what happened.
#
# 100-push.sh drives this under GNU parallel. parallel's own --joblog keeps
# a single row per job, so when a push is retried the earlier attempts leave
# no trace: only the last one is recorded, and its duration has to be
# reconstructed from the run's total span. stderr from all workers is
# interleaved in the job log with nothing tying a line to an image. This
# wrapper records each attempt separately instead.
#
# Two rows are written per attempt, a start and an end. A start with no
# matching end is an attempt that was still running when the job was
# killed, which is the case the timeouts under investigation produce and
# which a single row written after docker returns would lose entirely.
#
# Logging is best effort. If the record cannot be written the push still
# runs, with its output going to the job log as before: this is an
# observability wrapper and it must not be able to fail a publication.
#
# Available environment variables
#
# PUSH_LOG_DIR

set -u

IMAGE=$1

PUSH_LOG_DIR=${PUSH_LOG_DIR:-push-logs}

# kolla/nova-libvirt:2024.1 -> nova-libvirt_2024.1
SLUG=$(echo "$IMAGE" | sed 's|.*/||; s|:|_|g')

TSV=$PUSH_LOG_DIR/attempts.tsv
OUT=$PUSH_LOG_DIR/output/$SLUG.stdout
ERR=$PUSH_LOG_DIR/output/$SLUG.stderr

# Decide up front whether the output files can actually be appended to.
# A writable directory does not make them openable -- the path may exist
# as a directory, or be unwritable on its own -- and a redirection that
# cannot be opened stops docker from running at all. Probing both here
# means the choice is made before the push rather than at it.
if mkdir -p "$PUSH_LOG_DIR/output" "$PUSH_LOG_DIR/layers" 2>/dev/null &&
    : >> "$OUT" 2>/dev/null &&
    : >> "$ERR" 2>/dev/null; then
    LOGGING=true
else
    LOGGING=false
    echo "push-one.sh: cannot write under $PUSH_LOG_DIR, logging to the job log" >&2
fi

# Local size and layer IDs. These describe what we hold, not what crosses
# the wire: the registry skips blobs it already has, so bytes uploaded are
# not derivable from them. Best effort, and never fatal.
SIZE=$(docker image inspect --format '{{.Size}}' "$IMAGE" 2>/dev/null) || SIZE=
LAYERS=$(docker image inspect --format '{{range .RootFS.Layers}}{{println .}}{{end}}' "$IMAGE" 2>/dev/null) || LAYERS=
LAYER_COUNT=$(echo "$LAYERS" | grep -c . || true)
if [[ -n $LAYERS && $LOGGING == true ]]; then
    echo "$LAYERS" > "$PUSH_LOG_DIR/layers/$SLUG.txt" 2>/dev/null || true
fi

# One tab-separated row per event. Short enough to be written by a single
# append, which keeps it intact when several workers log at once.
record() {
    [[ $LOGGING == true ]] || return 0
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$1" "$IMAGE" "$2" "$3" "$4" "${SIZE:-}" "$LAYER_COUNT" \
        >> "$TSV" 2>/dev/null || true
}

START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
START_EPOCH=$(date +%s)
record start "$START" - -

if [[ $LOGGING == true ]]; then
    echo "=== attempt started $START ===" >> "$OUT" 2>/dev/null || true
    echo "=== attempt started $START ===" >> "$ERR" 2>/dev/null || true
    docker push "$IMAGE" >> "$OUT" 2>> "$ERR"
    RC=$?
else
    docker push "$IMAGE"
    RC=$?
fi

record end "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(($(date +%s) - START_EPOCH))" "$RC"

exit $RC

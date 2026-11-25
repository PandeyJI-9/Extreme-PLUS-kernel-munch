#!/usr/bin/env bash
# Self-check: a patch that cannot apply must fail the build, never be swallowed.
#   ./test_patch_fail.sh
set -u
cd "$(dirname "$0")"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

rc=0
./apply-all.sh "$tmp" >"$tmp/log" 2>&1 || rc=$?

if [ "$rc" -eq 0 ]; then
    echo "FAIL: apply-all.sh exited 0 even though no patch could be applied to an empty tree"
    tail -5 "$tmp/log"
    exit 1
fi

if ! grep -q "\[FAIL\]" "$tmp/log"; then
    echo "FAIL: apply-all.sh exited $rc but reported no per-patch failure"
    exit 1
fi

echo "PASS: apply-all.sh exits $rc and names the patches that failed"

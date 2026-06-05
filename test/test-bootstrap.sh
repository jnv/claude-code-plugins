#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.."
. test/helpers.sh
. test/fixtures.sh

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Arrange a fake plugin root with checksums.txt and a fake release server (dir).
plugin_root="$work/plugin"
rel="$work/rel"
mkdir -p "$plugin_root"
make_release_archive "$rel" "linux-x64"
sha="$(sha_of "$rel/v9.9.9/context-king-linux-x64.tar.gz")"
printf '%s  %s\n' "$sha" "context-king-linux-x64.tar.gz" > "$plugin_root/checksums.txt"

target="$work/data/v9.9.9"

# Act
CLAUDE_PLUGIN_ROOT="$plugin_root" \
CK_RELEASE_BASE_URL="file://$rel" \
bash plugins/context-king/bin/ck-bootstrap.sh v9.9.9 linux-x64 "$target"

# Assert: extracted binary + model present and runnable
assert_file "$target/ck" "binary extracted"
assert_file "$target/models/bge-small-en-v1.5/vocab.txt" "model extracted"
out="$("$target/ck" find-files foo 2>&1)"
assert_eq "$(echo "$out" | grep -c 'FAKE-CK')" "1" "extracted binary runs"

# Idempotency: a second run must exit 0 without re-downloading, even if the
# release URL is now unreachable (the [ -x target/ck ] guard short-circuits).
if CLAUDE_PLUGIN_ROOT="$plugin_root" CK_RELEASE_BASE_URL="file:///definitely-not-here" \
   bash plugins/context-king/bin/ck-bootstrap.sh v9.9.9 linux-x64 "$target" >/dev/null 2>&1; then
  echo "  ok: idempotent re-run exits 0"
else
  echo "  FAIL: idempotent re-run did not exit 0"; FAILED=1
fi

# Assert: checksum mismatch is rejected (corrupt checksums.txt)
printf '%s  %s\n' "deadbeef" "context-king-linux-x64.tar.gz" > "$plugin_root/checksums.txt"

if CLAUDE_PLUGIN_ROOT="$plugin_root" CK_RELEASE_BASE_URL="file://$rel" \
   bash plugins/context-king/bin/ck-bootstrap.sh v9.9.9 linux-x64 "$work/data2/v9.9.9" 2>/dev/null; then
  echo "  FAIL: mismatch not rejected"; FAILED=1
else
  echo "  ok: checksum mismatch rejected"
fi
assert_eq "$([ -e "$work/data2/v9.9.9" ] && echo exists || echo absent)" "absent" "no partial dir on mismatch"

finish

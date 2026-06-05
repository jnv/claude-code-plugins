#!/usr/bin/env bash
# Download, verify, and extract the ck binary + native libs + model for one
# platform into a version-namespaced data dir. Idempotent and atomic.
#
# Usage: ck-bootstrap.sh <version> <rid> <target-dir>
set -euo pipefail

VERSION="${1:?version required}"
RID="${2:?rid required}"
TARGET_DIR="${3:?target dir required}"

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BASE_URL="${CK_RELEASE_BASE_URL:-https://github.com/Fredrik-C/ContextKing/releases/download}"
ARCHIVE="context-king-${RID}.tar.gz"
URL="${BASE_URL}/${VERSION}/${ARCHIVE}"

[ -x "$TARGET_DIR/ck" ] && exit 0   # already bootstrapped

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}';
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}

tmp="$(mktemp -d)"
stage="$(mktemp -d)"
trap 'rm -rf "$tmp" "$stage"' EXIT

echo "ck: downloading $ARCHIVE ($VERSION)..." >&2
curl -fSL --retry 3 --progress-bar -o "$tmp/$ARCHIVE" "$URL"

want="$(awk -v f="$ARCHIVE" '$2 == f {print $1}' "$PLUGIN_ROOT/checksums.txt")"
[ -n "$want" ] || { echo "ck: no checksum for $ARCHIVE in checksums.txt" >&2; exit 1; }
got="$(sha256_of "$tmp/$ARCHIVE")"
if [ "$want" != "$got" ]; then
  echo "ck: checksum mismatch for $ARCHIVE (expected $want, got $got)" >&2
  exit 1
fi

echo "ck: extracting..." >&2
tar -xzf "$tmp/$ARCHIVE" -C "$tmp"
src="$tmp/context-king"

mkdir -p "$stage/models"
cp -a "$src/skills/ck/." "$stage/"          # binary + native libs
cp -a "$src/models/bge-small-en-v1.5" "$stage/models/"
chmod +x "$stage/ck"

mkdir -p "$(dirname "$TARGET_DIR")"
# clean up a leftover .partial from a previous run interrupted mid-publish
rm -rf "$TARGET_DIR.partial"
mv "$stage" "$TARGET_DIR.partial"
mv "$TARGET_DIR.partial" "$TARGET_DIR"
echo "ck: ready at $TARGET_DIR" >&2

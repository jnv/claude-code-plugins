#!/usr/bin/env bash
# Maintainer tool: regenerate the context-king plugin payload from an upstream
# ContextKing release. Lives at the marketplace repo root; NOT shipped in the
# plugin. Usage: scripts/ck-update.sh [--version vX.Y.Z] [--commit]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN="$REPO_ROOT/plugins/context-king"

UPSTREAM_REPO="${CK_UPSTREAM_REPO:-Fredrik-C/ContextKing}"
SRC_BASE="${CK_UPSTREAM_SRC_BASE:-https://github.com/${UPSTREAM_REPO}/archive/refs/tags}"
REL_BASE="${CK_RELEASE_BASE_URL:-https://github.com/${UPSTREAM_REPO}/releases/download}"

VERSION=""
DO_COMMIT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION="${2:?}"; shift 2 ;;
    --commit)  DO_COMMIT=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$VERSION" ]; then
  command -v jq >/dev/null 2>&1 || { echo "jq is required to auto-detect the latest version; install it or pass --version" >&2; exit 1; }
  VERSION="$(curl -fsSL "https://api.github.com/repos/${UPSTREAM_REPO}/releases/latest" \
    | jq -r '.tag_name')"
fi
[ -n "$VERSION" ] || { echo "could not resolve version" >&2; exit 1; }
echo "Syncing context-king plugin to $VERSION" >&2

# win-x64 intentionally excluded: the plugin targets macOS + Linux in v1.
RIDS="osx-arm64 osx-x64 linux-x64 linux-arm64"
HOOKS="ck-bash-guard.sh ck-read-guard.sh ck-search-guard.sh ck-scope-hint.sh ck-postsession.sh agent-usage-guard.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Fetching source $VERSION..." >&2
curl -fSL -o "$tmp/src.tar.gz" "${SRC_BASE}/${VERSION}.tar.gz"
tar -xzf "$tmp/src.tar.gz" -C "$tmp"
SRC="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n 1)"

# Replace skills + agents, copy only the shipped hooks.
rm -rf "$PLUGIN/skills" "$PLUGIN/agents"
mkdir -p "$PLUGIN/skills" "$PLUGIN/agents" "$PLUGIN/hooks"
cp -a "$SRC/skills/." "$PLUGIN/skills/"
rm -rf "$PLUGIN/skills/ck"                 # binary+libs are downloaded, not shipped
cp -a "$SRC/agents/explore.md" "$PLUGIN/agents/"
rm -f "$PLUGIN/hooks/"*.sh
for h in $HOOKS; do cp -a "$SRC/hooks/$h" "$PLUGIN/hooks/$h"; done

# Rewrite the bundled invocation path to the bare on-PATH command (idempotent).
# Assumes upstream invokes ck via the bare ".claude/skills/ck/ck" form (true as
# of the pinned release). An absolute "~/.claude/..." form would NOT be matched;
# re-verify on version bumps if upstream changes how skills/hooks invoke ck.
adapt_path() { local f="$1" t="$1.tmp.$$"; sed 's#\.claude/skills/ck/ck#ck#g' "$f" > "$t" && mv "$t" "$f"; }
while IFS= read -r f; do adapt_path "$f"; done < <(find "$PLUGIN/skills" -name 'SKILL.md')
for h in $HOOKS; do adapt_path "$PLUGIN/hooks/$h"; done

# Checksums of each per-platform archive.
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}';
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}
: > "$PLUGIN/checksums.txt"
for rid in $RIDS; do
  a="context-king-${rid}.tar.gz"
  echo "Hashing $a..." >&2
  curl -fSL -o "$tmp/$a" "${REL_BASE}/${VERSION}/${a}"
  printf '%s  %s\n' "$(sha256_of "$tmp/$a")" "$a" >> "$PLUGIN/checksums.txt"
done

# Version pin + plugin.json bump.
echo "$VERSION" > "$PLUGIN/UPSTREAM_VERSION"
plain="${VERSION#v}"
pj="$PLUGIN/.claude-plugin/plugin.json"
sed "s/\"version\": *\"[^\"]*\"/\"version\": \"$plain\"/" "$pj" > "$pj.tmp" && mv "$pj.tmp" "$pj"

echo "Done. Review 'git diff' and open a PR." >&2
if [ "$DO_COMMIT" = "1" ]; then
  git -C "$REPO_ROOT" add -A plugins/context-king
  git -C "$REPO_ROOT" commit -m "chore: sync context-king plugin to $VERSION"
fi

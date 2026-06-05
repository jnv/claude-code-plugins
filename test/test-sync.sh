#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.."
. test/helpers.sh
. test/fixtures.sh

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Build a throwaway copy of the repo's plugin dir to mutate.
repo="$work/repo"
mkdir -p "$repo/plugins/context-king/.claude-plugin" "$repo/scripts" "$repo/plugins/context-king/hooks"
cp scripts/ck-update.sh "$repo/scripts/ck-update.sh"
cp plugins/context-king/.claude-plugin/plugin.json "$repo/plugins/context-king/.claude-plugin/plugin.json"
git -C "$repo" init -q

# Fixtures: source archive + four release archives.
src="$work/src"; rel="$work/rel"; mkdir -p "$src" "$rel"
make_source_archive "$src"
for rid in osx-arm64 osx-x64 linux-x64 linux-arm64; do make_release_archive "$rel" "$rid"; done

# Act
CK_UPSTREAM_SRC_BASE="file://$src" CK_RELEASE_BASE_URL="file://$rel" \
  bash "$repo/scripts/ck-update.sh" --version v9.9.9

P="$repo/plugins/context-king"
# Skills copied + invocation path rewritten + ck/ dropped
assert_file "$P/skills/ck-find-files/SKILL.md" "skill copied"
assert_not_contains "$P/skills/ck-find-files/SKILL.md" ".claude/skills/ck/ck" "path rewritten in skill"
assert_contains "$P/skills/ck-find-files/SKILL.md" "Run: ck find-files" "bare ck command"
assert_eq "$([ -e "$P/skills/ck" ] && echo y || echo n)" "n" "skills/ck dropped"
# Hooks: shipped set present, update-check excluded
assert_file "$P/hooks/ck-bash-guard.sh" "guard hook copied"
assert_eq "$([ -e "$P/hooks/ck-update-check.sh" ] && echo y || echo n)" "n" "update-check excluded"
assert_not_contains "$P/hooks/ck-bash-guard.sh" ".claude/skills/ck/ck" "path rewritten in hook"
# Agent
assert_file "$P/agents/explore.md" "agent copied"
# Version pin + plugin.json bump
assert_contains "$P/UPSTREAM_VERSION" "v9.9.9" "UPSTREAM_VERSION pinned"
assert_contains "$P/.claude-plugin/plugin.json" "\"version\": \"9.9.9\"" "plugin.json version bumped"
# checksums.txt: 4 lines matching fixture hashes
assert_eq "$(wc -l < "$P/checksums.txt" | tr -d ' ')" "4" "four checksums"
want="$(sha_of "$rel/v9.9.9/context-king-linux-x64.tar.gz")"
assert_contains "$P/checksums.txt" "$want" "linux-x64 checksum correct"

# Idempotency: a second run rewrites paths identically (no double-mangling).
CK_UPSTREAM_SRC_BASE="file://$src" CK_RELEASE_BASE_URL="file://$rel" \
  bash "$repo/scripts/ck-update.sh" --version v9.9.9
assert_contains "$P/skills/ck-find-files/SKILL.md" "Run: ck find-files" "idempotent rewrite"

finish

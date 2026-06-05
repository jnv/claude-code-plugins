#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")/.."
. test/helpers.sh
j=plugins/context-king/hooks/hooks.json

assert_file "$j" "hooks.json exists"
jq -e . "$j" >/dev/null && echo "  ok: valid json" || { echo "  FAIL: invalid json"; FAILED=1; }

# Required events present
for ev in PreToolUse PostToolUse Stop SubagentStart; do
  assert_eq "$(jq -r --arg e "$ev" '.hooks[$e] | length > 0' "$j")" "true" "$ev present"
done
# ck-update-check must NOT be wired (plugin updates owned by /plugin)
assert_not_contains "$j" "ck-update-check" "no update-check hook"
# SessionStart must be absent (its only use was update-check)
assert_eq "$(jq -r '.hooks.SessionStart // "absent"' "$j")" "absent" "no SessionStart"
# Paths use the plugin-root variable
assert_contains "$j" '${CLAUDE_PLUGIN_ROOT}' "uses CLAUDE_PLUGIN_ROOT"

finish

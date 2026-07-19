#!/usr/bin/env bash
# Lint: plugin manifest + marketplace + skill location are consistent and loadable.
# Verifies the Plan-A layout: source="./", root plugin.json, skill auto-discoverable
# at skills/flow-status/SKILL.md. Run: bash test/test-plugin.bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
assert() { if eval "$1"; then printf '  ok %s\n' "$2"; PASS=$((PASS+1)); else printf '  FAIL %s\n' "$2" >&2; FAIL=$((FAIL+1)); fi; }

MP="$ROOT/.claude-plugin/marketplace.json"
PJ="$ROOT/.claude-plugin/plugin.json"
SKILL="$ROOT/skills/flow-status"

assert '[[ -f "$MP" ]]' "marketplace.json exists"
assert '[[ -f "$PJ" ]]' "plugin.json exists"
assert 'jq -e ".plugins[0].source == \"./\"" "$MP" >/dev/null' "marketplace source is ./"
assert 'jq -e ".plugins[0].name == \"flow-status\"" "$MP" >/dev/null' "marketplace plugin name=flow-status"
assert 'jq -e ".name == \"flow-status\"" "$PJ" >/dev/null' "plugin.json name=flow-status"
assert 'jq -e ".version" "$PJ" >/dev/null' "plugin.json has version"
assert 'jq -e ".description" "$PJ" >/dev/null' "plugin.json has description"
assert '[[ -f "$SKILL/SKILL.md" ]]' "skill discoverable at skills/flow-status/SKILL.md"
assert 'grep -q "^name: flow-status$" "$SKILL/SKILL.md"' "skill frontmatter name=flow-status"
assert '[[ -f "$SKILL/mcp.sh" ]]' "mcp.sh in skill dir"
assert '[[ -f "$SKILL/install.sh" ]]' "install.sh in skill dir"
assert '[[ -f "$SKILL/README.md" ]]' "README.md in skill dir"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]

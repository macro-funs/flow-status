#!/usr/bin/env bash
# Lint: README has the required sections + the one-click install command.
# Run: bash test/test-readme.bash
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills/flow-status" && pwd)"
README="$SKILL_DIR/README.md"
PASS=0; FAIL=0
assert() { if eval "$1"; then printf '  ok %s\n' "$2"; PASS=$((PASS+1)); else printf '  FAIL %s\n' "$2" >&2; FAIL=$((FAIL+1)); fi; }

assert '[[ -f "$README" ]]' "README.md exists"
assert 'grep -qi "Personal Access Token" "$README"' "PAT section present"
assert 'grep -q "curl -fsSL.*install.sh" "$README"' "one-click curl install command present"
assert 'grep -qi "plugin marketplace" "$README"' "plugin marketplace install documented"
assert 'grep -q "FLOW_STATUS_MCP_TOKEN" "$README"' "config env var documented"
assert 'grep -q "Authorization: Bearer fs_" "$README"' "Claude Desktop/Cursor Bearer config documented"
assert 'grep -qi "troubleshoot\|故障" "$README"' "troubleshooting section present"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]

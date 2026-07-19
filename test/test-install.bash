#!/usr/bin/env bash
# Unit test for install.sh: file placement, executability, idempotency.
# Run: bash test/test-install.bash
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills/flow-status" && pwd)"
INSTALL_SH="$SKILL_DIR/install.sh"
PASS=0; FAIL=0
assert() { if eval "$1"; then printf '  ok %s\n' "$2"; PASS=$((PASS+1)); else printf '  FAIL %s\n' "$2" >&2; FAIL=$((FAIL+1)); fi; }

TMP_HOME="$(mktemp -d)"; trap 'rm -rf "$TMP_HOME"' EXIT
export HOME="$TMP_HOME"
export CLAUDE_SKILLS_DIR="$TMP_HOME/.claude/skills"
export CLAUDE_SKILLS_DIR   # also visible to install.sh
exec 0</dev/null   # non-interactive: skip the TTY prompt

# Run 1: fresh install (local mode - siblings exist next to install.sh)
bash "$INSTALL_SH" > /dev/null 2>&1
assert '[[ -f "$CLAUDE_SKILLS_DIR/flow-status/SKILL.md" ]]' "SKILL.md installed"
assert '[[ -f "$CLAUDE_SKILLS_DIR/flow-status/mcp.sh" ]]' "mcp.sh installed"
assert '[[ -f "$CLAUDE_SKILLS_DIR/flow-status/README.md" ]]' "README.md installed"
assert '[[ -x "$CLAUDE_SKILLS_DIR/flow-status/mcp.sh" ]]' "mcp.sh is executable"
assert '[[ -f "$TMP_HOME/.config/flow-status-mcp/env" ]]' "config template created"
assert '[[ "$(stat -f '%Lp' "$TMP_HOME/.config/flow-status-mcp/env" 2>/dev/null || stat -c '%a' "$TMP_HOME/.config/flow-status-mcp/env")" == "600" ]]' "config chmod 600"

# Run 2: re-run must not clobber a token the user wrote in.
ENV="$TMP_HOME/.config/flow-status-mcp/env"
sed -i.bak -E 's|^FLOW_STATUS_MCP_TOKEN=.*|FLOW_STATUS_MCP_TOKEN=fs_usersaved|; s|^FLOW_STATUS_BASE_URL=.*|FLOW_STATUS_BASE_URL=http://127.0.0.1:1|' "$ENV" && rm -f "$ENV.bak"
bash "$INSTALL_SH" > /dev/null 2>&1
assert 'grep -q "fs_usersaved" "$ENV"' "re-run preserves existing token"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]

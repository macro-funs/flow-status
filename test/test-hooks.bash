#!/usr/bin/env bash
# Lint + behavior test for the plugin SessionStart hook.
# Verifies hooks/hooks.json registers a SessionStart command hook pointing at
# check-config.sh via ${CLAUDE_PLUGIN_ROOT}, and that the script is silent when
# a PAT is configured and prints a non-blocking hint when it's missing.
# Run: bash test/test-hooks.bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
assert() { if eval "$1"; then printf '  ok %s\n' "$2"; PASS=$((PASS+1)); else printf '  FAIL %s\n' "$2" >&2; FAIL=$((FAIL+1)); fi; }

HJ="$ROOT/hooks/hooks.json"
CC="$ROOT/hooks/check-config.sh"

# --- manifest structure ---
assert '[[ -f "$HJ" ]]' "hooks/hooks.json exists"
assert '[[ -x "$CC" ]]' "check-config.sh exists and is executable"
assert 'jq -e ".hooks.SessionStart" "$HJ" >/dev/null' "SessionStart hook registered"
assert 'jq -e ".hooks.SessionStart[0].hooks[0].type == \"command\"" "$HJ" >/dev/null' "hook type=command"
assert 'jq -er ".hooks.SessionStart[0].hooks[0].command == \"bash\"" "$HJ" >/dev/null' "hook command=bash (exec form)"
assert 'grep -q "CLAUDE_PLUGIN_ROOT}/hooks/check-config.sh" "$HJ"' "hook args reference check-config.sh via CLAUDE_PLUGIN_ROOT"

# --- behavior ---
TMP_HOME="$(mktemp -d)"; trap 'rm -rf "$TMP_HOME"' EXIT
export HOME="$TMP_HOME"
export CLAUDE_PLUGIN_ROOT="$ROOT"
CFG_DIR="$TMP_HOME/.config/flow-status-mcp"

# Case 1: token in env var -> silent, exit 0.
out=$(FLOW_STATUS_MCP_TOKEN=fs_test bash "$CC" 2>&1); rc=$?
assert '[[ $rc -eq 0 ]]' "configured (env): exit 0"
assert '[[ -z "$out" ]]' "configured (env): silent"

# Case 2: token in config file -> silent, exit 0.
mkdir -p "$CFG_DIR"
printf 'FLOW_STATUS_MCP_TOKEN=fs_test\nFLOW_STATUS_BASE_URL=http://x:1\n' > "$CFG_DIR/env"
out=$(env -u FLOW_STATUS_MCP_TOKEN bash "$CC" 2>&1); rc=$?
assert '[[ $rc -eq 0 ]]' "configured (file): exit 0"
assert '[[ -z "$out" ]]' "configured (file): silent"

# Case 3: no token anywhere -> hint printed, exit 0 (non-blocking).
rm -f "$CFG_DIR/env"
out=$(env -u FLOW_STATUS_MCP_TOKEN bash "$CC" 2>/dev/null); rc=$?
assert '[[ $rc -eq 0 ]]' "unconfigured: exit 0 (non-blocking)"
assert 'grep -q "FLOW_STATUS_MCP_TOKEN" <<<"$out"' "unconfigured: hint mentions token var"
assert 'grep -q "install.sh" <<<"$out"' "unconfigured: hint mentions installer"
assert 'grep -q "mcp.sh" <<<"$out"' "unconfigured: hint mentions mcp.sh check"
assert 'grep -q "not configured yet" <<<"$out"' "unconfigured: hint is clearly a setup nudge"

# Case 4: config file present but token line empty -> hint (treated as missing).
mkdir -p "$CFG_DIR"
printf 'FLOW_STATUS_MCP_TOKEN=\nFLOW_STATUS_BASE_URL=http://x:1\n' > "$CFG_DIR/env"
out=$(env -u FLOW_STATUS_MCP_TOKEN bash "$CC" 2>/dev/null); rc=$?
assert '[[ $rc -eq 0 ]]' "empty token (file): exit 0"
assert 'grep -q "not configured yet" <<<"$out"' "empty token (file): prints hint"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]

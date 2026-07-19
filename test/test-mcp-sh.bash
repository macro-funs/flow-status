#!/usr/bin/env bash
# Unit test for mcp.sh: verifies JSON-RPC request construction and response parsing
# by stubbing curl (no running app needed). Run: bash test/test-mcp-sh.bash
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills/flow-status" && pwd)"
MCP_SH="$SKILL_DIR/mcp.sh"
PASS=0; FAIL=0

assert_eq() { # <label> <expected> <actual>
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then printf '  ok %s\n' "$label"; PASS=$((PASS+1));
  else printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$label" "$expected" "$actual" >&2; FAIL=$((FAIL+1)); fi
}
assert() { # <condition> <label>
  if eval "$1"; then printf '  ok %s\n' "$2"; PASS=$((PASS+1));
  else printf '  FAIL %s\n' "$2" >&2; FAIL=$((FAIL+1)); fi
}

export FLOW_STATUS_MCP_TOKEN="fs_testtoken"
export FLOW_STATUS_BASE_URL="http://stub.test"
STUB_DIR="$(mktemp -d)"; trap 'rm -rf "$STUB_DIR"' EXIT
LAST_BODY="$STUB_DIR/last_body"
CURL_RESP="$STUB_DIR/curl_resp"

cat > "$STUB_DIR/curl" <<'EOF'
#!/usr/bin/env bash
# Record the -d body, then echo the canned response file.
out=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d) out="$2"; shift 2 ;;
    *) shift ;;
  esac
done
printf '%s' "$out" > "${LAST_BODY}"
cat "${CURL_RESP}"
EOF
chmod +x "$STUB_DIR/curl"
export PATH="$STUB_DIR:$PATH"
export LAST_BODY CURL_RESP

# check: expects tools/list, returns 3 tools
printf '%s' '{"jsonrpc":"2.0","id":1,"result":{"tools":[{"name":"list_tasks","description":"d1"},{"name":"get_task","description":"d2"},{"name":"create_task","description":"d3"}]}}' > "$CURL_RESP"
out=$(bash "$MCP_SH" check)
assert_eq "check prints tool count" "OK (3 tools) @ http://stub.test" "$out"
assert_eq "check sent tools/list" "tools/list" "$(jq -r '.method' "$LAST_BODY")"

# list: prints each tool name + description (column -t pads tabs to spaces, so check membership)
out=$(bash "$MCP_SH" list)
for name in list_tasks get_task create_task; do
  assert "grep -qw '$name' <<<\"\$out\"" "list contains $name"
done

# tool call: create_task, asserts body shape + parses content[0].text
printf '%s' '{"jsonrpc":"2.0","id":1,"result":{"content":[{"type":"text","text":"{\"id\":42,\"title\":\"x\"}"}],"isError":false}}' > "$CURL_RESP"
out=$(bash "$MCP_SH" create_task '{"title":"x"}')
assert_eq "tool call parsed payload" '{"id":42,"title":"x"}' "$(printf '%s' "$out" | jq -c .)"
assert_eq "tool call name" "create_task" "$(jq -r '.params.name' "$LAST_BODY")"
assert_eq "tool call arg" "x" "$(jq -r '.params.arguments.title' "$LAST_BODY")"

# tool error: isError true -> exit 1, msg on stderr
printf '%s' '{"jsonrpc":"2.0","id":1,"result":{"content":[{"type":"text","text":"title is required"}],"isError":true}}' > "$CURL_RESP"
set +e; err=$(bash "$MCP_SH" create_task '{"title":""}' 2>&1 >/dev/null); rc=$?; set -e
assert_eq "tool error exit code" "1" "$rc"
assert_eq "tool error message" "tool error: title is required" "$err"

# rpc error: .error object -> exit 1
printf '%s' '{"jsonrpc":"2.0","id":1,"error":{"code":-32601,"message":"method not found"}}' > "$CURL_RESP"
set +e; err=$(bash "$MCP_SH" unknown_tool '{}' 2>&1 >/dev/null); rc=$?; set -e
assert_eq "rpc error exit code" "1" "$rc"
assert_eq "rpc error message" "rpc error -32601: method not found" "$err"

# missing token: exit 1 with hint
unset FLOW_STATUS_MCP_TOKEN
export FLOW_STATUS_CONFIG_FILE="$STUB_DIR/nonexistent_env"
set +e; err=$(bash "$MCP_SH" check 2>&1 >/dev/null); rc=$?; set -e
assert_eq "no-token exit code" "1" "$rc"
case "$err" in *"FLOW_STATUS_MCP_TOKEN"*) assert_eq "no-token hint" "yes" "yes" ;; *) assert_eq "no-token hint" "yes" "no" ;; esac

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]

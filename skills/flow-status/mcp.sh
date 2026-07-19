#!/usr/bin/env bash
# flow-status MCP client helper (portable, consumer edition).
# Calls POST /mcp (JSON-RPC 2.0) authenticated with a Personal Access Token (PAT).
#
# Config (exported env var wins; else read from ~/.config/flow-status-mcp/env):
#   FLOW_STATUS_BASE_URL    default http://localhost:8083  (this appends /mcp)
#   FLOW_STATUS_MCP_TOKEN   required - a PAT (fs_...) from the flow-status MCP接入 page.
#
# Usage:
#   mcp.sh check                # verify the PAT works (tools/list round-trip)
#   mcp.sh list                  # tools/list -> tool names + descriptions
#   mcp.sh <tool> '<json-args>' # tools/call -> the tool result JSON (pretty)
#   mcp.sh raw  '<json-rpc-body>' # send a raw JSON-RPC request, print full response
#
# Exit codes: 0 success; 1 config/protocol/tool error (message on stderr).
set -euo pipefail

# Resolve this script's directory so it works from any CWD / install location.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Pull config from the user-scoped env file when env vars aren't exported.
CONFIG_FILE="${FLOW_STATUS_CONFIG_FILE:-$HOME/.config/flow-status-mcp/env}"
if [[ -z "${FLOW_STATUS_MCP_TOKEN:-}" && -f "$CONFIG_FILE" ]]; then
  set -a; . "$CONFIG_FILE"; set +a
fi

BASE="${FLOW_STATUS_BASE_URL:-http://localhost:8083}"
TOKEN="${FLOW_STATUS_MCP_TOKEN:-}"

if [[ -z "$TOKEN" ]]; then
  echo "Set FLOW_STATUS_MCP_TOKEN (a PAT from the flow-status MCP接入 page, e.g. fs_...)." >&2
  echo "Either export it, or put it in: $CONFIG_FILE" >&2
  echo "    FLOW_STATUS_MCP_TOKEN=fs_..." >&2
  echo "    FLOW_STATUS_BASE_URL=http://your-host:8083   # optional" >&2
  exit 1
fi

rpc() {  # rpc '<json-rpc-body>' -> full response JSON
  local body="$1"
  curl -fsS -X POST "$BASE/mcp" \
    -H "Authorization: Bearer $TOKEN" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    -d "$body" \
    || { echo "MCP request failed (HTTP error - PAT revoked, app down, or wrong base URL: $BASE). Run 'mcp.sh check'." >&2; exit 1; }
}

cmd="${1:-}"; shift || true

case "$cmd" in
  check)
    body=$(jq -nc '{jsonrpc:"2.0",id:1,method:"tools/list"}')
    resp=$(rpc "$body")
    n=$(printf '%s' "$resp" | jq -r '.result.tools | length')
    printf 'OK (%s tools) @ %s\n' "$n" "$BASE"
    ;;
  list)
    body=$(jq -nc '{jsonrpc:"2.0",id:1,method:"tools/list"}')
    rpc "$body" | jq -r '.result.tools[] | "\(.name)\t\(.description)"' | column -t -s $'\t'
    ;;
  raw)
    [[ $# -ge 1 ]] || { echo "usage: mcp.sh raw '<json-rpc-body>'" >&2; exit 1; }
    rpc "$1" | jq .
    ;;
  "")
    echo "usage: mcp.sh check | list | <tool> '<json-args>' | raw '<body>'" >&2
    exit 1
    ;;
  *)
    tool="$cmd"
    args="${1-}"
    [[ -z "$args" ]] && args='{}'
    body=$(jq -nc --arg name "$tool" --argjson args "$args" \
      '{jsonrpc:"2.0",id:1,method:"tools/call",params:{name:$name,arguments:$args}}')
    resp=$(rpc "$body")
    if printf '%s' "$resp" | jq -e '.error' >/dev/null 2>&1; then
      printf 'rpc error %s: %s\n' "$(printf '%s' "$resp" | jq -r '.error.code')" \
                                  "$(printf '%s' "$resp" | jq -r '.error.message')" >&2
      exit 1
    fi
    if [[ "$(printf '%s' "$resp" | jq -r '.result.isError // false')" == "true" ]]; then
      printf 'tool error: %s\n' "$(printf '%s' "$resp" | jq -r '.result.content[0].text')" >&2
      exit 1
    fi
    printf '%s' "$resp" | jq -r '.result.content[0].text' | jq .
    ;;
esac

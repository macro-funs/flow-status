#!/usr/bin/env bash
# flow-status plugin - SessionStart hook.
# Silent when a PAT is configured; prints a one-time setup hint when it's
# missing, so a freshly /plugin install'd flow-status points the user at the
# next step instead of failing silently on first use.
#
# Config resolution matches mcp.sh: exported FLOW_STATUS_MCP_TOKEN wins,
# otherwise ~/.config/flow-status-mcp/env is read. No network calls - this
# runs on every session start and must stay fast and offline-safe.
set -euo pipefail

CONFIG_FILE="${FLOW_STATUS_CONFIG_FILE:-$HOME/.config/flow-status-mcp/env}"

token="${FLOW_STATUS_MCP_TOKEN:-}"
if [[ -z "$token" && -f "$CONFIG_FILE" ]]; then
  token="$(grep -E '^FLOW_STATUS_MCP_TOKEN=' "$CONFIG_FILE" | head -1 | cut -d= -f2- || true)"
fi

# Configured -> stay quiet (don't pollute every session).
if [[ -n "$token" ]]; then
  exit 0
fi

# Missing -> non-blocking hint. Printed to stdout so Claude Code surfaces it.
plugin_root="${CLAUDE_PLUGIN_ROOT:-}"
cat <<EOF
flow-status: not configured yet. Set your Personal Access Token (PAT, fs_...)
from the flow-status MCP接入 page, then this skill is ready to use.

  Edit $CONFIG_FILE:
    FLOW_STATUS_MCP_TOKEN=fs_...
    FLOW_STATUS_BASE_URL=http://your-host:8083   # optional

  Or run the installer:
    bash "${plugin_root}/skills/flow-status/install.sh"

Verify with:
  bash "${plugin_root}/skills/flow-status/mcp.sh" check
EOF
exit 0

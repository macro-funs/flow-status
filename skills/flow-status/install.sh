#!/usr/bin/env bash
# flow-status skill - one-click installer.
# Installs the skill into ~/.claude/skills/flow-status/ and configures a PAT.
#
# Install (curl, one-click):
#   curl -fsSL https://raw.githubusercontent.com/macro-funs/flow-status/main/skills/flow-status/install.sh | bash
# Install (local, from a clone of the repo):
#   bash skills/flow-status/install.sh
#
set -euo pipefail

REPO_RAW="${FLOW_STATUS_REPO_RAW:-https://raw.githubusercontent.com/macro-funs/flow-status/main}"
SKILL_NAME="flow-status"
CLAUDE_SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
TARGET_DIR="$CLAUDE_SKILLS_DIR/$SKILL_NAME"
CONFIG_DIR="$HOME/.config/flow-status-mcp"
CONFIG_FILE="$CONFIG_DIR/env"

FILES=(SKILL.md mcp.sh README.md)

# Locate source files: same dir as this script (local run), else download (curl run).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
src_for() { # <file> -> local path or empty
  local f="$1"
  if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/$f" ]]; then printf '%s' "$SCRIPT_DIR/$f"; return; fi
  printf ''
}
fetch() { # <file> -> stdout contents (local copy or curl)
  local f="$1" local_path
  local_path="$(src_for "$f")"
  if [[ -n "$local_path" ]]; then cat "$local_path"; return; fi
  curl -fsSL "$REPO_RAW/skills/$SKILL_NAME/$f"
}

echo "> Installing flow-status skill into $TARGET_DIR"
mkdir -p "$TARGET_DIR" "$CONFIG_DIR"

for f in "${FILES[@]}"; do
  fetch "$f" > "$TARGET_DIR/$f"
done
chmod +x "$TARGET_DIR/mcp.sh"

# Config file: create template if missing; never clobber an existing token.
if [[ ! -f "$CONFIG_FILE" ]]; then
  cat > "$CONFIG_FILE" <<'EOF'
# flow-status MCP client config. Edit FLOW_STATUS_MCP_TOKEN with your PAT (fs_...).
# Get a PAT from the flow-status MCP接入 page (or POST /api/tokens with a login JWT).
FLOW_STATUS_MCP_TOKEN=
FLOW_STATUS_BASE_URL=http://localhost:8083
EOF
  chmod 600 "$CONFIG_FILE"
  echo "> Created config template: $CONFIG_FILE"
else
  echo "> Kept existing config: $CONFIG_FILE"
fi

# Interactive PAT entry (only when stdin is a TTY; curl|bash skips this).
if [[ -t 0 ]]; then
  current_base="$(grep -E '^FLOW_STATUS_BASE_URL=' "$CONFIG_FILE" | cut -d= -f2- || true)"
  echo
  echo "Enter your PAT (fs_...) - leave blank to skip and edit $CONFIG_FILE later."
  printf 'PAT: '; read -r input_token
  printf 'Base URL (Enter for %s): ' "${current_base:-http://localhost:8083}"; read -r input_base
  if [[ -n "$input_token" ]]; then
    sed -i.bak -E "s|^FLOW_STATUS_MCP_TOKEN=.*|FLOW_STATUS_MCP_TOKEN=$input_token|" "$CONFIG_FILE" && rm -f "$CONFIG_FILE.bak"
  fi
  if [[ -n "$input_base" ]]; then
    sed -i.bak -E "s|^FLOW_STATUS_BASE_URL=.*|FLOW_STATUS_BASE_URL=$input_base|" "$CONFIG_FILE" && rm -f "$CONFIG_FILE.bak"
  fi
fi

echo
echo "> Verifying..."
if bash "$TARGET_DIR/mcp.sh" check 2>/dev/null; then
  echo "OK. flow-status skill is ready."
else
  echo "Installed, but 'mcp.sh check' did not succeed yet."
  echo "  Edit $CONFIG_FILE and set FLOW_STATUS_MCP_TOKEN to your fs_... PAT,"
  echo "  then run: bash $TARGET_DIR/mcp.sh check"
fi
echo
echo "In Claude Code, the skill is now available as '$SKILL_NAME' (restart the session if it was open)."

# flow-status

A [Claude Code](https://claude.com/claude-code) plugin (and installable skill) that connects Claude Code to a [flow-status](https://github.com/macro-funs/flow-status) instance, letting you view / create / update / complete / delete tasks, lists, and tags over MCP — authenticated with a Personal Access Token (PAT).

## Install

**Option 1 — Claude Code plugin marketplace (native):**

```text
/plugin marketplace add macro-funs/flow-status
/plugin install flow-status
```

**Option 2 — one-click script (curl):**

```bash
curl -fsSL https://raw.githubusercontent.com/macro-funs/flow-status/main/skills/flow-status/install.sh | bash
```

## Next steps

After installing, configure your PAT and verify the connection — see
[`skills/flow-status/README.md`](skills/flow-status/README.md) for the full guide:

- Getting a Personal Access Token (`fs_...`)
- Configuring `~/.config/flow-status-mcp/env`
- Connecting Claude Desktop / Cursor
- Troubleshooting

The skill itself lives in [`skills/flow-status/`](skills/flow-status/) (`SKILL.md`, `mcp.sh`, `install.sh`).

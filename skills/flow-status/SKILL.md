---
name: flow-status
description: Connect to a flow-status instance and manage its todos (tasks, lists, tags) over MCP. Use when the user wants to view/create/update/complete/delete flow-status tasks or manage lists/tags from inside Claude Code.
---

# flow-status skill (consumer)

Drive a **flow-status** task system from inside Claude Code, through its standard **MCP** endpoint (`POST /mcp`, JSON-RPC 2.0). All calls authenticate with a **Personal Access Token (PAT)** sent as `Authorization: Bearer fs_...`; every operation is scoped to the PAT's owner.

This is the portable, installable edition for **integrators**. (The flow-status repo also ships an internal `flow-status-mcp` skill for its own developers; this one is for everyone else.)

## Prerequisites

1. A running flow-status instance you can reach over HTTP (e.g. `http://your-host:8083`). The `/mcp` endpoint is served by the nginx front-end (port 8083) which proxies to the Spring Boot app (port 8082); either works if reachable.
2. A **PAT** (`fs_...`) from the flow-status **MCP接入** page (or created via `POST /api/tokens` with a login JWT). Configure it once via the installer or the config file below.
3. `jq` and `curl` on your PATH. (macOS: `brew install jq curl`; Debian/Ubuntu: `sudo apt-get install jq curl`.)

## Configuration

The helper reads config in this order (first wins): exported env var -> `~/.config/flow-status-mcp/env`.

`~/.config/flow-status-mcp/env`:
```
FLOW_STATUS_MCP_TOKEN=fs_...                      # required
FLOW_STATUS_BASE_URL=http://your-host:8083        # optional, default http://localhost:8083
```

Run the installer (`install.sh` in this directory) once to create this file interactively, or edit it by hand. If the token is missing, the helper prints a hint and exits 1.

## The helper

All MCP access goes through `mcp.sh` in this skill's directory (it resolves its own path, so call it from anywhere):
```
bash <skill-dir>/mcp.sh check                  # verify the PAT works (tools/list round-trip)
bash <skill-dir>/mcp.sh list                   # list the 23 tools
bash <skill-dir>/mcp.sh <tool> '<json-args>'   # call a tool; prints the result JSON
bash <skill-dir>/mcp.sh raw  '<json-rpc-body>' # send a raw JSON-RPC request
```

- **Success:** prints the tool's payload as pretty JSON (for `tools/call`, that's `result.content[0].text`).
- **Tool error** (unknown id, terminal-state conflict): `tool error: ...` on stderr, exit 1.
- **Protocol error** (unknown tool, bad params): `rpc error <code>: ...` on stderr, exit 1.
- Always read stderr when the script exits non-zero.

## Tool catalog (23 tools)

**Tasks - read:** `list_tasks` `{status?,priority?,listId?,tagId?,page?,size?}`, `get_task` `{id}`, `list_subtasks` `{parentId}`, `list_task_tags` `{taskId}`
**Tasks - write:** `create_task` `{title,content?,priority?,listId?,startTime?,endTime?,duration?,remindTime?,parentTaskId?}` (`priority` 1=LOW 2=NORMAL 3=HIGH 4=URGENT; `duration` minutes), `update_task` `{id,...}` (partial merge), `delete_task` `{id}`, `update_task_status` `{id,status}` (`status` ∈ pending/processing/completed/expired/cancelled), `bind_task_tag`/`unbind_task_tag` `{taskId,tagId}`
**Tasks - batch:** `batch_complete_tasks` `{ids:[...]}`, `batch_delete_tasks` `{ids:[...]}`, `batch_migrate_tasks` `{ids:[...],listId}`
**Lists:** `create_list` `{listName,color?,icon?,sort?}`, `update_list` `{id,...}`, `delete_list` `{id}`, `get_list` `{id}`, `list_lists` `{}`
**Tags:** `create_tag` `{tagName,color?}`, `update_tag` `{id,...}`, `delete_tag` `{id}`, `get_tag` `{id}`, `list_tags` `{}`

Datetimes are ISO-8601 (e.g. `2026-07-19T14:00:00`). Full server-side spec: `docs/mcp.md` in the flow-status repo.

## How to work

1. If unsure what's available, run `mcp.sh list`.
2. Map the user's request to one or more tools. Examples:
   - "what are my tasks today?" -> `list_tasks`, summarize `items`.
   - "add a task: 写周报, high priority" -> `create_task '{"title":"写周报","priority":4}'`, report the created id.
   - "mark task 12 done" -> `update_task_status '{"id":12,"status":"completed"}'`.
3. When a tool errors, read the message, fix the args, and retry - don't give up silently.
4. Report results to the user concisely in their language (Chinese/English).

## Notes

- The skill never sends a `userId` - the PAT carries identity; all data is the PAT owner's.
- The PAT is long-lived (no expiry, no refresh). If calls start failing with HTTP 401, the token was likely revoked - regenerate it on the MCP接入 page, update `FLOW_STATUS_MCP_TOKEN` (env var or `~/.config/flow-status-mcp/env`), and retry.
- This calls the flow-status MCP server (an HTTP endpoint you point at), not an external third-party service.
- For full setup (install, Claude Desktop/Cursor config, troubleshooting), see `README.md` in this directory.

# flow-status MCP Server

`flow-status` exposes the task system (tasks, lists, tags) over the **Model Context Protocol** so any MCP client (Claude Desktop, Cursor, etc.) can read and manipulate a user's todos directly.

## Endpoint

- **URL:** `POST http://<host>:8083/mcp`
- **Protocol:** MCP `2025-06-18`, JSON-RPC 2.0, **Streamable HTTP** transport.
- **Stateless:** the server does not issue or validate `Mcp-Session-Id`; each request is self-contained. Responses are `Content-Type: application/json`. Notifications (JSON-RPC messages without `id`) receive `HTTP 202` with no body. `GET /mcp` (SSE streaming) is not supported in v1.
- **Content type:** send `Content-Type: application/json`. `Accept: application/json, text/event-stream` is fine; the server always answers with `application/json`.

## Authentication

Every request must carry the user's Bearer JWT (the same token used by the REST API):

```
Authorization: Bearer <jwt>
```

The endpoint accepts either token type via the existing `JwtAuthFilter`, and every tool call is scoped to `AuthContext.currentUserId()` - a client can only ever touch the authenticated user's own data. There is no client-supplied `userId`.

- **JWT** (short-lived, `expiration-minutes: 120`): obtain via `POST /api/auth/login`. Fine for interactive sessions.
- **Personal Access Token (PAT)** (long-lived, `fs_...`, recommended for MCP clients): create via `POST /api/tokens {"name":"..."}` (needs a JWT), list with `GET /api/tokens`, revoke with `DELETE /api/tokens/{id}`. The plaintext token is returned **once** at creation. Use it as `Authorization: Bearer fs_...`.

## Lifecycle

```
1. initialize              -> {protocolVersion, capabilities:{tools:{}}, serverInfo}
2. notifications/initialized (notification) -> HTTP 202
3. tools/list              -> {tools:[{name, description, inputSchema}, ...]}
4. tools/call              -> {content:[{type:"text", text:"<json>"}], isError:false}
```

`ping` is also supported (returns `{}`).

## Error model

- **Tool execution failures** (not-found, terminal-state conflict, invalid enum value, missing required field) -> a `tools/call` result with `isError: true` and a text message. The model can read it and recover.
- **Protocol failures** -> a JSON-RPC `error` object: `-32700` parse error, `-32600` invalid request, `-32601` method not found, `-32602` invalid params (incl. unknown tool), `-32603` internal error.
- **Unauthenticated** -> `HTTP 401`.

## Tool catalog (23 tools)

**Tasks - read:** `list_tasks`, `get_task`, `list_subtasks`, `list_task_tags`
**Tasks - write:** `create_task`, `update_task` (partial merge), `delete_task`, `update_task_status`, `bind_task_tag`, `unbind_task_tag`
**Tasks - batch:** `batch_complete_tasks`, `batch_delete_tasks`, `batch_migrate_tasks`
**Lists:** `create_list`, `update_list`, `delete_list`, `get_list`, `list_lists`
**Tags:** `create_tag`, `update_tag`, `delete_tag`, `get_tag`, `list_tags`

Each tool's `inputSchema` is a JSON Schema object; tool results are JSON-serialized domain objects wrapped in a `text` content item. `update_task`/`update_list`/`update_tag` only change provided fields.

## Example session

```jsonc
// 1. initialize
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"demo","version":"1"}}}
// <- {"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18","capabilities":{"tools":{}},"serverInfo":{"name":"flow-status","version":"0.0.1-SNAPSHOT"}}}

// 2. create a task
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"create_task","arguments":{"title":"写周报","priority":3}}}
// <- {"jsonrpc":"2.0","id":2,"result":{"content":[{"type":"text","text":"{\"id\":12,\"title\":\"写周报\",...}"}],"isError":false}}
```

## Claude Desktop config

Configure a Streamable HTTP server pointing at the endpoint, sending the JWT as a header:

```json
{
  "mcpServers": {
    "flow-status": {
      "url": "http://localhost:8083/mcp",
      "headers": { "Authorization": "Bearer <your-jwt>" }
    }
  }
}
```

(The exact `headers` field name varies by client; some clients call it `customHeaders` or require a header-provider. Replace `<your-jwt>` with a token from `POST /api/auth/login`, or - recommended for long-lived clients - a PAT `fs_...` from `POST /api/tokens`.)

## Claude Code skill

For Claude Code specifically, install the **flow-status skill** instead of hand-configuring headers - it wraps the same `/mcp` endpoint with a PAT and exposes all 23 tools. One-click:

```
curl -fsSL https://raw.githubusercontent.com/Macroldj/flow-status/main/.claude/skills/flow-status/install.sh | bash
```

Or via the plugin marketplace: `/plugin marketplace add Macroldj/flow-status` then `/plugin install flow-status`. Full setup (PAT, config, troubleshooting): `.claude/skills/flow-status/README.md`.


```yaml
  - job_name: "flow-status-app"
    # 抓取间隔，可根据需求调整
    scrape_interval: 15s
    # 指标路径，固定为 actuator/prometheus
    metrics_path: "/actuator/prometheus"
    # 目标实例地址
    
    static_configs:
      - targets: ["192.168.1.4:8083"]
        labels:
          env: "prod"
          service: "flow-status"
          
      - targets: ["192.168.1.9:8083"]
        labels:
          env: "dev"
          service: "flow-status"
```
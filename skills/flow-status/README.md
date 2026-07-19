# flow-status skill - 接入文档

把 Claude Code（或任意 MCP 客户端）接入 [flow-status](https://github.com/macro-funs/flow-status) 的任务系统。安装这个 skill 后，配置你自己的 **Personal Access Token (PAT)**，就能在 Claude Code 里查看 / 创建 / 完成 / 删除任务、清单和标签。

- 协议：MCP `2025-06-18`，JSON-RPC 2.0，Streamable HTTP，端点 `POST <base>/mcp`。
- 认证：`Authorization: Bearer fs_...`（PAT，长期有效）。每个操作只作用于 PAT 所属用户的数据。
- 端口：nginx 前端默认 `8083`（`/mcp` 反代到后端 `8082`）。本地直连后端用 `8082`。下文默认 `8083`。

---

## 1. 获取 Personal Access Token (PAT)

PAT 是一个 `fs_` 开头的长字符串，创建时**只显示一次**，请立刻保存。

**方式 A - 前端「MCP接入」页面（推荐）：**
1. 登录 flow-status 前端。
2. 进入 **MCP接入** 页面（侧边栏 / `/mcp` 路由）。
3. 点击「创建 Token」，给个名字（如 `claude-code`），复制出现的 `fs_...`。

**方式 B - 直接调 API（需要一个登录 JWT）：**
```bash
# 1) 登录拿 JWT
JWT=$(curl -fsS -X POST http://localhost:8083/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"your-username","password":"your-password"}' | jq -r '.data.token')

# 2) 用 JWT 创建 PAT（明文只返回这一次）
curl -fsS -X POST http://localhost:8083/api/tokens \
  -H "Authorization: Bearer $JWT" -H 'Content-Type: application/json' \
  -d '{"name":"claude-code"}' | jq -r '.data.token'   # -> fs_...
```

其它：列出 `GET /api/tokens`、吊销 `DELETE /api/tokens/{id}`（都需要 JWT）。

---

## 2. 安装（三选一）

### 方式 1 - 一键脚本（curl，推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/macro-funs/flow-status/main/skills/flow-status/install.sh | bash
```

脚本会把 skill 装进 `~/.claude/skills/flow-status/`，创建配置文件模板 `~/.config/flow-status-mcp/env`，并尝试 `mcp.sh check` 验证。
- 在有 TTY 的终端里，会交互式询问 PAT 和 Base URL。
- 通过管道执行（无 TTY）时只生成模板，请手动编辑填入 PAT（见第 3 节）。

> 安全提示：先看一眼脚本再执行更稳妥：
> `curl -fsSL https://raw.githubusercontent.com/macro-funs/flow-status/main/skills/flow-status/install.sh | less`

### 方式 2 - Claude Code 插件市场（原生一键）

```text
/plugin marketplace add macro-funs/flow-status
/plugin install flow-status
```

装完后 skill 即生效。PAT 仍按第 3 节配置（插件版和脚本版共用同一份 `~/.config/flow-status-mcp/env`）。

### 方式 3 - 手动复制

把本目录（`skills/flow-status/`）复制到 `~/.claude/skills/flow-status/`，确保 `mcp.sh` 可执行：
```bash
mkdir -p ~/.claude/skills
cp -r skills/flow-status ~/.claude/skills/
chmod +x ~/.claude/skills/flow-status/mcp.sh
```

---

## 3. 配置

编辑 `~/.config/flow-status-mcp/env`（脚本/插件都会读这个文件）：
```
FLOW_STATUS_MCP_TOKEN=fs_你的token
FLOW_STATUS_BASE_URL=http://your-host:8083
```

或者直接 export 环境变量（env 变量优先于配置文件）：
```bash
export FLOW_STATUS_MCP_TOKEN=fs_...
export FLOW_STATUS_BASE_URL=http://your-host:8083
```

`FLOW_STATUS_BASE_URL` 默认 `http://localhost:8083`，可换成你部署的地址 / 域名。

---

## 4. 验证

```bash
bash ~/.claude/skills/flow-status/mcp.sh check
# OK (23 tools) @ http://localhost:8083
```

看到 `OK (23 tools)` 即接入成功。报错见第 7 节排查。

---

## 5. 在 Claude Code 里使用

装好 skill、配好 PAT 后，直接对 Claude 说即可（skill 会自动触发）：
- 「我的 flow-status 里有哪些任务？」-> 调 `list_tasks` 汇总。
- 「加个任务：写周报，高优先级」-> `create_task '{"title":"写周报","priority":4}'`，告诉你新建的 id。
- 「把任务 12 标记完成」-> `update_task_status '{"id":12,"status":"completed"}'`。
- 「把任务 3 和 7 移到 Work 清单」-> 先 `list_lists` 拿清单 id，再 `batch_migrate_tasks '{"ids":[3,7],"listId":<id>}'`。

直接调 helper 也行：
```bash
bash ~/.claude/skills/flow-status/mcp.sh list
bash ~/.claude/skills/flow-status/mcp.sh create_task '{"title":"测试接入","priority":3}'
```

---

## 6. 接入其它 MCP 客户端（Claude Desktop / Cursor）

skill 只是 Claude Code 的封装；底层就是一个带 PAT 头的 MCP 端点，任何 MCP 客户端都能直连。

**Claude Desktop**（`~/Library/Application Support/Claude/claude_desktop_config.json` 或对应平台路径）：
```json
{
  "mcpServers": {
    "flow-status": {
      "url": "http://your-host:8083/mcp",
      "headers": { "Authorization": "Bearer fs_..." }
    }
  }
}
```

**Cursor**（`.cursor/mcp.json`，项目根或全局）：
```json
{
  "mcpServers": {
    "flow-status": {
      "url": "http://your-host:8083/mcp",
      "headers": { "Authorization": "Bearer fs_..." }
    }
  }
}
```

> 不同客户端的 `headers` 字段名可能叫 `customHeaders` 或需要 header-provider，按客户端文档调整。把 `fs_...` 换成你的 PAT。

---

## 7. 故障排查 (Troubleshooting)

| 现象 | 原因 / 处理 |
|---|---|
| `MCP request failed (HTTP error ...)` + 401 | PAT 已吊销或填错。回 MCP接入 页面重建，更新 `FLOW_STATUS_MCP_TOKEN`。 |
| `MCP request failed` + 连接被拒 | Base URL / 端口不对。直连后端用 `8082`，走 nginx 用 `8083`；确认 host 可达。 |
| `jq: command not found` / `curl: command not found` | 装依赖：macOS `brew install jq curl`；Debian `sudo apt-get install jq curl`。 |
| `rpc error -32601: ...` | 调了不存在的工具。先 `mcp.sh list` 看 23 个工具名。 |
| `tool error: ...` | 工具执行失败（如 id 不存在、终态冲突）。看消息，改参数重试。 |
| Claude Code 里 skill 没生效 | 装在 `~/.claude/skills/flow-status/` 后重启当前会话；`/plugin install` 后同理。 |

---

## 8. 安全说明

- PAT 是凭据，等同密码。配置文件建议 `chmod 600 ~/.config/flow-status-mcp/env`（installer 会自动设）。
- 不要把 PAT 提交进 git，也不要贴到公开聊天。
- 不再使用时，回 MCP接入 页面吊销，或 `DELETE /api/tokens/{id}`（需 JWT）。
- 本 skill 只调用你配置的 flow-status 实例，不会把数据发到任何第三方。

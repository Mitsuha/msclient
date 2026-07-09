# 初始化逻辑

MirrorStages 桌面端对本机 AI CLI 工具（Codex、Claude Code）的"初始化"，指把
MirrorStages 的授权凭据和代理地址写入该工具的本地配置，使其通过 MirrorStages
账号与代理运行。

## 模块结构

初始化逻辑封装在 `lib/app/initialization/`，与 UI 和 `AppService` 解耦：

```
lib/app/initialization/
├── tool_initializer.dart    InitStep / InitStepStatus / ToolInitializer
├── codex_initializer.dart   Codex 的步骤定义（codexInitializer 工厂）
└── claude_initializer.dart  Claude Code 的步骤定义（claudeInitializer 工厂）
```

- **InitStep**：一个可独立执行的初始化步骤，含 `check()`（只读检测）和
  `apply()`（写入/修复）两个闭包。
- **ToolInitializer**：按顺序驱动一组步骤：
  - `initialize({backupOriginals})` — 依次无条件执行每个步骤的 `apply()`
    （首页"初始化 / 更换计费"按钮）；
  - `checkSteps()` — 只读检测所有步骤，结果进入 `AppSnapshot`
    （`codexInitSteps` / `claudeInitSteps`），设置页据此逐条展示；
  - `applyStep(id)` — 单独修复某一步（设置页"修复"按钮）。
- 文件读写等本机操作在 `lib/system/` 的 `CodexConfigManager` /
  `ClaudeConfigManager` 中，以步骤为粒度暴露 check/write 方法对。

### old_config 备份时机

`old_config/` 备份**只在首页首次初始化时创建**，此外任何路径都不创建：

- 备份不再散落在各 write 方法里，而是集中在各 Manager 的 `preserveOriginals()`，
  仅由 `ToolInitializer.initialize(backupOriginals: true)` 在写入前调用一次。
- `AppService` 只有在对应工具**当前未初始化**（即真正的首次初始化）时才传
  `backupOriginals: true`；工具已初始化时的"更换计费"传 `false`。
- 单步修复（`applyStep`）、切换代理节点（`writeProxyEnv` / `writeProxySettings`）
  直接调用 write 方法，均不备份。
- 同一文件至多备份一次，因此即使首次初始化也不会覆盖已存在的备份。

调用入口（`AppService`）：

| 场景 | 调用 | 是否创建 old_config |
|------|------|------|
| 首页首次初始化 | `initializeLocalProxyEnv` / `initializeClaude` → `initialize(backupOriginals: true)` | 是 |
| 首页更换计费（已初始化） | 同上，`initialize(backupOriginals: false)` | 否 |
| 设置页单步修复 | `applyCodexInitStep` / `applyClaudeInitStep` → `ToolInitializer.applyStep(id)`（沿用当前凭据的 user_pack_id 计费） | 否 |
| 快照刷新时的状态检测 | `ToolInitializer.checkSteps()` + 各 Manager 的 `readStatus()` | 否 |
| 设置页切换代理节点 | 保存偏好后，对**已初始化**的工具直接调用 `writeProxyEnv` / `writeProxySettings` 立即写入 | 否 |

## Codex

配置目录：`~/.codex`。

### 初始化检测（三条必须同时满足）

1. `~/.codex/.env` 中存在非空的 `http_proxy` 与 `https_proxy`；
2. `~/.codex/auth.json` 可正常解析为 JSON，且 `tokens.access_token`（JWT）的
   payload 中包含 `account_sharing_member_id` 与 `user_id`；
3. `~/.codex/config.toml` 不存在，或其中不存在 `provider` 字段 / `provider`
   字段为空。

任一条不满足即视为**未初始化**；解析失败一律按未初始化处理，不作为错误上抛。
账户展示信息（邮箱、用户名、套餐）优先取 `tokens.id_token` 的 payload，取不到
时回退 `access_token` payload；计费套餐 `user_pack_id` 取自 `access_token`。

### 初始化步骤（按顺序）

| # | 步骤 id | 检测（check） | 写入（apply） |
|---|---------|---------------|---------------|
| 1 | `codex.proxy_env` | `.env` 含非空 `http_proxy` / `https_proxy` | 向 `.env` 合并写入两个代理项（保留其他条目） |
| 2 | `codex.auth` | `auth.json` 的 access_token 含上述两个 claim | 调用 `POST /user/codex-auth` 获取凭据并覆盖 `auth.json` |
| 3 | `codex.provider_config` | `config.toml` 不存在或无非空 `provider` | 删除 `config.toml`，使 Codex 回落到 MirrorStages provider |

备份目录：`~/.codex/old_config/`（`auth.json`、`config.toml`）。首次初始化前由
`preserveOriginals()` 一次性把原件移入，单步修复不备份（见上文"old_config 备份时机"）。

## Claude Code

配置目录：`~/.claude`。凭据存储位置分平台：macOS 为登录钥匙串条目
`Claude Code-credentials`，Windows/Linux 为 `~/.claude/.credentials.json`。

### 初始化检测

凭据 JSON 可解析，且 `claudeAiOauth.accessToken` 为
`sk-ant-oat01-<content>-…` 形式，`<content>` 经 base64url 解码后为
`user_id|account_sharing_member_id|user_pack_id|account_email` 四段。
能解析出账户即视为已初始化，任何失败按未初始化处理。

### 初始化步骤（按顺序）

| # | 步骤 id | 检测（check） | 写入（apply） |
|---|---------|---------------|---------------|
| 1 | `claude.credentials` | 凭据能解码出 MirrorStages 账户 | 调用 `POST /user/claude-auth` 获取凭据并写入（macOS 写钥匙串，其他平台写文件） |
| 2 | `claude.proxy_settings` | `settings.json` 的 `env` 含非空 `HTTPS_PROXY` / `HTTP_PROXY` | 合并写入两个代理项（保留用户其他设置；`theme` / `model` 仅在缺失时补默认值） |

备份目录：`~/.claude/old_config/`（`settings.json`、`.credentials.json`；
macOS 的钥匙串条目也快照为 `.credentials.json`）。首次初始化前由
`preserveOriginals()` 一次性快照（凭据在凭据步骤写入之前快照），单步修复不备份。

## 代理节点切换

设置页的"代理节点"以分段控件展示服务器下发的节点（只显示名称）。切换后：

1. 选中的 url 持久化到本地偏好（`ProxyPreferenceStore`）；
2. 立即检测 Codex 与 Claude Code 哪个已初始化，已初始化的直接写入其配置
   （Codex 更新 `.env`，Claude Code 更新 `settings.json`），无需重新初始化；
3. 未初始化的工具不受影响，之后初始化时会使用新选中的节点；
4. 正在运行的 CLI 需重启后新代理才生效。

## 恢复原始配置

设置页"恢复原始配置"把 `old_config/` 中的备份移回原位（备份中缺失的文件说明
初始化前并不存在，会直接删除 MirrorStages 写入的现行文件），随后清空备份目录。
恢复后工具回到初始化之前的状态，需重新初始化才能继续通过 MirrorStages 运行。

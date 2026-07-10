# 本地代理（go-gost）

MirrorStages 桌面端内置一个本地 [go-gost](https://github.com/go-gost/gost) 进程作为
本机代理。CLI 工具（Codex、Claude Code）的 `http_proxy` 一律指向这个本地端口，由
gost 通过一条**转发链（chain）**代理到当前所选的远程 MirrorStages 节点。切换节点时
只改这条链，工具配置本身不动。

只有**名单内的域名**才走转发链到远程节点，其余流量由 gost 直连（分流 / split
tunnel），避免把无关流量也送去付费节点：

```
                                     ┌─ 命中名单 ─▶ chain ─▶ 远程 MirrorStages 节点
CLI 工具 ──http──▶ 127.0.0.1:18610 ──┤
          (gostLocalProxyUrl，恒定)   └─ 其余域名 ─▶ 直连（不走链）
```

名单（`GostController._proxyDomains`，含各自子域）：`chatgpt.com`、`anthropic.com`、
`openai.com`、`claude.com`、`claude.ai`。

## 二进制的获取与存放

- gost **不随安装包分发**，而是在**首次启动时按平台下载**：
  - `gost_darwin_amd64` / `gost_darwin_arm64` / `gost_linux_amd64` /
    `gost_windows_amd64.exe`（从 `AppConfig.gostDownloadBaseUrl` 拉取，macOS 依
    运行架构从 `Platform.version` 选择 amd64/arm64）。
- 下载到 `~/.mstages/bin/gost`（Windows 为 `gost.exe`），运行日志写在
  `~/.mstages/gost.log`。选用**用户主目录**是因为 macOS 的 `.app` 包已签名、只读，
  无法把二进制写进包内。
- 下载先落到 `*.download` 临时文件，校验大小后原子重命名，Unix 上再 `chmod +x`。

## 生命周期

| 时机 | 动作 |
|------|------|
| 启动（`AppViewModel.bootstrap`） | `unawaited(startGost())`：后台下载/拉起 gost，不阻塞登录界面 |
| 快照刷新（`loadSnapshot`） | best-effort 把 chain 对齐到当前所选节点（gost 未就绪或未变化时自动跳过）；同时 `isHealthy()` 探测 gost 是否在运行，写入 `AppSnapshot.isProxyRunning` |
| 最小化 / 关窗（`onWindowClose`、⌘W） | 只隐藏到托盘/Dock（`setPreventClose(true)`），gost 作为独立进程**继续后台运行** |
| 切换节点（`selectProxy`） | 保存偏好 → `applyProxyNode(远程 url)` 更新 chain；已初始化的工具重新指向恒定的本地地址（迁移旧的远程写入） |
| 退出 | 停掉 gost 再终止进程。两条路径都覆盖：托盘「退出」走 `AppViewModel.shutdown` → `stopGost()`；macOS ⌘Q / Dock 退出 / 应用菜单退出走 `AppLifecycleListener.onExitRequested` → 同样 `shutdown()` 后返回 `AppExitResponse.exit` |

若上一次会话残留了仍在监听的 gost（如进程被强杀、未走上述任一退出路径），`start()`
会先 `ping` 控制 API，探测到就**复用**它，既避免端口冲突也避免起第二个。

注意这种被收养的 gost 往往在**第一次配置下发时就会死掉**：它的 stdout/stderr 管道随
旧父进程一起断了，下发配置触发它写日志 → EPIPE → Go 运行时默认以 SIGPIPE 退出，请求
端表现为 `Connection closed before full header was received` / `Connection reset by
peer`。为此 `GostController._applyNow` 做了兜底：下发失败后若探测到 API 已掉线、且当
前进程并不持有自己拉起的 gost，就改为**自行拉起一个新 gost 并从头重发整套配置**
（bypass→chain→service）。该兜底同样覆盖本会话拉起的 gost 中途死亡的情形。此外所有
配置下发经由一个内部队列**串行化**，避免并发调用在 `GostApiClient` 的存在性检查上竞
争、对同名对象重复 POST。

## 与工具卡片运行状态联动

Codex / Claude Code 的请求全部经本地 gost 转发，因此「正在运行」必须以 gost 真的在跑
为前提。`loadSnapshot` 每次都 `GostController.isHealthy()`（即 `ping` 控制 API）刷新
`AppSnapshot.isProxyRunning`，卡片据此显示三态：

- **未初始化**（灰）：工具尚未初始化。
- **正在运行**（绿）：工具已初始化 **且** gost 健康。
- **代理未运行**（红）：工具已初始化，但 gost 没起来 —— 此时请求无法转发。

## 模块结构

分层遵循 `app → { data, system, core }`：

```
lib/system/gost_binary.dart    选平台资产、首次下载、chmod（本机 IO）
lib/system/gost_process.dart   Process.start / kill，输出转存日志
lib/data/api/gost_api.dart     gost 控制 API 客户端（HTTP，前缀是 /config 不是 /api/config）
lib/app/gost/gost_controller.dart  编排三者：下载→拉起→配置 chain/service
```

`AppConfig` 里集中了端口与地址：`gostProxyPort`(18610)、`gostApiPort`(18611)、
`gostLocalProxyUrl`、`gostApiBaseUri`、`gostDownloadBaseUrl`。

## 控制 API 要点

- 变更前缀是 **`/config`**（非 `/api/config`）。
- `POST /config/<kind>` **新建**具名对象，`PUT /config/<kind>/<name>` **更新**已有；
  建已存在的名字或改不存在的名字都会报错，故 `GostApiClient` 先读 `GET /config`
  判断存在与否再决定 POST/PUT。
- 我们维护三个对象：bypass `mstages-proxy`、chain `mstages`、service
  `mstages-local`，且**按此顺序**下发（chain 按名字引用 bypass，service 引用
  chain，被引用者必须先存在）：
  - **bypass `mstages-proxy`**：`whitelist: true`（反向模式）+ 名单域名的
    `matchers`（每个域名附带 `*.` 通配）。反向模式下,"命中"表示**不在**名单——
    这类目标会被旁路掉。
  - **chain `mstages`**：单跳到远程节点（`https` 节点用 `tls` dialer + `http`
    connector）；节点上挂 `bypasses: ["mstages-proxy"]`，于是非名单目标在选路时
    被旁路 → 该跳无可用节点 → 直连；名单目标正常经节点转发。
  - **service `mstages-local`**：本地 http 代理，`handler.chain` 指向 `mstages`。
- 分流方向已对真实 gost 二进制验证：名单外 `example.com` 直连（200），名单内
  `api.openai.com` 经远程节点（未授权时 401）。注意 bypass 是在**服务创建时**编译进
  路由的：给一个"创建时链上还没 bypass"的运行中 service 事后补挂 bypass 不会生效——
  但每次全新启动都按 bypass→chain→service 顺序新建，故正常路径无此问题；仅切换节点时
  的 chain PUT 会热更新（改节点地址即时生效）。

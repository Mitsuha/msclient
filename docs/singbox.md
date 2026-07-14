# 本地代理（sing-box）

MirrorStages 桌面端内置一个本地 [sing-box](https://github.com/SagerNet/sing-box) 进程
作为本机代理。CLI 工具（Codex、Claude Code）的 `http_proxy` 一律指向这个本地端口，由
sing-box 通过一个 **selector** 代理到当前所选的远程 MirrorStages 节点。sing-box 由
**启动时读取的配置文件**驱动（而非运行时增量下发）：启动时按服务器返回的节点列表生成
「每个节点一个 http outbound + 一个 selector + 一个 direct」，切换节点时经 Clash API
切换 selector，工具配置本身不动。

只有**名单内的域名**才走 selector 到远程节点，其余流量直连（分流 / split tunnel），
避免把无关流量也送去付费节点：

```
                                     ┌─ 命中名单 ─▶ selector ─▶ 远程 MirrorStages 节点
CLI 工具 ──http──▶ 127.0.0.1:18610 ──┤
          (singboxLocalProxyUrl，恒定) └─ 其余域名 ─▶ direct（route.final）
```

名单（`SingboxConfigBuilder.proxyDomains`）：`chatgpt.com`、`anthropic.com`、
`openai.com`、`claude.com`、`claude.ai`、`api.anthropic.com`、`platform.claude.com`。
sing-box 的 `domain_suffix` 已覆盖各自子域。

## 二进制的获取与存放

- sing-box 需为标准 `with_clash_api` release（否则 `experimental.clash_api` 不存在，
  `_waitForApi` 会一直超时）。建议在托管镜像里固定一个版本（≥1.11.x）。
- **下载逻辑三端统一**（缺失即下载）：`sing-box-darwin`（macOS 单一通用二进制，无 arch
  后缀）/ `sing-box-linux` / `sing-box.exe`，从 `AppConfig.singboxDownloadBaseUrl` 拉取。
- 路径上**唯一的平台特判**在 `SingboxBinary.path()`：Windows 为**可执行文件同级**的
  `sing-box.exe`（正常由 MSI 打包，无需下载；缺失时才补下）；macOS/Linux 为
  `~/.mstages/bin/sing-box`。选用**用户主目录**是因为 macOS 的 `.app` 包已签名、只读，
  无法把二进制写进包内。
- 下载先落到 `*.download` 临时文件，校验大小（>1MB）后原子重命名，Unix 上再 `chmod +x`。
- 生成的配置文件写在 `~/.mstages/sing-box.json`，sing-box 子进程 stdout/stderr 转存在
  `~/.mstages/sing-box.log`。应用侧诊断日志写入 `~/.mstages/logs/app-YYYY-MM-DD.log`，
  按本地日期轮转并保留最近 7 天。诊断事件包括 `singbox.download.started`、
  `singbox.download.http_failed`、`singbox.download.write_failed`、
  `singbox.start.failed`、`singbox.select.failed`。

## 生命周期

单一入口 `SingboxController.apply(proxies, {selectedUrl})` 覆盖首启、列表刷新、切节点
三种情形；内部用一个队列串行化，避免 bootstrap 与 30s 刷新竞争。

| 时机 | 动作 |
|------|------|
| 启动（`AppViewModel.bootstrap`） | `unawaited(startProxy())`：后台拉取节点列表 → `apply(...)` 下载/拉起 sing-box，不阻塞登录界面 |
| 快照刷新（`loadSnapshot`） | best-effort `apply(当前列表, 所选)`：节点集合变则重写配置并重启，仅选择变则切 selector，未变则 no-op；同时 `isHealthy()` 探测 sing-box 是否在运行，写入 `AppSnapshot.isProxyRunning` |
| 最小化 / 关窗（`onWindowClose`、⌘W） | 只隐藏到托盘/Dock（`setPreventClose(true)`），sing-box 作为独立进程**继续后台运行** |
| 切换节点（`selectProxy`） | 保存偏好 → `apply(缓存列表, selectedUrl: url)`：经 Clash API 切 selector，并把 `selector.default` 重新落盘（下次启动生效）；已初始化的工具重新指向恒定的本地地址（迁移旧的远程写入） |
| 退出 | 停掉 sing-box 再终止进程。两条路径都覆盖：托盘「退出」走 `AppViewModel.shutdown` → `stopProxy()`；macOS ⌘Q / Dock 退出 / 应用菜单退出走 `AppLifecycleListener.onExitRequested` → 同样 `shutdown()` 后返回 `AppExitResponse.exit` |

因为配置是文件化的、每次启动都重新生成，且每个真实退出路径都干净 `stop()`，不再需要
gost 时代「收养孤儿进程并重推配置」的兜底逻辑。硬崩溃残留的孤儿进程会在下次启动待 OS
释放端口后自愈。

## 重启 vs 仅切换

Clash API 能切换 selector 的目标，但**无法增删 outbound**。因此控制器用一个
`outboundSignature`（每节点 `tag|server|port|tls` 的有序列表）判定：

- **节点集合变了**（签名不同）→ 重写配置文件 + `stop()`/`start()` 重启。
- **仅所选节点变了**（签名相同、default 不同）→ Clash API `PUT /proxies/default-selector`
  即时切换，并重新生成整份配置文件持久化 `selector.default`。
- 都没变 → no-op。

## 与工具卡片运行状态联动

Codex / Claude Code 的请求全部经本地 sing-box 转发，因此「正在运行」必须以 sing-box
真的在跑为前提。`loadSnapshot` 每次都 `SingboxController.isHealthy()`（即 `GET /version`
探测 Clash API）刷新 `AppSnapshot.isProxyRunning`，卡片据此显示三态：

- **未初始化**（灰）：工具尚未初始化。
- **正在运行**（绿）：工具已初始化 **且** sing-box 健康。
- **代理未运行**（红）：工具已初始化，但 sing-box 没起来 —— 此时请求无法转发（健康前的
  「连接中」也复用此加载态呈现）。

## 模块结构

分层遵循 `app → { data, system, core }`：

```
lib/system/singbox_binary.dart          选平台资产、缺失即下载、chmod（本机 IO）
lib/system/singbox_process.dart         Process.start('run','-c',config) / kill，输出转存日志
lib/core/logging/app_logger.dart        通用结构化日志接口
lib/system/file_app_logger.dart         按天写入应用日志、保留最近 7 天
lib/data/api/singbox_clash_api.dart     Clash API 客户端（GET /version、PUT /proxies/<name>）
lib/app/singbox/singbox_config_builder.dart  纯函数：节点列表 → 配置 JSON（+ default tag、签名）
lib/app/singbox/singbox_controller.dart      编排：下载→写配置→拉起/重启/切换
```

`AppConfig` 里集中了端口与地址：`singboxProxyPort`(18610)、`singboxApiPort`(18611)、
`singboxLocalProxyUrl`、`singboxClashApiBaseUri`、`singboxDownloadBaseUrl`、
`singboxClashSecret`、`singboxConfigFileName`。

## 配置与 Clash API 要点

- 生成的配置（`SingboxConfigBuilder.build`）：
  - **inbound**：一个 `http` 类型，`tag: default-http`，监听 `127.0.0.1:18610`。
  - **outbounds**：每节点一个 `http`（`tag` 取自节点名并去重，`server`/`server_port`
    从 url 解析，`tls.enabled` 由 scheme 是否 `https` 决定）；一个 `selector`
    （`tag: default-selector`，`default` = 所选节点，缺省取列表首个）；一个 `direct`。
  - **route**：`rules` 里名单域名 `domain_suffix` → `default-selector`，`final: direct`。
- Clash API 绑定回环、带常量 secret（`Authorization: Bearer default-secret`）：
  - `GET /version` 作健康探测（`_waitForApi`、`isHealthy`）。
  - `PUT /proxies/default-selector`，body `{"name": "<节点 tag>"}` 切换所选节点
    （成功返回 204）。
- 节点列表为空时，`AppService._proxiesOrFallback` 注入一个 `AppConfig.proxyUrl` 合成节点，
  保证配置至少有一个 outbound。

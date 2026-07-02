# MirrorStages Desktop

MirrorStages 桌面控制面板（Flutter，Cupertino 风格）。登录 MirrorStages 账号后：

- 展示账户余额、套餐订阅与运行状态；
- 一键初始化本机 Codex 环境：写入 `~/.codex/auth.json`、代理环境变量
  `~/.codex/.env`，并将用户原有的 `auth.json` / `config.toml` 备份到
  `~/.codex/old_config/`（设置页可随时恢复）；
- 安装并校验 MirrorStages 根证书（macOS 钥匙串 / Windows 证书存储）；
- 检测与 CC-Switch 等冲突进程。

支持平台：macOS、Windows（Linux 可编译，证书安装不支持）。

## 运行与测试

```sh
flutter run -d macos      # 或 -d windows
flutter analyze lib/ test/
flutter test
```

注意：若 shell 设置了全局 `http_proxy`/`https_proxy`（如指向 127.0.0.1:9000
的本地代理），Flutter 测试进程与本地 test server 的回环连接会被代理劫持，
所有用例在 loading 阶段即失败（`HttpException: Connection closed before full
header was received`）。此时用 `no_proxy='*' flutter test` 运行。

## 目录结构

```
lib/
├── main.dart      仅窗口引导
├── app/           装配与共享状态：MirrorStagesApp、AppConfig、AppViewModel、
│   │              AppService（门面）；app/models/ 是 UI 聚合模型
├── core/          通用无业务代码：ApiClient、json/jwt/格式化工具
├── data/          远端 API、DTO、SessionStore
├── system/        本机集成：home 目录、env 文件、冲突进程检测、根证书、
│                  Codex 配置读写与备份恢复
├── ui/widgets/    通用设计组件（按钮、卡片等）
└── features/      按内容划分的界面：shell/（主框架）、dashboard/、
                   settings/、auth/
```

依赖方向：`features → { app, data, system, ui, core }`，`app → { data, system,
core }`，其余各层只依赖 `core`。详细约定见 [AGENT.md](AGENT.md)。

## 原生侧

macOS 通过 MethodChannel `com.mirrorstages.desktop/process_inspector`
（`macos/Runner/MainFlutterWindow.swift`）提供冲突进程扫描和用户 home 目录；
Windows/Linux 由 Dart 侧调用 `tasklist.exe` / `ps` 兜底。根证书资产位于
`assets/ca/mirrorstages-root-ca.cer`。

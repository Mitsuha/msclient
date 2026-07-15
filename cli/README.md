# mstages

MirrorStages 的命令行版本 —— desktop 端的 CLI 对应实现。登录鉴权、管理本地
sing-box 代理，并以 `mcodex` / `mclaude` 身份初始化并直接拉起 `codex` / `claude`。

## 安装

```sh
make install          # 编译并安装到 $HOME/.local/bin，创建 mcodex/mclaude 软链接
# 或自定义前缀：
make install PREFIX=/usr/local
```

`mcodex` 与 `mclaude` 是指向同一 `mstages` 二进制的软链接；程序通过 `os.Args[0]`
的 basename 判定以哪种身份运行。确保 `$HOME/.local/bin` 在 `PATH` 中。

## 命令

| 命令 | 说明 |
|------|------|
| `mstages auth login` | TUI 表单输入账号（邮箱/手机号）与密码，登录并写入 `~/.mstages/credentials.json`（0600） |
| `mstages switch node` | 拉取服务端节点列表，TUI 选择并持久化到 `~/.mstages/config.json`；若 sing-box 正在运行则通过 Clash API 即时切换 |
| `mcodex [args...]` | 初始化并启动 `codex`（透传标准输入输出） |
| `mclaude [args...]` | 初始化并启动 `claude`（透传标准输入输出） |

## `mcodex` / `mclaude` 运行流程

每次运行都会完整执行一遍，退出时恢复原状：

1. 读取 `~/.mstages/credentials.json`（未登录则提示先 `mstages auth login`）。
2. 检查 `~/.mstages/bin/sing-box`，缺失则下载并显示进度条。
3. 检测并（未信任时）自动安装内置的 MirrorStages 根证书。
4. 由选中节点生成 sing-box 配置并启动本地代理（`127.0.0.1:18610`）。
5. 备份现有工具配置到 `~/.codex|~/.claude` 下的 `old_configs/`，再写入 MirrorStages
   凭据与代理设置。
6. 以透传的 stdin/stdout/stderr 启动 `codex` / `claude`。
7. 子进程退出（或收到信号）后恢复 `old_configs/` 并停止 sing-box。

## 数据目录

```
~/.mstages/
├── credentials.json         # 登录会话 {token, user}（0600）
├── config.json              # {selected_node_url}
├── bin/sing-box             # 按需下载的代理内核
├── sing-box.json            # 生成的运行配置
├── sing-box.log             # 代理运行日志
└── mirrorstages-root-ca.cer # 从二进制释放的根证书
```

## 开发

```sh
make build    # 编译到 bin/mstages
make test     # 运行测试（已设 NO_PROXY 以便回环测试）
make vet
make fmt
```

工程布局：`cmd/mstages` 入口分派；`internal/{app,models,api,auth,config,singbox,cert,tools,cli,tui}`
按职责分层，行为对齐 Flutter desktop 端（见 `../lib`、`../docs`）。

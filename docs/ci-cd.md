# CI/CD 部署手册（GitHub Actions + Shorebird）

本项目用 **GitHub Actions** 做跨平台自动编译打包，用 **Shorebird** 做 release 与
后续热更新（patch）。macOS 上无法本地编译 Windows/Linux，交给 CI 的原生 runner 解决。

## 一、两个工作流的职责

| 文件 | 触发 | 做什么 | 是否用 Shorebird |
|---|---|---|---|
| `.github/workflows/ci.yml` | 每次 push / PR 到 `master` | 三端原生 `flutter build` + `analyze` + `test`，只验证能编译能过测 | 否（不消耗 release 额度） |
| `.github/workflows/release.yml` | 推送 `v*` tag 或手动 | `shorebird release` 三端 → 打成安装包 → 发到 GitHub Release | 是 |

> 为什么分两个：Shorebird 每个版本号只能 release 一次，不适合“每次提交都 release”。
> 所以日常提交走 `ci.yml`（只编译验证），正式发版才打 tag 走 `release.yml`。

## 二、产物清单

`release.yml` 会在 GitHub Release 里附带：

- **Windows**：`...-windows-x64-setup.exe`（Inno Setup 安装程序）、`...-windows-x64.zip`（免安装）
- **Linux**：`...-x86_64.AppImage`、`mirrorstages-desktop_<ver>_amd64.deb`、`...-linux-x64.tar.gz`
- **macOS**：`...-macos.dmg`

## 三、一次性准备（本地，只做一次）

### 1. 登录并初始化 Shorebird

当前项目还**没有** `shorebird.yaml`，需要先初始化（会在 Shorebird 服务端注册这个 app，
生成带 `app_id` 的 `shorebird.yaml`，并自动把它加入 `pubspec.yaml` 的 assets）：

```sh
shorebird login          # 浏览器登录 Shorebird 账号
shorebird init           # 生成 shorebird.yaml，写入 app_id
git add shorebird.yaml pubspec.yaml
git commit -m "chore: init shorebird"
```

> `shorebird.yaml` 必须提交进仓库，CI 才能用它做 release。

### 2. 生成 CI 用的 API Key

`shorebird login:ci` 已废弃，改用控制台 API Key：

1. 打开 https://console.shorebird.dev → **Account → API Keys → Create API Key**
2. 名称填 `GitHub Actions`，选好有效期和权限，点创建
3. **立刻复制**那串 `sb_api_...`（只显示这一次，关掉就再也看不到）

### 3. 建一个 GitHub 仓库专门跑 CI

你的 `origin` 是 `https://cnb.cool/mirrorstages/desktop`，GitHub Actions 跑不了。
再加一个 GitHub 远程即可，两边并存、互不影响：

```sh
# 方式 A：已装 gh CLI
gh repo create mirrorstages/desktop --private --source=. --remote=github --push

# 方式 B：先在 github.com 网页手动建空仓库，再：
git remote add github https://github.com/<你的账号>/<仓库名>.git
git push github master
```

以后要触发 CI，就把代码推到 `github` 这个远程（`git push github master`）。

### 4. 在 GitHub 仓库配置 Secret

GitHub 仓库 → **Settings → Secrets and variables → Actions → New repository secret**：

- Name：`SHOREBIRD_TOKEN`
- Secret：第 2 步复制的 `sb_api_...`

这是 `release.yml` 唯一需要的密钥。CI 里 Shorebird CLI 检测到该变量会自动认证。

## 四、发布一个正式版本

```sh
# 1. 更新版本号（pubspec.yaml 的 version 字段，可选但推荐）
#    version: 1.0.1+2

# 2. 打 tag 并推到 GitHub，触发 release.yml
git tag v1.0.1
git push github v1.0.1
```

几分钟后到 GitHub 仓库的 **Releases** 页就能看到三端安装包。
也可以在 **Actions** 页用 “Run workflow” 手动触发（需手填版本号）。

> tag 名去掉 `v` 就是 Shorebird 的版本号。同一个版本号不能 release 两次，
> 每次发版记得递增。

## 五、之后的热更新（patch）

改了 Dart 代码但没动原生部分时，可以不重新发安装包，直接推补丁：

```sh
shorebird patch --platforms=windows,linux,macos --release-version=1.0.1+2
```

（也可以把它做成第三个 workflow，需要时再加。）

## 六、注意事项 / 已知限制

- **未签名**：Windows 安装包未做代码签名，首次运行会有 SmartScreen 提示；
  macOS 的 `.dmg` 未签名未公证，用户需右键“打开”或在“隐私与安全性”里放行。
  如需正式签名/公证，要额外准备证书并在 workflow 里加签名步骤。
- **Linux 兼容性**：CI 用 `ubuntu-22.04`（glibc 2.35）构建，能覆盖大多数较新发行版；
  更老的系统可能需要更低版本的构建环境。
- **托盘依赖**：Linux 运行需要 `libayatana-appindicator3-1`（deb 包已声明依赖，
  AppImage/tar 需用户自行安装）。
- **图标**：安装包图标来自 `assets/tray/app_icon.ico`，Linux/macOS 会在 CI 里转成 PNG。
  想换更精致的图标，替换该文件即可。
- **cnb.cool**：本手册只配置了 GitHub。若还想在 cnb.cool 上跑原生 CI，
  它用的是 `.cnb.yml`（与 GitHub Actions 不通用），需要另配。

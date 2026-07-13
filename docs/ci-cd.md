# CI/CD 操作手册

本项目使用 GitHub Actions 和 Shorebird 为 Windows、Linux、macOS 发布正式版本与 Dart 热更新。

## 触发规则

普通分支 push、`master` push 和 Pull Request 均不触发 GitHub Actions。只有以下两类 tag 会启动 workflow：

| 操作 | Tag 格式 | 示例 |
|---|---|---|
| Shorebird release | `v<major>.<minor>.<patch>+<build>` | `v1.2.3+45` |
| Shorebird patch | `v<目标release版本>-patch.<序号>` | `v1.2.3+45-patch.1` |

workflow 会严格校验 tag 和 `pubspec.yaml`，不能只依赖 tag 名相似。

## 一次性配置

### Shorebird API key

在 [Shorebird Console](https://console.shorebird.dev) 的 **Account → API Keys** 创建 API key，然后在 GitHub 仓库的 **Settings → Secrets and variables → Actions** 中新增：

```text
Name: SHOREBIRD_TOKEN
Value: sb_api_...
```

`SHOREBIRD_TOKEN` 是密钥，不能提交到仓库。`shorebird login:ci` 已废弃，应使用 Console 创建的 API key。详情见 [Shorebird GitHub Integration](https://docs.shorebird.dev/code-push/ci/github/)。

### 本地 pre-commit

当前 checkout 的 `.git/hooks/pre-commit` 会在每次 commit 前执行：

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze
```

hook 不修改文件，只在检查失败时阻止 commit。它只对当前 checkout 生效，也可以被 `git commit --no-verify` 绕过。GitHub Actions 不重复 format、analyze 或 test。

## 发布正式版本

先把 `pubspec.yaml` 的完整版本设置为要发布的版本：

```yaml
version: 1.2.3+45
```

然后创建并推送完全对应的 tag：

```sh
git tag v1.2.3+45
git push github v1.2.3+45
```

tag 中不能省略 `+build`，且去掉前导 `v` 后必须和 `pubspec.yaml` 完全一致。

release workflow 会用 Flutter `3.44.2` 并行执行三个 Shorebird release，然后上传以下 GitHub Actions artifacts：

- Windows：`MirrorStages-Desktop-1.2.3+45-windows-x64.msi`
- Linux：`mirrorstages-desktop_1.2.3+45_amd64.deb`
- macOS：`MirrorStages-Desktop-1.2.3+45-macos.dmg`

artifact 保留 7 天。本流程不会创建 GitHub Release，也不会生成其他安装包格式。

### MSI 版本映射

Windows Installer 只比较三段 `major.minor.build`。项目按以下规则生成 MSI ProductVersion：

```text
pubspec/Shorebird 1.2.3+45 -> MSI 1.2.45
```

major、minor 来自 pubspec；MSI 第三段使用 Flutter build number。因此：

- major、minor 不得超过 255。
- build number 不得超过 65535。
- 同一 major/minor 下，每次正式 release 的 build number 必须单调递增。

artifact 文件名和 Shorebird 版本仍使用完整的 `1.2.3+45`。

## 发布 patch

patch 只能用于 Shorebird 支持的 Dart 代码变更。不要在 patch 中加入原生代码、资源、字体或构建配置变更；这类变更必须发布新的 release。

从目标 release 对应的代码准备修复，并保持 `pubspec.yaml` 版本不变：

```yaml
version: 1.2.3+45
```

为第一个补丁创建 tag：

```sh
git tag v1.2.3+45-patch.1
git push github v1.2.3+45-patch.1
```

后续补丁依次使用 `.2`、`.3`。必须等待前一个 patch workflow 完成后再推送下一个 tag。

patch workflow 会显式指定 `--release-version=1.2.3+45`，不会使用 `latest`，并直接发布到 Shorebird `stable`。tag 推送后没有 staging 或人工审批环节。

## 失败处理

- tag 或 pubspec 校验失败：修正版本后创建新 tag；不要复用错误 tag。
- 单个平台失败：在 GitHub Actions 中选择 **Re-run failed jobs**，只重跑失败平台。
- patch 检测到 native 或 asset diff：停止 patch，改为递增 pubspec 版本并发布新 release。
- 已成功的平台不会因另一平台失败而自动回滚。

## 本地打包入口

`packaging/` 是唯一打包实现。Makefile 和 workflow 是互不依赖的两个入口，都直接调用 `packaging/<platform>/`：

```sh
make package-windows
make package-linux
make package-macos
```

这些命令只负责把已经生成的 Shorebird/Flutter bundle 打成 MSI、DEB 或 DMG，不执行 Shorebird release。

## 参考资料

- [Shorebird Development Workflow](https://docs.shorebird.dev/code-push/guides/development-workflow/)
- [Shorebird GitHub Integration](https://docs.shorebird.dev/code-push/ci/github/)
- [Shorebird Create a Release](https://docs.shorebird.dev/code-push/release/)
- [Shorebird Create a Patch](https://docs.shorebird.dev/code-push/patch/)

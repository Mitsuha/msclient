# CI/CD 发布手册

本项目通过 GitHub Actions 和 Shorebird 发布 Windows、Linux、macOS 正式版本及 Dart 热更新。

## 分支与触发规则

- 本地 `master` 对应 GitHub 仓库的 `rm` 分支，推送命令为
  `git push github master:rm`。
- 普通分支 push、`rm` 分支 push 和 Pull Request 都不会触发发布。
- 正式 release tag：`v<major>.<minor>.<patch>+<build>`，例如
  `v1.2.3+45`。
- patch tag：`v<目标 release 版本>-patch.<序号>`，例如
  `v1.2.3+45-patch.1`。
- tag 去掉前导 `v` 和 patch 后缀后，必须与 `pubspec.yaml` 的
  `version` 完全一致，否则 workflow 会终止。

GitHub Actions 仓库 Secrets 必须配置有效的 `SHOREBIRD_TOKEN`。

## 发布正式版本

正式版本适用于 Dart、原生代码、资源、字体、依赖或构建配置的任何变更。

### 1. 同步发布分支

```sh
git fetch github rm
git rebase github/rm
```

开始发布前，确认当前位于本地 `master`，并处理完 rebase 冲突。

### 2. 更新版本

修改 `pubspec.yaml`：

```yaml
version: 1.2.3+45
```

同一 `major.minor` 下，`build` 必须比之前的正式版本大。Windows MSI
会把 `1.2.3+45` 映射成 ProductVersion `1.2.45`，因此 `major`、`minor`
不能超过 255，`build` 不能超过 65535。

### 3. 验证并提交

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
git diff --check
git add -A
git commit -m "release: 1.2.3+45"
```

### 4. 推送 `rm` 分支

```sh
git push github master:rm
```

确认推送成功后再创建 tag，保证 GitHub 的 `rm` 分支已经包含发布提交。

### 5. 创建并推送 release tag

```sh
git tag v1.2.3+45
git push github v1.2.3+45
```

tag push 会触发 `.github/workflows/shorebird-release.yml`。workflow 并行创建
三个平台的 Shorebird release，并生成保留 7 天的 GitHub Actions artifacts：

- Windows：`MirrorStages-Desktop-1.2.3+45-windows-x64.msi`
- Linux：`mirrorstages-desktop_1.2.3+45_amd64.deb`
- macOS：`MirrorStages-Desktop-1.2.3+45-macos.dmg`

该 workflow 不会自动创建 GitHub Release 页面。

## 发布 patch

patch 只适用于 Shorebird 支持的 Dart 代码变更。原生代码、资源、字体、依赖和
构建配置发生变化时，必须发布新的正式版本。

### 1. 准备目标版本代码

从目标 release 对应的代码开始修复，并保持 `pubspec.yaml` 版本不变：

```yaml
version: 1.2.3+45
```

完成修改后执行验证并提交：

```sh
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
git diff --check
git add -A
git commit -m "fix: describe the patch"
git push github master:rm
```

### 2. 创建并推送 patch tag

第一个 patch 使用 `.1`，后续依次使用 `.2`、`.3`：

```sh
git tag v1.2.3+45-patch.1
git push github v1.2.3+45-patch.1
```

tag push 会触发 `.github/workflows/shorebird-patch.yml`，并向目标 release
`1.2.3+45` 的 Shorebird `stable` track 发布三个平台的 patch。必须等待前一个
patch workflow 完成后再发布下一个序号。

## 发布检查

推送 tag 后，在 GitHub Actions 中确认 `prepare` 校验和三个系统任务全部成功。

- tag 或版本校验失败：修正代码和版本后使用一个新 tag，不要移动或复用已推送的 tag。
- 单个平台失败：在 GitHub Actions 中执行 **Re-run failed jobs**。
- patch 包含不支持的 native 或 asset diff：停止 patch，改为递增版本并发布正式 release。
- 某个平台失败不会自动回滚其他已经成功的平台。

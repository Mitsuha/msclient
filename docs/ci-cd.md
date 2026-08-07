# 发布手册

以 `1.2.3+45` 为例，替换成实际版本号。

提交时 pre-commit hook 会自动执行格式化、analyze、测试和 version.json
校验；检查失败则不会提交，无需手动重复执行。

## 自动化操作约定

用户要求提交或发布时，应尽量减少命令次数和对话轮次：

- 读取相关文件后，使用简短的 commit message。
- 按需求选择文件，并用 `git add ... && git commit ...` 一次完成暂存和提交。
- commit 已包含 hook；hook 通过即视为代码可运行，不再手动执行格式化、analyze、测试或其他检查命令。
- 发布时将 tag、分支推送和 tag 推送等连续操作用 `&&` 合并，一次执行。
- 不要很傻逼的执行很多轮对话，不要很傻逼的写很多注释，不能搞的代码比注释还多

## 发布正式版本

```sh
# 1. 同步发布分支（当前应在本地 master）
git fetch github rm
git rebase github/rm

# 2. 改版本号：pubspec.yaml 的 version、version.json 的 "version"，两者必须一致
#    version.json 里 forced / download_page / auth_download / cli_download 按需改

# 3. 提交（pre-commit hook 自动跑格式化、analyze、测试、version.json 校验）
git add -A
git commit -m "release: 1.2.3+45"

# 4. 推送分支，确认推送成功后再打 tag
git push github master:rm

# 5. 打 tag 触发发布
git tag v1.2.3+45
git push github v1.2.3+45
```

CI 完成后 CNB 仓库 `latest/` 下会更新：

- `mirrorstages.msi` / `mirrorstages.deb` / `mirrorstages.dmg`
- `cli/mstages-darwin-arm64` / `cli/mstages-linux-amd64`
- `version.json`（即仓库根目录的 `version.json`）
- `install.sh`（即 `packaging/install.sh`）

CLI 安装/更新命令（用户侧，重复执行即为更新）：

```sh
curl -fsSL https://cnb.cool/mirrorstages/gost/-/git/raw/main/latest/install.sh | sh
```

## 发布 patch

仅限 Dart 代码变更；原生代码、资源、字体、依赖、构建配置变了必须发正式版本。

```sh
# 1. 在目标 release 的代码上修复，pubspec.yaml 版本保持 1.2.3+45 不变
git add -A
git commit -m "fix: describe the patch"
git push github master:rm

# 2. 打 patch tag，序号从 .1 开始递增
git tag v1.2.3+45-patch.1
git push github v1.2.3+45-patch.1
```

前一个 patch workflow 跑完后才能发下一个序号。

## 约束速查

- 本地 `master` → GitHub `rm` 分支；只有 tag push 触发发布。
- release tag `v1.2.3+45`，patch tag `v1.2.3+45-patch.1`；去掉 `v` 和 patch 后缀后
  必须与 `pubspec.yaml`、`version.json` 完全一致。
- 同一 `major.minor` 下 `build` 必须递增；`major`/`minor` ≤ 255，`build` ≤ 65535。
- 仓库 Secrets 需要 `SHOREBIRD_TOKEN` 和 `CNB_GIT_CREDENTIALS`
  （格式 `https://cnb:<CNB access token>@cnb.cool`）。
- 不会创建 GitHub Release 页面；GitHub Actions artifacts 保留 7 天。
- 跳过 hook：`SKIP_TESTS=1 git commit ...` 只跳过测试，
  `git commit --no-verify` 跳过全部检查。

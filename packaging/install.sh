#!/bin/sh
# MirrorStages CLI installer.
#
#   curl -fsSL https://cnb.cool/mirrorstages/gost/-/git/raw/main/latest/install.sh | sh
#
# 再次运行即为更新。可用环境变量：
#   MSTAGES_VERSION   指定版本，默认取 latest/version.json 里的 version
#   MSTAGES_BASE_URL  下载源，默认 CNB latest/
#   MSTAGES_HOME      版本目录，默认 ~/.local/share/mstages
#   MSTAGES_BIN_DIR   软链接目录，默认 ~/.local/bin
set -eu

BASE_URL="${MSTAGES_BASE_URL:-https://cnb.cool/mirrorstages/gost/-/git/raw/main/latest}"
HOME_DIR="${MSTAGES_HOME:-$HOME/.local/share/mstages}"
BIN_DIR="${MSTAGES_BIN_DIR:-$HOME/.local/bin}"
PERSONAS="mstages mcodex mclaude"
TMP_DIR=""
RELOAD_FILE=""

# 只在 stdout 是终端时上色（`curl | sh` 时 stdout 仍是终端）。
if [ -t 1 ]; then
  ESC="$(printf '\033')"
  C_RESET="$ESC[0m"
  C_DIM="$ESC[2m"
  C_BOLD="$ESC[1m"
  C_CYAN="$ESC[36m"
  C_GREEN="$ESC[32m"
  C_YELLOW="$ESC[33m"
else
  C_RESET="" C_DIM="" C_BOLD="" C_CYAN="" C_GREEN="" C_YELLOW=""
fi

log() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

cleanup() {
  [ -n "$TMP_DIR" ] && rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

# 下载 $1 到 $2，curl 优先，回退 wget。
fetch() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --retry 3 -o "$2" "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$2" "$1"
  else
    die "需要 curl 或 wget"
  fi
}

detect_target() {
  os="$(uname -s)"
  arch="$(uname -m)"
  case "$os" in
    Darwin) os=darwin ;;
    Linux) os=linux ;;
    *) die "不支持的操作系统：$os（仅支持 macOS 和 Linux）" ;;
  esac
  case "$arch" in
    arm64 | aarch64) arch=arm64 ;;
    x86_64 | amd64) arch=amd64 ;;
    *) die "不支持的架构：$arch" ;;
  esac
  case "$os-$arch" in
    darwin-arm64 | linux-amd64) ;;
    *) die "暂无 $os-$arch 的预编译版本" ;;
  esac
  printf '%s-%s\n' "$os" "$arch"
}

resolve_version() {
  if [ -n "${MSTAGES_VERSION:-}" ]; then
    printf '%s\n' "$MSTAGES_VERSION"
    return
  fi
  manifest="$TMP_DIR/version.json"
  fetch "$BASE_URL/version.json" "$manifest" || die "无法获取 $BASE_URL/version.json"
  version="$(
    sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$manifest" \
      | head -n 1
  )"
  [ -n "$version" ] || die "version.json 里没有解析到 version"
  printf '%s\n' "$version"
}

# 已安装的版本（软链接指向的版本目录名），未安装时为空。
installed_version() {
  link="$BIN_DIR/mstages"
  [ -L "$link" ] || return 0
  target="$(readlink "$link")" || return 0
  case "$target" in
    "$HOME_DIR"/versions/*)
      target="${target#"$HOME_DIR"/versions/}"
      printf '%s\n' "${target%%/*}"
      ;;
  esac
}

# 把 BIN_DIR 写进 shell 配置，已存在则跳过。
ensure_path() {
  case ":$PATH:" in
    *":$BIN_DIR:"*)
      log "PATH 已包含 $BIN_DIR"
      return
      ;;
  esac

  # 用 $HOME 而不是绝对路径，配置文件可跨机器复用。
  case "$BIN_DIR" in
    "$HOME"/*) path_literal="\$HOME/${BIN_DIR#"$HOME"/}" ;;
    *) path_literal="$BIN_DIR" ;;
  esac
  line="export PATH=\"$path_literal:\$PATH\""
  marker="# added by mstages installer"

  rcfiles=""
  shell_name="$(basename "${SHELL:-}")"
  case "$shell_name" in
    zsh) rcfiles="${ZDOTDIR:-$HOME}/.zshrc" ;;
    bash)
      # macOS 的登录 shell 读 .bash_profile，Linux 交互式 shell 读 .bashrc。
      if [ "$(uname -s)" = Darwin ] && [ -f "$HOME/.bash_profile" ]; then
        rcfiles="$HOME/.bash_profile"
      else
        rcfiles="$HOME/.bashrc"
      fi
      ;;
    *)
      # 未知 shell：写进已存在的通用配置。
      for candidate in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
        [ -f "$candidate" ] && rcfiles="$rcfiles $candidate"
      done
      [ -n "$rcfiles" ] || rcfiles="$HOME/.profile"
      ;;
  esac

  for rcfile in $rcfiles; do
    if [ -f "$rcfile" ] && grep -Fq "$marker" "$rcfile"; then
      log "$rcfile 已配置过 PATH"
      continue
    fi
    printf '\n%s\n%s\n' "$marker" "$line" >>"$rcfile"
    log "已写入 $rcfile"
    RELOAD_FILE="$rcfile"
  done
}

# macOS 上未签名的二进制会被 Gatekeeper 拦下，就地做一次 ad-hoc 签名。
sign_macos() {
  [ "$(uname -s)" = Darwin ] || return 0
  binary_path="$1"

  # curl/wget 下载不会打 quarantine 标记，用户手动下载过则会有，顺手清掉。
  if command -v xattr >/dev/null 2>&1; then
    xattr -d com.apple.quarantine "$binary_path" >/dev/null 2>&1 || true
  fi

  if ! command -v codesign >/dev/null 2>&1; then
    log "未找到 codesign，跳过签名；首次运行若被拦截，请到「系统设置 - 隐私与安全性」放行"
    return 0
  fi

  if codesign --verify --strict "$binary_path" >/dev/null 2>&1; then
    log "签名已存在，跳过"
    return 0
  fi

  if codesign --force --sign - "$binary_path" >/dev/null 2>&1; then
    log "已 ad-hoc 签名 $binary_path"
    return 0
  fi

  # 权限不足时用 sudo 重试，密码从终端读（`curl | sh` 下 stdin 是脚本本身）。
  if command -v sudo >/dev/null 2>&1 && [ -e /dev/tty ]; then
    log "签名需要管理员权限，请输入密码"
    if sudo -p "%p 的密码：" codesign --force --sign - "$binary_path" </dev/tty; then
      log "已 ad-hoc 签名 $binary_path"
      return 0
    fi
  fi

  log "${C_YELLOW}签名失败${C_RESET}；首次运行若被拦截，请到「系统设置 - 隐私与安全性」放行"
}

### 安装完成后的提示框 ###############################################
# 框内宽度固定 58 列；中文按 2 列计，各行右侧留白已按显示宽度算好。
BOX_WIDTH=58

spaces() {
  i=0
  while [ "$i" -lt "$1" ]; do
    printf ' '
    i=$((i + 1))
  done
}

hline() {
  printf '%s%s' "$C_CYAN" "$1"
  i=0
  while [ "$i" -lt "$BOX_WIDTH" ]; do
    printf '─'
    i=$((i + 1))
  done
  printf '%s%s\n' "$2" "$C_RESET"
}

# row <命令> <说明> <说明的显示宽度>
row() {
  cmd_pad=$((20 - ${#1}))
  desc_pad=$((BOX_WIDTH - 2 - 20 - $3))
  printf '%s│%s  %s%s%s%s%s%s%s│%s\n' \
    "$C_CYAN" "$C_RESET" \
    "$C_GREEN$C_BOLD" "$1" "$C_RESET" "$(spaces "$cmd_pad")" \
    "$2" "$(spaces "$desc_pad")" \
    "$C_CYAN" "$C_RESET"
}

banner() {
  head_pad=$((BOX_WIDTH - 20 - ${#1}))
  printf '\n'
  hline '╭' '╮'
  printf '%s│%s  %sMirrorStages CLI%s  %s%s%s%s%s│%s\n' \
    "$C_CYAN" "$C_RESET" "$C_BOLD" "$C_RESET" \
    "$C_DIM" "$1" "$C_RESET" "$(spaces "$head_pad")" \
    "$C_CYAN" "$C_RESET"
  hline '├' '┤'
  row 'mstages auth login' '登录 MirrorStages 账号' 22
  row 'mcodex' '启动 Codex' 10
  row 'mclaude' '启动 Claude Code' 16
  hline '╰' '╯'

  if [ -n "$RELOAD_FILE" ]; then
    printf '\n%s先重开终端，或执行：source %s%s\n' \
      "$C_YELLOW" "$RELOAD_FILE" "$C_RESET"
  fi
  printf '\n'
}
######################################################################

main() {
  TMP_DIR="$(mktemp -d)"

  target="$(detect_target)"
  version="$(resolve_version)"
  binary="mstages-$target"
  version_dir="$HOME_DIR/versions/$version"
  installed="$(installed_version)"

  log "MirrorStages CLI $version ($target)"

  if [ "$installed" = "$version" ] && [ -x "$version_dir/mstages" ]; then
    log "已是最新版本，检查软链接与 PATH"
  else
    log "下载 $BASE_URL/cli/$binary"
    fetch "$BASE_URL/cli/$binary" "$TMP_DIR/mstages" \
      || die "下载失败：$BASE_URL/cli/$binary"
    [ -s "$TMP_DIR/mstages" ] || die "下载到的文件为空"
    chmod 0755 "$TMP_DIR/mstages"

    mkdir -p "$version_dir"
    # 先落到同目录临时文件再 mv，避免覆盖到一半失败留下坏二进制。
    mv "$TMP_DIR/mstages" "$version_dir/.mstages.new"
    mv "$version_dir/.mstages.new" "$version_dir/mstages"
    log "已安装到 $version_dir/mstages"
  fi

  mkdir -p "$BIN_DIR"
  for name in $PERSONAS; do
    link="$BIN_DIR/$name"
    if [ -e "$link" ] && [ ! -L "$link" ]; then
      die "$link 已存在且不是软链接，请先手动移除"
    fi
    ln -sf "$version_dir/mstages" "$link"
    log "链接 $link -> $version_dir/mstages"
  done

  sign_macos "$version_dir/mstages"
  ensure_path
  banner "$version"
}

main "$@"

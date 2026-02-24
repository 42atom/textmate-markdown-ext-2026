#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TM_MANAGED="$HOME/Library/Application Support/TextMate/Managed/Bundles"
TM_USER="$HOME/Library/Application Support/TextMate/Bundles"
RUBY_BIN="/System/Library/Frameworks/Ruby.framework/Versions/Current/usr/bin/ruby"
LOCAL_THEME_ROOT="$ROOT_DIR/theme-css-5-to-Themes@tmbundle-Support-web-themes"
THEME_DIRS=(
  "tpr-github"
  "tpr-techo"
  "tpr-han"
  "tpr-vue"
  "tpr-bluetex"
)

find_bundle() {
  local name="$1"
  local base
  for base in "$TM_USER" "$TM_MANAGED"; do
    if [[ -d "$base/$name" ]]; then
      printf '%s\n' "$base/$name"
      return 0
    fi
  done
  return 1
}

find_bundle_with_file() {
  local name="$1"
  local rel="$2"
  local base
  for base in "$TM_USER" "$TM_MANAGED"; do
    if [[ -d "$base/$name" && -f "$base/$name/$rel" ]]; then
      printf '%s\n' "$base/$name"
      return 0
    fi
  done
  return 1
}

backup_if_exists() {
  local f="$1"
  local ts="$2"
  if [[ -f "$f" ]]; then
    cp "$f" "$f.bak-$ts"
  fi
}

MD_BUNDLE="$(find_bundle_with_file 'Markdown.tmbundle' 'Commands/Markdown preview.plist' || true)"
THEMES_BUNDLE="$(find_bundle_with_file 'Themes.tmbundle' 'Support/web-themes/default/style.css' || find_bundle 'Themes.tmbundle' || true)"
FM_BUNDLE="$(find_bundle 'Markdown (Front Matter).tmbundle' || true)"

[[ -n "$MD_BUNDLE" ]] || { echo "[ERROR] 未找到 Markdown.tmbundle"; exit 1; }
[[ -n "$THEMES_BUNDLE" ]] || { echo "[ERROR] 未找到 Themes.tmbundle"; exit 1; }

PREVIEW_PLIST="$MD_BUNDLE/Commands/Markdown preview.plist"
THEMES_WEB_THEMES="$THEMES_BUNDLE/Support/web-themes"

for f in \
  "$ROOT_DIR/templates/show_preview.rb" \
  "$ROOT_DIR/templates/Split Windows.tmCommand"; do
  [[ -f "$f" ]] || { echo "[ERROR] 模板文件不存在: $f"; exit 1; }
done

[[ -d "$LOCAL_THEME_ROOT" ]] || { echo "[ERROR] 主题目录不存在: $LOCAL_THEME_ROOT"; exit 1; }
for d in "${THEME_DIRS[@]}"; do
  [[ -d "$LOCAL_THEME_ROOT/$d" ]] || { echo "[ERROR] 缺少主题目录: $LOCAL_THEME_ROOT/$d"; exit 1; }
done

for f in "$PREVIEW_PLIST"; do
  [[ -f "$f" ]] || { echo "[ERROR] 目标文件不存在: $f"; exit 1; }
done

ts="$(date +%Y%m%d-%H%M%S)"
backup_if_exists "$PREVIEW_PLIST" "$ts"
echo "[INFO] 备份完成: $ts"

# 1) 安装主题目录到 Themes.tmbundle 的 web-themes
mkdir -p "$THEMES_WEB_THEMES"
for d in "${THEME_DIRS[@]}"; do
  src="$LOCAL_THEME_ROOT/$d"
  dst="$THEMES_WEB_THEMES/$d"
  if [[ -d "$dst" ]]; then
    cp -R "$dst" "$dst.bak-$ts"
  fi
  mkdir -p "$dst"
  cp -R "$src"/. "$dst"/
  echo "[INFO] 主题已安装: $dst"
done

# 2) Show Preview 跟随逻辑
SHOW_PREVIEW_CONTENT="$(cat "$ROOT_DIR/templates/show_preview.rb")"
plutil -replace command -string "$SHOW_PREVIEW_CONTENT" "$PREVIEW_PLIST"

USER_SHOW_PREVIEW="$TM_USER/Markdown.tmbundle/Commands/Show Preview.tmCommand"
if [[ -f "$USER_SHOW_PREVIEW" ]]; then
  backup_if_exists "$USER_SHOW_PREVIEW" "$ts"
  if plutil -extract changed.command raw "$USER_SHOW_PREVIEW" >/dev/null 2>&1; then
    plutil -replace changed.command -string "$SHOW_PREVIEW_CONTENT" "$USER_SHOW_PREVIEW"
  elif plutil -extract command raw "$USER_SHOW_PREVIEW" >/dev/null 2>&1; then
    plutil -replace command -string "$SHOW_PREVIEW_CONTENT" "$USER_SHOW_PREVIEW"
  fi
fi

# 3) 安装 split command 到用户覆写 bundle
USER_MD_COMMANDS="$TM_USER/Markdown.tmbundle/Commands"
mkdir -p "$USER_MD_COMMANDS"
USER_SPLIT_CMD="$USER_MD_COMMANDS/Split Windows.tmCommand"
backup_if_exists "$USER_SPLIT_CMD" "$ts"
install -m 644 "$ROOT_DIR/templates/Split Windows.tmCommand" "$USER_SPLIT_CMD"

# 4) 修复 Markdown preview 的 legacy ruby18 shebang
old_cmd="$(plutil -extract command raw "$PREVIEW_PLIST")"
new_cmd="$(printf '%s' "$old_cmd" | perl -0777 -pe 's{\A\#\!/usr/bin/env ruby18 -wKU}{#!/System/Library/Frameworks/Ruby.framework/Versions/Current/usr/bin/ruby}')"
if [[ "$old_cmd" != "$new_cmd" ]]; then
  plutil -replace command -string "$new_cmd" "$PREVIEW_PLIST"
  echo "[INFO] 已修复 Markdown Preview 命令 shebang（去掉 -K 警告）"
fi

# 5) 可选修复 Front Matter pre-filter shebang
if [[ -n "$FM_BUNDLE" ]]; then
  FM_SCRIPT="$FM_BUNDLE/Support/strip_front_matter"
  if [[ -f "$FM_SCRIPT" ]]; then
    backup_if_exists "$FM_SCRIPT" "$ts"
    perl -0777 -i -pe 's{\A\#\!/usr/bin/env ruby18 -wKU}{#!/System/Library/Frameworks/Ruby.framework/Versions/Current/usr/bin/ruby}' "$FM_SCRIPT"
    chmod +x "$FM_SCRIPT"
    echo "[INFO] 已修复 Front Matter 预过滤脚本 shebang（去掉 -K 警告）"
  fi
fi

# 6) Syntax checks
TMP_PREVIEW="$(mktemp /tmp/show-preview-XXXXXX.rb)"
printf '%s' "$SHOW_PREVIEW_CONTENT" > "$TMP_PREVIEW"
"$RUBY_BIN" -c "$TMP_PREVIEW" >/dev/null
rm -f "$TMP_PREVIEW"

# 7) 验证主题文件
for d in "${THEME_DIRS[@]}"; do
  [[ -s "$THEMES_WEB_THEMES/$d/style.css" ]] || { echo "[ERROR] 主题文件为空: $THEMES_WEB_THEMES/$d/style.css"; exit 1; }
  [[ -s "$THEMES_WEB_THEMES/$d/images/header.png" ]] || { echo "[ERROR] 缺少 header 资源: $THEMES_WEB_THEMES/$d/images/header.png"; exit 1; }
  [[ -s "$THEMES_WEB_THEMES/$d/images/teaser.png" ]] || { echo "[ERROR] 缺少 teaser 资源: $THEMES_WEB_THEMES/$d/images/teaser.png"; exit 1; }
done

echo "[OK] 完成"
echo "[OK] 主题目录: $THEMES_WEB_THEMES"
echo "[OK] 已安装主题: ${THEME_DIRS[*]}"
echo "[OK] 切换方式: 在 Markdown Preview 顶部 Theme 下拉选择 tpr-* 主题"
echo "[OK] 若 TextMate 正在运行，请 Reload Bundles 或重启 TextMate"
echo "[OK] 分屏快捷键: Option + Command + S"

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

THEMES_BUNDLE="$(find_bundle_with_file 'Themes.tmbundle' 'Support/web-themes/default/style.css' || find_bundle 'Themes.tmbundle' || true)"
FM_BUNDLE="$(find_bundle 'Markdown (Front Matter).tmbundle' || true)"
MANAGED_MD_BUNDLE="$TM_MANAGED/Markdown.tmbundle"
USER_MD_BUNDLE="$TM_USER/Markdown.tmbundle"
MD_BUNDLE="$USER_MD_BUNDLE"

[[ -n "$THEMES_BUNDLE" ]] || { echo "[ERROR] 未找到 Themes.tmbundle"; exit 1; }
[[ -f "$MANAGED_MD_BUNDLE/Commands/Markdown preview.plist" ]] || { echo "[ERROR] 未找到 Managed Markdown.tmbundle（或缺少 Markdown preview.plist）"; exit 1; }

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

ts="$(date +%Y%m%d-%H%M%S)"
THEME_BACKUP_DIR="$HOME/.Trash/TextMate-theme-backups-$ts"
BUNDLE_BACKUP_DIR="$HOME/.Trash/TextMate-bundle-backups-$ts"
mkdir -p "$THEME_BACKUP_DIR"
mkdir -p "$BUNDLE_BACKUP_DIR"

# 0) 处理用户 Markdown bundle：安装到用户目录，确保 Reload Bundles 可生效。
while IFS= read -r stale_bundle; do
  [[ -n "$stale_bundle" ]] || continue
  stale_name="$(basename "$stale_bundle")"
  mv "$stale_bundle" "$BUNDLE_BACKUP_DIR/$stale_name"
  echo "[INFO] 已迁移遗留 partial bundle: $stale_name -> $BUNDLE_BACKUP_DIR/$stale_name"
done < <(find "$TM_USER" -maxdepth 1 -mindepth 1 -type d -name '*.tmbundle.partial.bak-*' -print 2>/dev/null)

if [[ ! -d "$USER_MD_BUNDLE" ]]; then
  cp -R "$MANAGED_MD_BUNDLE" "$USER_MD_BUNDLE"
  echo "[INFO] 已创建用户 Markdown bundle（来自 Managed）: $USER_MD_BUNDLE"
elif [[ ! -f "$USER_MD_BUNDLE/Commands/Markdown preview.plist" || ! -f "$USER_MD_BUNDLE/info.plist" ]]; then
  USER_MD_BACKUP="$BUNDLE_BACKUP_DIR/Markdown.tmbundle.partial.bak-$ts"
  mv "$USER_MD_BUNDLE" "$USER_MD_BACKUP"
  cp -R "$MANAGED_MD_BUNDLE" "$USER_MD_BUNDLE"
  echo "[INFO] 用户 Markdown bundle 不完整，已重建并备份到: $USER_MD_BACKUP"
fi

for f in "$PREVIEW_PLIST"; do
  [[ -f "$f" ]] || { echo "[ERROR] 目标文件不存在: $f"; exit 1; }
done
backup_if_exists "$PREVIEW_PLIST" "$ts"
echo "[INFO] 备份完成: $ts"

# 1) 安装主题目录到 Themes.tmbundle 的 web-themes
mkdir -p "$THEMES_WEB_THEMES"

# 清理历史遗留的 *.bak-* 主题目录，避免被 TextMate 当成可选主题扫描出来。
while IFS= read -r stale_dir; do
  [[ -n "$stale_dir" ]] || continue
  stale_name="$(basename "$stale_dir")"
  mv "$stale_dir" "$THEME_BACKUP_DIR/$stale_name"
  echo "[INFO] 已迁移遗留备份主题: $stale_name -> $THEME_BACKUP_DIR/$stale_name"
done < <(find "$THEMES_WEB_THEMES" -maxdepth 1 -mindepth 1 -type d -name '*.bak-*' -print 2>/dev/null)

for d in "${THEME_DIRS[@]}"; do
  src="$LOCAL_THEME_ROOT/$d"
  dst="$THEMES_WEB_THEMES/$d"
  if [[ -d "$dst" ]]; then
    cp -R "$dst" "$THEME_BACKUP_DIR/${d}.bak-$ts"
    echo "[INFO] 已备份主题目录: $THEME_BACKUP_DIR/${d}.bak-$ts"
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

# 3) 安装 split command 到用户 Markdown bundle（确保 Reload Bundles 可感知）
SPLIT_UUID="0B9CF6F8-179C-45CA-8CCF-CC3DF2170298"
SPLIT_CMD="$MD_BUNDLE/Commands/Split Windows.tmCommand"
SPLIT_INFO="$MD_BUNDLE/info.plist"
backup_if_exists "$SPLIT_CMD" "$ts"
install -m 644 "$ROOT_DIR/templates/Split Windows.tmCommand" "$SPLIT_CMD"
backup_if_exists "$SPLIT_INFO" "$ts"

# 将 Split 命令 UUID 追加到 mainMenu.items（避免“菜单里没有”导致快捷键失效）。
python3 - "$SPLIT_INFO" "$SPLIT_UUID" <<'PY'
import plistlib
import sys

path, split_uuid = sys.argv[1], sys.argv[2]
with open(path, "rb") as f:
    data = plistlib.load(f)

main_menu = data.setdefault("mainMenu", {})
items = main_menu.setdefault("items", [])

if split_uuid not in items:
    items.append(split_uuid)
    with open(path, "wb") as f:
        plistlib.dump(data, f, sort_keys=False)
    print("[INFO] 已将 Split 命令加入 Markdown 菜单")
PY

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
echo "[OK] 主题备份目录: $THEME_BACKUP_DIR"
echo "[OK] Split 命令安装位置: $SPLIT_CMD"
echo "[OK] 已安装主题: ${THEME_DIRS[*]}"
echo "[OK] 切换方式: 在 Markdown Preview 顶部 Theme 下拉选择 tpr-* 主题"
echo "[OK] 若 TextMate 正在运行，请 Reload Bundles 或重启 TextMate"
echo "[OK] 分屏快捷键: Option + Command + S"

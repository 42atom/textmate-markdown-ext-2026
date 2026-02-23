#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TM_MANAGED="$HOME/Library/Application Support/TextMate/Managed/Bundles"
TM_USER="$HOME/Library/Application Support/TextMate/Bundles"
RUBY_BIN="/System/Library/Frameworks/Ruby.framework/Versions/Current/usr/bin/ruby"
THEME_URL="https://raw.githubusercontent.com/typora/typora-default-themes/master/themes/github.css"

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

backup_if_exists() {
  local f="$1"
  local ts="$2"
  if [[ -f "$f" ]]; then
    cp "$f" "$f.bak-$ts"
  fi
}

GH_BUNDLE="$(find_bundle 'Markdown (GitHub).tmbundle' || true)"
MJ_BUNDLE="$(find_bundle 'Markdown (MathJax).tmbundle' || true)"
MD_BUNDLE="$(find_bundle 'Markdown.tmbundle' || true)"
FM_BUNDLE="$(find_bundle 'Markdown (Front Matter).tmbundle' || true)"

[[ -n "$GH_BUNDLE" ]] || { echo "[ERROR] 未找到 Markdown (GitHub).tmbundle"; exit 1; }
[[ -n "$MJ_BUNDLE" ]] || { echo "[ERROR] 未找到 Markdown (MathJax).tmbundle"; exit 1; }
[[ -n "$MD_BUNDLE" ]] || { echo "[ERROR] 未找到 Markdown.tmbundle"; exit 1; }

REDCARPET="$GH_BUNDLE/Support/bin/redcarpet.rb"
APPEND_JS="$MJ_BUNDLE/Support/append_mathjax_js"
PREVIEW_PLIST="$MD_BUNDLE/Commands/Markdown preview.plist"
CSS_DIR="$GH_BUNDLE/Support/css"
CSS_FILE="$CSS_DIR/typora-github.css"

for f in \
  "$ROOT_DIR/templates/redcarpet.rb" \
  "$ROOT_DIR/templates/append_mathjax_js.rb" \
  "$ROOT_DIR/templates/show_preview.rb" \
  "$ROOT_DIR/templates/Split Windows.tmCommand"; do
  [[ -f "$f" ]] || { echo "[ERROR] 模板文件不存在: $f"; exit 1; }
done

for f in "$REDCARPET" "$APPEND_JS" "$PREVIEW_PLIST"; do
  [[ -f "$f" ]] || { echo "[ERROR] 目标文件不存在: $f"; exit 1; }
done

ts="$(date +%Y%m%d-%H%M%S)"
backup_if_exists "$REDCARPET" "$ts"
backup_if_exists "$APPEND_JS" "$ts"
backup_if_exists "$PREVIEW_PLIST" "$ts"
echo "[INFO] 备份完成: $ts"

# 1) Theme
mkdir -p "$CSS_DIR"
curl -fsSL "$THEME_URL" -o "$CSS_FILE"
echo "[INFO] 主题已下载: $CSS_FILE"

# 2) Renderer and post-filter
install -m 755 "$ROOT_DIR/templates/redcarpet.rb" "$REDCARPET"
install -m 755 "$ROOT_DIR/templates/append_mathjax_js.rb" "$APPEND_JS"

# 3) Show Preview command body
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

# 4) Install split command in user bundle override
USER_MD_COMMANDS="$TM_USER/Markdown.tmbundle/Commands"
mkdir -p "$USER_MD_COMMANDS"
USER_SPLIT_CMD="$USER_MD_COMMANDS/Split Windows.tmCommand"
backup_if_exists "$USER_SPLIT_CMD" "$ts"
install -m 644 "$ROOT_DIR/templates/Split Windows.tmCommand" "$USER_SPLIT_CMD"

# 5) Fix legacy ruby18 -wKU shebang warning in Markdown preview command
old_cmd="$(plutil -extract command raw "$PREVIEW_PLIST")"
new_cmd="$(printf '%s' "$old_cmd" | perl -0777 -pe 's{\A\#\!/usr/bin/env ruby18 -wKU}{#!/System/Library/Frameworks/Ruby.framework/Versions/Current/usr/bin/ruby}')"
if [[ "$old_cmd" != "$new_cmd" ]]; then
  plutil -replace command -string "$new_cmd" "$PREVIEW_PLIST"
  echo "[INFO] 已修复 Markdown Preview 命令 shebang（去掉 -K 警告）"
fi

# 6) Optional fix for Front Matter pre-filter
if [[ -n "$FM_BUNDLE" ]]; then
  FM_SCRIPT="$FM_BUNDLE/Support/strip_front_matter"
  if [[ -f "$FM_SCRIPT" ]]; then
    backup_if_exists "$FM_SCRIPT" "$ts"
    perl -0777 -i -pe 's{\A\#\!/usr/bin/env ruby18 -wKU}{#!/System/Library/Frameworks/Ruby.framework/Versions/Current/usr/bin/ruby}' "$FM_SCRIPT"
    chmod +x "$FM_SCRIPT"
    echo "[INFO] 已修复 Front Matter 预过滤脚本 shebang（去掉 -K 警告）"
  fi
fi

# 7) Syntax checks
"$RUBY_BIN" -c "$REDCARPET" >/dev/null
"$RUBY_BIN" -c "$APPEND_JS" >/dev/null
TMP_PREVIEW="$(mktemp /tmp/show-preview-XXXXXX.rb)"
printf '%s' "$SHOW_PREVIEW_CONTENT" > "$TMP_PREVIEW"
"$RUBY_BIN" -c "$TMP_PREVIEW" >/dev/null
rm -f "$TMP_PREVIEW"

# 8) Smoke check
TMP_HTML="/tmp/tm-preview-$(date +%s)-$$.html"
cat <<'MD' | "$REDCARPET" | "$APPEND_JS" > "$TMP_HTML"
# Demo

普通段落 `inline code`

```mermaid
graph TD;
A-->B;
```
MD

grep -q "mermaid.min.js" "$TMP_HTML"
grep -q "<pre class='mermaid'>" "$TMP_HTML"

if grep -q "color: #4183C4;" "$TMP_HTML"; then
  echo "[INFO] 主题颜色校验通过"
else
  echo "[WARN] 未检测到 color: #4183C4;（可能是主题 upstream 变化）"
fi

echo "[OK] 完成"
echo "[OK] 主题文件: $CSS_FILE"
echo "[OK] 验证输出: $TMP_HTML"
echo "[OK] 若 TextMate 正在运行，请 Reload Bundles 或重启 TextMate"
echo "[OK] 分屏快捷键: Option + Command + S"

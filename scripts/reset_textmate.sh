#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  reset_textmate.sh [--reset|--uninstall] [--dry-run] [--remove-mate]

Options:
  --reset        仅重置用户层数据（默认）
  --uninstall    附加移动 TextMate.app（如有权限）
  --dry-run      仅打印将要移动的路径，不真正执行
  --remove-mate  尝试移除 /usr/local/bin/mate（可能需要管理员权限）
  -h, --help     显示帮助

说明:
  所有删除动作均为“移动到回收站”，目录为:
    ~/.Trash/TextMate-reset-<timestamp>
EOF
}

MODE="reset"
DRY_RUN="false"
REMOVE_MATE="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reset)
      MODE="reset"
      ;;
    --uninstall)
      MODE="uninstall"
      ;;
    --dry-run)
      DRY_RUN="true"
      ;;
    --remove-mate)
      REMOVE_MATE="true"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] 未知参数: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

TS="$(date +%Y%m%d-%H%M%S)"
TRASH_DIR="$HOME/.Trash/TextMate-reset-$TS"
mkdir -p "$TRASH_DIR"

MOVED_COUNT=0
SKIP_COUNT=0

move_to_trash() {
  local src="$1"
  local base dest
  [[ -e "$src" || -L "$src" ]] || return 0

  base="$(basename "$src")"
  dest="$TRASH_DIR/$base"
  if [[ -e "$dest" || -L "$dest" ]]; then
    dest="$TRASH_DIR/${base}.dup.$RANDOM"
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY] $src -> $dest"
    MOVED_COUNT=$((MOVED_COUNT + 1))
    return 0
  fi

  if mv "$src" "$dest" 2>/dev/null; then
    echo "[MOVED] $src -> $dest"
    MOVED_COUNT=$((MOVED_COUNT + 1))
  else
    echo "[SKIP]  $src (无权限或被占用)"
    SKIP_COUNT=$((SKIP_COUNT + 1))
  fi
}

# 先尝试退出 TextMate
if [[ "$DRY_RUN" == "true" ]]; then
  echo "[DRY] quit TextMate process"
else
  osascript -e 'tell application "TextMate" to quit' >/dev/null 2>&1 || true
  sleep 1
  pkill -x TextMate >/dev/null 2>&1 || true
  sleep 1
fi

# 用户层路径
USER_TARGETS=(
  "$HOME/Library/Application Support/TextMate"
  "$HOME/Library/Application Support/Avian"
  "$HOME/Library/WebKit/com.macromates.TextMate"
  "$HOME/Library/HTTPStorages/com.macromates.TextMate"
  "$HOME/.tm_properties"
)

for p in "${USER_TARGETS[@]}"; do
  move_to_trash "$p"
done

# 动态扫描常见残留
scan_and_move() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  while IFS= read -r -d '' p; do
    move_to_trash "$p"
  done < <(
    find "$dir" -maxdepth 1 \
      \( -name 'com.macromates*' -o -iname '*textmate*' -o -name '*TextMate*' \) \
      -print0 2>/dev/null
  )
}

scan_and_move "$HOME/Library/Preferences"
scan_and_move "$HOME/Library/Caches"
scan_and_move "$HOME/Library/Saved Application State"
scan_and_move "$HOME/Library/Autosave Information"
scan_and_move "$HOME/Library/Logs/DiagnosticReports"

# 卸载模式附加 App
if [[ "$MODE" == "uninstall" ]]; then
  move_to_trash "/Applications/TextMate.app"
  move_to_trash "$HOME/Applications/TextMate.app"
fi

# 可选处理 mate
if [[ "$REMOVE_MATE" == "true" ]]; then
  move_to_trash "/usr/local/bin/mate"
else
  if command -v mate >/dev/null 2>&1; then
    echo "[INFO] 保留 /usr/local/bin/mate（如需移除请加 --remove-mate）"
  fi
fi

if [[ "$DRY_RUN" != "true" ]]; then
  if ps aux | grep -v grep | grep -q 'TextMate.app/Contents/MacOS/TextMate'; then
    echo "[WARN] TextMate 进程仍在运行，请手动关闭后重试"
  fi
fi

echo "[OK] 模式: $MODE"
echo "[OK] 回收站目录: $TRASH_DIR"
echo "[OK] 移动数量: $MOVED_COUNT"
echo "[OK] 跳过数量: $SKIP_COUNT"

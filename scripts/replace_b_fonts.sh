#!/usr/bin/env bash
set -euo pipefail

# 将 Themes.tmbundle 里以 B/b 开头的字体名替换为系统等线字体。
TARGET_FONT="${1:-PingFang SC}"
TM_ROOT="$HOME/Library/Application Support/TextMate"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_ROOT="$HOME/.Trash/TextMate-fontname-backups-$TIMESTAMP"

mkdir -p "$BACKUP_ROOT"

THEME_BUNDLES=(
  "$TM_ROOT/Bundles/Themes.tmbundle"
  "$TM_ROOT/Managed/Bundles/Themes.tmbundle"
)

changed=0

backup_file() {
  local file="$1"
  local rel="${file#"$TM_ROOT/"}"
  local dst="$BACKUP_ROOT/$rel"
  mkdir -p "$(dirname "$dst")"
  cp "$file" "$dst"
}

for bundle in "${THEME_BUNDLES[@]}"; do
  pref_dir="$bundle/Preferences"
  [[ -d "$pref_dir" ]] || continue

  while IFS= read -r pref; do
    [[ -n "$pref" ]] || continue
    current="$(plutil -extract settings.fontName raw "$pref" 2>/dev/null || true)"
    [[ -n "$current" ]] || continue

    if [[ "$current" =~ ^[Bb] ]]; then
      backup_file "$pref"
      plutil -replace settings.fontName -string "$TARGET_FONT" "$pref"
      echo "[OK] ${pref}: ${current} -> ${TARGET_FONT}"
      changed=$((changed + 1))
    fi
  done < <(find "$pref_dir" -type f -name '*.tmPreferences' -print)
done

echo "[DONE] changed=$changed"
echo "[DONE] backup=$BACKUP_ROOT"


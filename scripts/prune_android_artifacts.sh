#!/bin/sh
# Remove APKs from old build archives under artifacts/android, keeping the newest
# archives whole. Dart symbols (symbols/) and logs are always kept so old crash
# reports can still be symbolicated. Dry run by default; pass --apply to delete.
#   sh scripts/prune_android_artifacts.sh [--keep N] [--apply]
set -eu
cd "$(dirname "$0")/.."

keep=5
apply=0
while [ $# -gt 0 ]; do
  case "$1" in
    --keep) keep=$2; shift 2 ;;
    --keep=*) keep=${1#--keep=}; shift ;;
    --apply) apply=1; shift ;;
    *) printf '未知参数：%s\n' "$1" >&2; exit 2 ;;
  esac
done

dir=artifacts/android
[ -d "$dir" ] || exit 0
# Every build archive (release, local and hand-named ones), oldest first.
old=$(find "$dir" -mindepth 1 -maxdepth 1 -type d \
  -exec stat -f '%m %N' {} + | sort -n | awk '{ $1 = ""; sub(/^ /, ""); print }' |
  awk -v keep="$keep" '{ line[NR] = $0 } END { for (i = 1; i <= NR - keep; i++) print line[i] }')
[ -n "$old" ] || { printf '没有需要清理的旧归档。\n'; exit 0; }

apks=$(printf '%s\n' "$old" | while IFS= read -r d; do find "$d" -maxdepth 1 -type f -name '*.apk'; done)
[ -n "$apks" ] || { printf '旧归档里没有 APK。\n'; exit 0; }
size=$(printf '%s\n' "$apks" | tr '\n' '\0' | xargs -0 du -ck | tail -1 | awk '{ printf "%.1f", $1 / 1048576 }')
count=$(printf '%s\n' "$apks" | wc -l | tr -d ' ')
if [ "$apply" = 1 ]; then
  printf '%s\n' "$apks" | tr '\n' '\0' | xargs -0 rm -f
  printf '已删除 %s 个旧 APK，释放约 %s GB；保留最近 %s 个归档及全部符号表。\n' "$count" "$size" "$keep"
else
  printf '%s\n' "$apks"
  printf '预演：将删除以上 %s 个旧 APK（约 %s GB），保留最近 %s 个归档及全部符号表。加 --apply 执行。\n' "$count" "$size" "$keep"
fi

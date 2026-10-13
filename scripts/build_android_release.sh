#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

# Archive matching symbols outside build/ so flutter clean cannot remove them.
release_id=$(date -u +%Y%m%dT%H%M%SZ)
release_dir="$PWD/artifacts/android/$release_id"
mkdir -p "$release_dir/symbols"
"${FLUTTER_BIN:-flutter}" build apk --release --split-per-abi \
  --split-debug-info="$release_dir/symbols" \
  -P force-version-code-ignoring-abi=true "$@"
for abi in armeabi-v7a arm64-v8a x86_64; do
  cp "build/app/outputs/flutter-apk/app-$abi-release.apk" "$release_dir/"
done
printf 'Release APKs and matching Dart symbols: %s\n' "$release_dir"

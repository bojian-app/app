#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

# Archive matching symbols outside build/ so flutter clean cannot remove them.
release_id=$(date -u +%Y%m%dT%H%M%SZ)
release_dir="$PWD/artifacts/android/$release_id"
mkdir -p "$release_dir/symbols"
"${FLUTTER_BIN:-flutter}" build apk --release --split-per-abi \
  --dart-define=BOJIAN_ENV=production \
  --split-debug-info="$release_dir/symbols" \
  -P force-version-code-ignoring-abi=true "$@"
# Phones install arm64; set ARCHIVE_ALL_ABIS=1 to also archive armeabi-v7a and x86_64.
abis=arm64-v8a
if [ "${ARCHIVE_ALL_ABIS:-0}" = 1 ]; then
  abis="armeabi-v7a arm64-v8a x86_64"
fi
for abi in $abis; do
  cp "build/app/outputs/flutter-apk/app-$abi-release.apk" "$release_dir/"
done
cp build/app/outputs/apk/release/output-metadata.json "$release_dir/"
python3 - "$release_dir" <<'PY'
import json
from pathlib import Path
import sys

archive = Path(sys.argv[1])
for variant in json.loads((archive / "output-metadata.json").read_text())["elements"]:
    if (archive / variant["outputFile"]).is_file():
        print(f'{variant["outputFile"]}: versionName={variant["versionName"]} versionCode={variant["versionCode"]}')
PY
printf 'Release APKs and matching Dart symbols: %s\n' "$release_dir"

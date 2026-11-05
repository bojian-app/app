#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

device=${1:-}
if [ -z "$device" ]; then
  devices=$(adb devices | awk 'NR > 1 && $2 == "device" {print $1}')
  count=$(printf '%s\n' "$devices" | awk 'NF {count++} END {print count+0}')
  if [ "$count" != 1 ]; then
    printf '请连接一台已授权的 Android 手机，或传入设备 ID。\n' >&2
    exit 1
  fi
  device=$devices
fi
adb -s "$device" get-state >/dev/null
python3 ../app-server/scripts/local_backend.py start
adb -s "$device" reverse tcp:8080 tcp:8080

installed=$(adb -s "$device" shell dumpsys package cn.kelance.bojian | sed -n 's/.*versionCode=\([0-9]*\).*/\1/p' | head -1)
build_number=${BUILD_NUMBER:-$(date +%Y%m%d)01}
if [ -n "$installed" ] && [ "$installed" -ge "$build_number" ]; then
  build_number=$((installed + 1))
fi
release_dir="$PWD/artifacts/android/local-$build_number"
mkdir -p "$release_dir/symbols"
"${FLUTTER_BIN:-flutter}" build apk --release --target-platform android-arm64 \
  --build-name=1.0.0-local --build-number="$build_number" \
  --dart-define=BOJIAN_ENV=local \
  --dart-define=BOJIAN_API_BASE_URL=http://127.0.0.1:8080/api/v1 \
  --split-debug-info="$release_dir/symbols" >"$release_dir/build.log" 2>&1 || {
    tail -60 "$release_dir/build.log"
    exit 1
  }
cp build/app/outputs/flutter-apk/app-release.apk "$release_dir/bojian-local.apk"
adb -s "$device" install -r "$release_dir/bojian-local.apk"
adb -s "$device" shell am force-stop cn.kelance.bojian
adb -s "$device" shell am start -n cn.kelance.bojian/.MainActivity
printf '已安装本地测试版 1.0.0-local+%s，待人工测试。\n保持 USB 连接；重连后执行 adb -s %s reverse tcp:8080 tcp:8080\n产物：%s\n' "$build_number" "$device" "$release_dir"

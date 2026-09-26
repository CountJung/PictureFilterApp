#!/bin/bash

set -euo pipefail
source "$(dirname "$0")/lib.sh"
require_xcode_project
require_tool python3

device_id="$(simulator_udid)" || fail "시뮬레이터 이름 또는 ID를 확인하세요."
xcrun simctl boot "$device_id" 2>/dev/null || true
xcrun simctl bootstatus "$device_id" -b
open -a Simulator

xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "platform=iOS Simulator,id=$device_id" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -quiet \
    build

app_path="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION-iphonesimulator/PictureFilterApp.app"
[[ -d "$app_path" ]] || fail "빌드 앱을 찾을 수 없습니다: $app_path"
installed=false
for attempt in 1 2 3; do
    if xcrun simctl install "$device_id" "$app_path"; then
        installed=true
        break
    fi
    printf '시뮬레이터 설치 연결 재시도 (%s/3)\n' "$attempt" >&2
    sleep 2
done
[[ "$installed" == true ]] || fail "시뮬레이터에 앱을 설치하지 못했습니다. Simulator 앱과 대상 기기의 상태를 확인하세요."
xcrun simctl launch "$device_id" "$BUNDLE_ID"

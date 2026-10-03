#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$PROJECT_ROOT/PictureFilterApp.xcodeproj"
SCHEME="${IOS_SCHEME:-PictureFilterApp}"
CONFIGURATION="${IOS_CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${IOS_DERIVED_DATA_PATH:-$PROJECT_ROOT/.build/DerivedData}"
SIMULATOR_NAME="${IOS_SIMULATOR_NAME:-iPhone 17 Pro}"
BUNDLE_ID="${IOS_BUNDLE_ID:-com.local.PictureFilterApp}"

fail() {
    printf '오류: %s\n' "$*" >&2
    exit 1
}

require_tool() {
    command -v "$1" >/dev/null 2>&1 || fail "필요한 도구를 찾을 수 없습니다: $1"
}

require_xcode_project() {
    [[ -d "$PROJECT_PATH" ]] || fail "Xcode 프로젝트가 없습니다: $PROJECT_PATH"
    require_tool xcodebuild
    require_tool xcrun
    xcodebuild -version >/dev/null || fail "Xcode를 사용할 수 없습니다. Xcode 설치와 xcode-select 경로를 확인하세요."
}

simulator_udid() {
    require_tool python3
    xcrun simctl list devices available -j | python3 "$PROJECT_ROOT/scripts/select-simulator.py" \
        --name "$SIMULATOR_NAME" \
        --udid "${IOS_SIMULATOR_UDID:-}" \
        --runtime "${IOS_SIMULATOR_RUNTIME:-}"
}

xcode_destination() {
    local device_id
    device_id="$(simulator_udid)" || return 1
    printf 'platform=iOS Simulator,id=%s' "$device_id"
}

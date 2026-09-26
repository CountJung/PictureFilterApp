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
    local requested="${IOS_SIMULATOR_UDID:-$SIMULATOR_NAME}"
    xcrun simctl list devices available -j | python3 -c '
import json, sys
requested = sys.argv[1]
devices = [d for group in json.load(sys.stdin)["devices"].values() for d in group]
matches = [d for d in devices if d.get("udid") == requested or d.get("name") == requested]
if len(matches) != 1:
    print(f"시뮬레이터를 하나로 특정할 수 없습니다: {requested}", file=sys.stderr)
    print("사용 가능한 iPhone: " + ", ".join(d["name"] for d in devices if d.get("isAvailable") and d["name"].startswith("iPhone ")), file=sys.stderr)
    sys.exit(1)
print(matches[0]["udid"])
' "$requested"
}

xcode_destination() {
    if [[ -n "${IOS_SIMULATOR_UDID:-}" ]]; then
        printf 'platform=iOS Simulator,id=%s' "$IOS_SIMULATOR_UDID"
    else
        printf 'platform=iOS Simulator,name=%s' "$SIMULATOR_NAME"
    fi
}

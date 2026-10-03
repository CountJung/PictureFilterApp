#!/bin/bash

set -euo pipefail
source "$(dirname "$0")/lib.sh"
require_xcode_project

destination="$(xcode_destination)" || fail "시뮬레이터 선택에 실패했습니다."

xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$destination" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -quiet \
    build

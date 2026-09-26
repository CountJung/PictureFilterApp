#!/bin/bash

set -euo pipefail
source "$(dirname "$0")/lib.sh"
require_xcode_project

xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$(xcode_destination)" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -parallel-testing-enabled NO \
    -quiet \
    "$@" \
    test

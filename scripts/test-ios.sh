#!/bin/bash

set -euo pipefail
source "$(dirname "$0")/lib.sh"
require_xcode_project

profile="${IOS_TEST_PROFILE:-simulator}"
profile_args=()
device_tests=(
    PictureFilterAppTests/EditorModelTests/testEditorDetectsMultiplePeopleInSyntheticImage
    PictureFilterAppTests/FilterRendererTests/testExpressiveStylesKeepGeneratedPortraitFaceDetectable
    PictureFilterAppTests/FilterRendererTests/testSyntheticPortraitFixtureExercisesSkinSmoothingRenderPath
    PictureFilterAppTests/FilterRendererTests/testPersonSelectionSmoothsOnlySelectedSyntheticPortrait
    PictureFilterAppTests/FilterRendererTests/testPortraitLightChangesOnlySelectedSyntheticFace
    PictureFilterAppTests/FilterRendererTests/testBothPeopleKeepTheirEditsAcrossSelectionInPreviewAndExport
    PictureFilterAppTests/FilterRendererTests/testIndividualResetRestoresOnlyThatPersonDespiteNonzeroGlobalStrength
    PictureFilterAppTests/FilterRendererTests/testBackgroundBlurUsesOnDevicePersonMask
    PictureFilterAppTests/FilterRendererTests/testRepeatedHighResolutionPreviewAndOutputRecordsSpeedAndThermalState
)
case "$profile" in
    simulator)
        destination="$(xcode_destination)" || fail "시뮬레이터 선택에 실패했습니다."
        for test_id in "${device_tests[@]}"; do
            printf '미실행 (실기기 전용): %s\n' "$test_id" >&2
            profile_args+=("-skip-testing:$test_id")
        done
        ;;
    device)
        [[ -n "${IOS_DEVICE_UDID:-}" ]] || fail "device 프로필에는 IOS_DEVICE_UDID가 필요합니다."
        destination="platform=iOS,id=$IOS_DEVICE_UDID"
        for test_id in "${device_tests[@]}"; do
            profile_args+=("-only-testing:$test_id")
        done
        printf '실기기 Vision/성능 테스트: %s (실제 카메라 수동 수용 검증은 별도)\n' "$IOS_DEVICE_UDID" >&2
        ;;
    *) fail "IOS_TEST_PROFILE은 simulator 또는 device여야 합니다." ;;
esac

xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$destination" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -parallel-testing-enabled NO \
    -quiet \
    "${profile_args[@]}" \
    "$@" \
    test

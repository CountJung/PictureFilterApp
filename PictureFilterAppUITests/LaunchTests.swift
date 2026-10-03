import XCTest

final class LaunchTests: XCTestCase {
    func testStartCameraWithoutSampleRetakeCompareAndSave() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-camera"]
        app.launch()
        app.buttons["start-camera"].tap()
        XCTAssertTrue(app.buttons["cameraShutter"].waitForExistence(timeout: 10))
        app.buttons["cameraZoom-6.0"].tap()
        app.buttons["cameraShutter"].tap()
        XCTAssertTrue(app.images["imagePreview"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["filterStatus"].label, "선택: 화사한 인물")
        app.buttons["filter-sepia"].tap()
        app.buttons["capturePhoto"].tap()
        XCTAssertTrue(app.buttons["cameraShutter"].waitForExistence(timeout: 10))
        app.buttons["cameraShutter"].tap()
        XCTAssertTrue(app.images["imagePreview"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["filterStatus"].label, "선택: 세피아")
        app.staticTexts["compareOriginal"].press(forDuration: 0.5)
        let export = app.buttons["내보내기"]
        for _ in 0..<10 where !export.isHittable { app.swipeUp() }
        export.tap()
        app.buttons["사진 앱에 저장"].tap()
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 2) {
            alert.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'allow' OR label CONTAINS[c] '허용' OR label CONTAINS[c] '추가'")).firstMatch.tap()
        }
        let status = app.staticTexts["saveStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "label CONTAINS %@", "사진 앱에 저장했습니다"), evaluatedWith: status)
        waitForExpectations(timeout: 15)
    }

    func testStartLibraryWithoutSampleOpensPicker() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["start-library"].tap()
        XCTAssertTrue(app.navigationBars["사진"].waitForExistence(timeout: 10) || app.buttons["취소"].exists || app.buttons["Cancel"].exists)
    }

    func testBrightPortraitControlsCompareResetAndSave() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["start-sample-landscape"].tap()
        XCTAssertTrue(app.images["imagePreview"].waitForExistence(timeout: 10))
        app.buttons["filter-brightPortrait"].tap()
        XCTAssertEqual(app.staticTexts["filterStatus"].label, "선택: 화사한 인물")
        for identifier in ["portraitBrightnessSlider", "portraitWarmthSlider"] {
            let slider = app.sliders[identifier]
            for _ in 0..<6 where !slider.isHittable { app.swipeUp() }
            XCTAssertTrue(slider.isEnabled)
            slider.adjust(toNormalizedSliderPosition: 0.8)
        }
        let guidance = app.staticTexts["brightPortraitGuidance"]
        XCTAssertTrue(guidance.exists)
        let compare = app.staticTexts["compareOriginal"]
        for _ in 0..<8 where !compare.isHittable { app.swipeDown() }
        compare.press(forDuration: 0.5)
        XCTAssertEqual(app.staticTexts["filterStatus"].label, "선택: 화사한 인물")
        let export = app.buttons["내보내기"]
        for _ in 0..<12 where !export.isHittable { app.swipeUp() }
        export.tap()
        app.buttons["사진 앱에 저장"].tap()
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 2) {
            alert.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'allow' OR label CONTAINS[c] '허용' OR label CONTAINS[c] '추가'")).firstMatch.tap()
        }
        let status = app.staticTexts["saveStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        let saved = NSPredicate(format: "label CONTAINS %@", "사진 앱에 저장했습니다")
        expectation(for: saved, evaluatedWith: status)
        waitForExpectations(timeout: 15)
        let reset = app.buttons["초기화"]
        for _ in 0..<12 where !reset.isHittable { app.swipeUp() }
        reset.tap()
        XCTAssertFalse(app.sliders["portraitBrightnessSlider"].exists)
        XCTAssertEqual(app.staticTexts["filterStatus"].label, "선택: 원본")
    }

    func testDedicatedCameraCaptureAndCancelWithSimulatorStandIn() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-camera"]
        app.launch()
        app.buttons["start-sample-portrait"].tap()
        XCTAssertTrue(app.images["imagePreview"].waitForExistence(timeout: 10))
        app.buttons["capturePhoto"].tap()
        XCTAssertTrue(app.buttons["cameraShutter"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["cameraZoomValue"].label, "1.0×")
        app.buttons["cameraZoom-6.0"].tap()
        XCTAssertTrue(app.staticTexts["cameraZoomValue"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["cameraZoomValue"].label, "3.0×")
        app.buttons["cameraSwitch"].tap()
        XCTAssertTrue(app.staticTexts["cameraFacing"].label.contains("전면"))
        XCTAssertEqual(app.staticTexts["cameraZoomValue"].label, "1.0×")
        XCTAssertFalse(app.buttons["cameraZoom-6.0"].exists)
        app.sliders["cameraZoomSlider"].adjust(toNormalizedSliderPosition: 0.5)
        XCTAssertFalse(app.segmentedControls["cameraFlash"].exists)
        app.sliders["cameraExposure"].adjust(toNormalizedSliderPosition: 0.7)
        app.buttons["cameraShutter"].tap()
        let title = app.staticTexts["sampleTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "카메라 사진")
        XCTAssertTrue(app.images["imagePreview"].exists)
        app.buttons["filter-brightPortrait"].tap()
        app.buttons["capturePhoto"].tap()
        XCTAssertTrue(app.buttons["cameraCancel"].waitForExistence(timeout: 10))
        app.buttons["cameraCancel"].tap()
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "카메라 사진")
        XCTAssertEqual(app.staticTexts["filterStatus"].label, "선택: 화사한 인물")
    }

    func testLaunchShowsWelcomeScreen() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["welcomeTitle"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars["PictureFilterApp"].exists)
    }

    func testSampleSelectionChangeAndReturn() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["start-sample-landscape"].tap()
        XCTAssertTrue(app.images["imagePreview"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["sampleTitle"].label, "가로 색상표")
        app.buttons["changeSample"].tap()
        app.buttons["세로 색상표"].tap()
        XCTAssertTrue(app.images["imagePreview"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["sampleTitle"].label, "세로 색상표")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["welcomeTitle"].waitForExistence(timeout: 5))
        app.buttons["start-sample-portrait"].tap()
        XCTAssertTrue(app.images["imagePreview"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["sampleTitle"].label, "세로 색상표")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testFilterControlsAndReset() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["start-sample-landscape"].tap()
        XCTAssertTrue(app.images["imagePreview"].waitForExistence(timeout: 10))
        app.buttons["filter-sepia"].tap()
        XCTAssertEqual(app.staticTexts["filterStatus"].label, "선택: 세피아")
        app.sliders["intensitySlider"].adjust(toNormalizedSliderPosition: 1)
        app.staticTexts["compareOriginal"].press(forDuration: 0.5)
        XCTAssertEqual(app.staticTexts["filterStatus"].label, "선택: 세피아")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["초기화"].tap()
        XCTAssertEqual(app.staticTexts["filterStatus"].label, "선택: 원본")
        XCTAssertFalse(app.sliders["intensitySlider"].isEnabled)
    }

    func testExpressiveStylePresetsAreVisibleAndSelectable() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["start-sample-portrait"].tap()
        XCTAssertTrue(app.images["imagePreview"].waitForExistence(timeout: 10))

        for style in ["softFilm", "goldenHour", "cinematic", "vivid"] {
            XCTAssertTrue(app.buttons["filter-\(style)"].exists)
        }
        app.buttons["filter-goldenHour"].tap()
        XCTAssertEqual(app.staticTexts["filterStatus"].label, "선택: 골든아워")

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "PF-023-expressive-style-presets"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testSystemPhotoPickerIsAvailableWithoutAConnectedPhone() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["start-sample-landscape"].tap()
        XCTAssertTrue(app.images["imagePreview"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["pickPhoto"].exists)
        XCTAssertTrue(app.buttons["capturePhoto"].exists)
        XCTAssertTrue(app.sliders["skinSmoothingSlider"].exists)
        XCTAssertTrue(app.sliders["portraitLightSlider"].exists)
        XCTAssertTrue(app.sliders["backgroundBlurSlider"].exists)
    }

    func testPortraitControlKeepsOriginalWhenNoFaceIsDetected() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-no-faces"]
        app.launch()
        app.buttons["start-sample-landscape"].tap()
        XCTAssertTrue(app.images["imagePreview"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["인물을 찾지 못하면 원본을 유지합니다."].waitForExistence(timeout: 10))
        XCTAssertFalse(app.pickers["skinFacePicker"].exists)
        XCTAssertTrue(app.sliders["skinSmoothingSlider"].exists)
        XCTAssertFalse(app.sliders["portraitLightSlider"].isEnabled)
        XCTAssertTrue(app.sliders["backgroundBlurSlider"].isEnabled)
    }

    func testFailedFaceAnalysisIsDistinctAndOffersRetry() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-face-failure"]
        app.launch()
        app.buttons["start-sample-landscape"].tap()
        XCTAssertTrue(app.images["imagePreview"].waitForExistence(timeout: 10))
        let retry = app.buttons["retryFaceAnalysis"]
        XCTAssertTrue(retry.waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["인물을 찾지 못하면 원본을 유지합니다."].exists)
        for _ in 0..<8 where !retry.isHittable { app.swipeUp() }
        retry.tap()
        XCTAssertTrue(retry.waitForExistence(timeout: 10))
        XCTAssertFalse(app.sliders["portraitLightSlider"].isEnabled)
    }

    func testCameraReportsUnavailableOnSimulator() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["start-sample-landscape"].tap()
        XCTAssertTrue(app.buttons["capturePhoto"].waitForExistence(timeout: 10))
        app.buttons["capturePhoto"].tap()
        XCTAssertTrue(app.staticTexts["카메라를 사용할 수 없습니다"].waitForExistence(timeout: 5))
    }

    func testFileImportAndExportActionsAreAvailable() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["start-sample-landscape"].tap()
        XCTAssertTrue(app.images["imagePreview"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["openImageFile"].exists)
        app.buttons["내보내기"].tap()
        XCTAssertTrue(app.buttons["파일로 저장"].exists)
        XCTAssertTrue(app.buttons["사진 앱에 저장"].exists)
    }

    func testSavingEditedPhotoInSimulatorPhotoLibrary() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["start-sample-landscape"].tap()
        XCTAssertTrue(app.images["imagePreview"].waitForExistence(timeout: 10))
        app.buttons["filter-sepia"].tap()
        XCTAssertEqual(app.staticTexts["filterStatus"].label, "선택: 세피아")
        app.buttons["내보내기"].tap()
        app.buttons["사진 앱에 저장"].tap()

        let permissionAlert = app.alerts.firstMatch
        if permissionAlert.waitForExistence(timeout: 3) {
            let allowButton = permissionAlert.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'allow' OR label CONTAINS[c] '허용' OR label CONTAINS[c] '추가'" )).firstMatch
            XCTAssertTrue(allowButton.waitForExistence(timeout: 3))
            allowButton.tap()
        }
        XCTAssertTrue(app.staticTexts["saveStatus"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["saveStatus"].label.contains("사진 앱에 저장했습니다"))
    }

    func testPhotoPickerLoadsMostRecentSavedLibraryImage() {
        let app = XCUIApplication()
        app.launch()
        let startButton = app.buttons["start-sample-landscape"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10))
        startButton.tap()
        XCTAssertTrue(app.images["imagePreview"].waitForExistence(timeout: 10))
        app.buttons["pickPhoto"].tap()

        let newestPhoto = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(newestPhoto.waitForExistence(timeout: 10), "The photo saved by PF-018 should be available")
        newestPhoto.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        XCTAssertTrue(app.staticTexts["sampleTitle"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["sampleTitle"].label, "선택한 사진")
        XCTAssertTrue(app.images["imagePreview"].exists)
    }

    func testDeniedPhotoSaveOffersSettingsAndRetry() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-photo-save-denied"]
        app.launch()
        app.buttons["start-sample-landscape"].tap()
        XCTAssertTrue(app.images["imagePreview"].waitForExistence(timeout: 10))
        app.buttons["내보내기"].tap()
        app.buttons["사진 앱에 저장"].tap()
        XCTAssertTrue(app.staticTexts["saveStatus"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["saveStatus"].label.contains("권한이 없습니다"))
        XCTAssertTrue(app.buttons["openPhotoSettings"].exists)
        XCTAssertTrue(app.buttons["retrySave"].exists)
    }

    func testActualPhotoPermissionCanBeDeniedAndRestored() {
        let app = XCUIApplication()
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        var permissionChanged = false
        var permissionRestored = false

        func openPhotoPermissionSettings() -> Bool {
            app.activate()
            let shortcut = app.buttons["openPhotoSettings"]
            if shortcut.exists {
                for _ in 0..<10 where !shortcut.isHittable { app.swipeDown() }
                shortcut.tap()
            } else { settings.activate() }
            guard settings.wait(for: .runningForeground, timeout: 10) else { return false }
            let addOnly = settings.descendants(matching: .any).matching(NSPredicate(format: "label == '사진 추가만' OR label == 'Add Photos Only'")).firstMatch
            if addOnly.waitForExistence(timeout: 2) { return true }
            let photos = settings.descendants(matching: .any).matching(identifier: "PHOTOS").firstMatch
            if !photos.waitForExistence(timeout: 3) {
                let closeSearch = settings.buttons.matching(NSPredicate(format: "label == '닫기' OR label == 'Close' OR label == 'Cancel' OR label == '취소'")).firstMatch
                if settings.searchFields.firstMatch.exists, closeSearch.exists, closeSearch.isHittable {
                    closeSearch.tap()
                }
                // The simulator may open Settings at its root. Navigate the
                // installed apps list instead of relying on global search indexing.
                let apps = settings.buttons.matching(NSPredicate(format: "label == '앱' OR label == 'Apps'")).firstMatch
                for _ in 0..<10 where !apps.isHittable { settings.swipeUp() }
                guard apps.exists, apps.isHittable else {
                    add(XCTAttachment(string: settings.debugDescription)); return false
                }
                apps.tap()
                let search = settings.searchFields.firstMatch
                if search.waitForExistence(timeout: 3) {
                    search.tap()
                    search.typeText("PictureFilterApp")
                }
                let row = settings.descendants(matching: .any)
                    .matching(NSPredicate(format: "label == 'PictureFilterApp'")).firstMatch
                for _ in 0..<10 where !row.isHittable { settings.swipeUp() }
                guard row.exists, row.isHittable else {
                    add(XCTAttachment(string: settings.debugDescription)); return false
                }
                row.tap()
            }
            guard photos.waitForExistence(timeout: 5) else {
                add(XCTAttachment(string: settings.debugDescription)); return false
            }
            photos.tap()
            return true
        }

        func choosePhotoPermission(_ korean: String, _ english: String) -> Bool {
            let option = settings.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@ OR label == %@", korean, english)).firstMatch
            guard option.waitForExistence(timeout: 5), option.isHittable else { return false }
            option.tap()
            return true
        }

        func savePhoto() {
            app.buttons["start-sample-landscape"].tap()
            let export = app.buttons["내보내기"]
            for _ in 0..<10 where !export.isHittable { app.swipeUp() }
            export.tap()
            app.buttons["사진 앱에 저장"].tap()
        }

        defer {
            if permissionChanged && !permissionRestored {
                if openPhotoPermissionSettings() {
                    permissionRestored = choosePhotoPermission("사진 추가만", "Add Photos Only")
                }
                XCTAssertTrue(permissionRestored, "Restore Photos access after the test")
            }
        }

        // Request actual authorization before using the denied-service shortcut;
        // a fresh install otherwise has no Photos permission entry in Settings.
        app.launch()
        savePhoto()
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 2) {
            alert.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'allow' OR label CONTAINS[c] '허용' OR label CONTAINS[c] '추가'")).firstMatch.tap()
        }
        XCTAssertTrue(app.staticTexts["saveStatus"].waitForExistence(timeout: 10))
        app.terminate()
        app.launchArguments = ["--ui-test-photo-save-denied"]
        app.launch()
        savePhoto()
        XCTAssertTrue(app.buttons["openPhotoSettings"].waitForExistence(timeout: 10))
        guard openPhotoPermissionSettings() else { XCTFail("Open app Photos settings"); return }
        guard choosePhotoPermission("안 함", "None") else { XCTFail("Choose None"); return }
        permissionChanged = true

        app.terminate()
        app.launchArguments = []
        app.launch()
        savePhoto()
        XCTAssertTrue(app.staticTexts["saveStatus"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["saveStatus"].label.contains("권한이 없습니다"))
        guard openPhotoPermissionSettings() else { XCTFail("Reopen app Photos settings"); return }
        guard choosePhotoPermission("사진 추가만", "Add Photos Only") else { XCTFail("Restore Add Only"); return }
        permissionRestored = true

        app.terminate()
        app.launch()
        savePhoto()
        let status = app.staticTexts["saveStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "label CONTAINS %@", "사진 앱에 저장했습니다"), evaluatedWith: status)
        waitForExpectations(timeout: 15)
    }

    func testPhotoSaveFailureCanBeRetried() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-photo-save-fails"]
        app.launch()
        app.buttons["start-sample-landscape"].tap()
        XCTAssertTrue(app.images["imagePreview"].waitForExistence(timeout: 10))
        app.buttons["내보내기"].tap()
        app.buttons["사진 앱에 저장"].tap()
        XCTAssertTrue(app.buttons["retrySave"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["openPhotoSettings"].exists)
        app.buttons["retrySave"].tap()
        XCTAssertTrue(app.buttons["retrySave"].waitForExistence(timeout: 10))
    }

    func testSaveControlsDisableWhilePhotoSaveIsInProgress() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-photo-save-slow"]
        app.launch()
        app.buttons["start-sample-landscape"].tap()
        XCTAssertTrue(app.images["imagePreview"].waitForExistence(timeout: 10))
        app.buttons["내보내기"].tap()
        app.buttons["사진 앱에 저장"].tap()
        XCTAssertTrue(app.staticTexts["saveStatus"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["saveStatus"].label.contains("저장 중"))
        XCTAssertFalse(app.buttons["내보내기"].isEnabled)
        let completion = expectation(for: NSPredicate(format: "label CONTAINS %@", "사진 앱에 저장했습니다"),
                                    evaluatedWith: app.staticTexts["saveStatus"])
        wait(for: [completion], timeout: 6)
    }

    func testEditorRemainsAccessibleAtLargestDynamicType() {
        let app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let startButton = app.buttons["start-sample-landscape"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10))
        startButton.tap()

        XCTAssertTrue(app.images["imagePreview"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["pickPhoto"].exists)
        XCTAssertTrue(app.buttons["내보내기"].exists)
        XCTAssertTrue(app.buttons["filter-sepia"].exists)
        XCTAssertTrue(app.sliders["intensitySlider"].exists)

        app.swipeUp()
        XCTAssertTrue(app.buttons["openImageFile"].exists)
        app.buttons["filter-sepia"].tap()
        XCTAssertEqual(app.staticTexts["filterStatus"].label, "선택: 세피아")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "PF-015-largest-dynamic-type"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}

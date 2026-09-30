import XCTest

final class LaunchTests: XCTestCase {
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
        app.launch()
        app.buttons["start-sample-landscape"].tap()
        XCTAssertTrue(app.images["imagePreview"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["인물을 찾지 못하면 원본을 유지합니다."].waitForExistence(timeout: 10))
        XCTAssertFalse(app.pickers["skinFacePicker"].exists)
        XCTAssertTrue(app.sliders["skinSmoothingSlider"].exists)
        XCTAssertFalse(app.sliders["portraitLightSlider"].isEnabled)
        XCTAssertTrue(app.sliders["backgroundBlurSlider"].isEnabled)
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
        var permissionRestored = false

        func openPhotoPermissionSettings() {
            app.activate()
            let shortcut = app.buttons["openPhotoSettings"]
            if shortcut.exists {
                shortcut.tap()
            } else {
                settings.activate()
            }
            XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 10))
            let photosSettings = settings.descendants(matching: .any).matching(identifier: "PHOTOS").firstMatch
            if photosSettings.waitForExistence(timeout: 5) {
                photosSettings.tap()
            }
        }

        func choosePhotoPermission(_ label: String) -> Bool {
            let option = settings.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@", label)).firstMatch
            guard option.waitForExistence(timeout: 5), option.isHittable else { return false }
            option.tap()
            return true
        }

        defer {
            if !permissionRestored {
                openPhotoPermissionSettings()
                permissionRestored = choosePhotoPermission("사진 추가만")
            }
        }

        app.launchArguments = ["--ui-test-photo-save-denied"]
        app.launch()
        app.buttons["start-sample-landscape"].tap()
        app.buttons["내보내기"].tap()
        app.buttons["사진 앱에 저장"].tap()
        XCTAssertTrue(app.buttons["openPhotoSettings"].waitForExistence(timeout: 10))
        app.buttons["openPhotoSettings"].tap()

        XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 10))
        let photosSettings = settings.descendants(matching: .any).matching(identifier: "PHOTOS").firstMatch
        XCTAssertTrue(photosSettings.waitForExistence(timeout: 5))
        photosSettings.tap()
        XCTAssertTrue(choosePhotoPermission("안 함"), "The iOS Photos permission page should offer None")

        app.terminate()
        app.launchArguments = []
        app.launch()
        app.buttons["start-sample-landscape"].tap()
        app.buttons["내보내기"].tap()
        app.buttons["사진 앱에 저장"].tap()
        XCTAssertTrue(app.staticTexts["saveStatus"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["saveStatus"].label.contains("권한이 없습니다"))
        XCTAssertTrue(app.buttons["openPhotoSettings"].exists)

        openPhotoPermissionSettings()
        XCTAssertTrue(choosePhotoPermission("사진 추가만"), "Restore the original Add Only Photos permission")

        app.terminate()
        app.launchArguments = []
        app.launch()
        app.buttons["start-sample-landscape"].tap()
        app.buttons["내보내기"].tap()
        app.buttons["사진 앱에 저장"].tap()
        XCTAssertTrue(app.staticTexts["saveStatus"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["saveStatus"].label.contains("사진 앱에 저장했습니다"))
        permissionRestored = true
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

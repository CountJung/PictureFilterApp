import XCTest
import UIKit
@testable import PictureFilterApp

private actor DeferredAnalysisRenderer: PreviewRendering, FaceCounting {
    private var pending: [Data: CheckedContinuation<FaceAnalysisState, Never>] = [:]
    func render(_ data: Data, settings: EditSettings, maxDimension: Int) async throws -> Data { data }
    func faceCount(in data: Data) async -> Int { 0 }
    func backgroundAnalysis(in data: Data) async -> FaceAnalysisState { .idle }
    func faceAnalysis(in data: Data, retry: Bool) async -> FaceAnalysisState {
        await withCheckedContinuation { pending[data] = $0 }
    }
    func isWaiting(_ data: Data) -> Bool { pending[data] != nil }
    func finish(_ data: Data, _ state: FaceAnalysisState) { pending.removeValue(forKey: data)?.resume(returning: state) }
}

@MainActor
final class EditorModelTests: XCTestCase {
    func testAnalysisLoadingFailureRetryAndStalePhotoResults() async throws {
        let renderer = DeferredAnalysisRenderer()
        let model = EditorModel(sample: SampleImage.catalog[0], renderer: renderer)
        let first = try await BundleSampleInput().load(SampleImage.catalog[0])
        let second = try await BundleSampleInput().load(SampleImage.catalog[1])
        func waitForAnalysis(_ data: Data) async throws {
            for _ in 0..<100 {
                if await renderer.isWaiting(data) { return }
                try await Task.sleep(for: .milliseconds(10))
            }
            XCTFail("Analysis did not start")
        }
        model.load(first, title: "first")
        XCTAssertEqual(model.faceAnalysis, .analyzing)
        try await waitForAnalysis(first)
        model.load(second, title: "second")
        try await waitForAnalysis(second)
        await renderer.finish(first, .ready(4))
        await Task.yield()
        XCTAssertEqual(model.faceAnalysis, .analyzing)
        XCTAssertEqual(model.detectedFaceCount, 0)
        await renderer.finish(second, .failed)
        for _ in 0..<100 where model.faceAnalysis == .analyzing { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(model.faceAnalysis, .failed)
        model.retryFaceAnalysis()
        XCTAssertEqual(model.faceAnalysis, .analyzing)
        try await waitForAnalysis(second)
        await renderer.finish(second, .ready(0))
        for _ in 0..<100 where model.faceAnalysis == .analyzing { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(model.faceAnalysis, .ready(0))
        XCTAssertEqual(model.originalData, second)
    }

    func testFirstCaptureUsesBrightPortraitAndRetakePreservesOnlyLook() async throws {
        let model = EditorModel(sample: SampleImage.catalog[0])
        let first = try await BundleSampleInput().load(SampleImage.catalog[0])
        model.loadCapture(first)
        XCTAssertEqual(model.originalData, first)
        XCTAssertEqual(model.settings.filter, .brightPortrait)
        model.setIntensity(0.8)
        model.setPortraitBrightness(0.7)
        model.setPortraitWarmth(-0.2)
        model.setSkinSmoothing(0.6)
        model.setPortraitLight(0.8)
        model.setBackgroundBlur(0.9)
        model.selectSkinFace(0)
        model.setSkinSmoothing(0.9)
        let second = try await BundleSampleInput().load(SampleImage.catalog[1])
        model.loadCapture(second)
        XCTAssertEqual(model.originalData, second)
        XCTAssertEqual(model.settings.filter, .brightPortrait)
        XCTAssertEqual(model.settings.intensity, 0.8)
        XCTAssertEqual(model.settings.portraitBrightness, 0.7)
        XCTAssertEqual(model.settings.portraitWarmth, -0.2)
        XCTAssertEqual(model.settings.skinSmoothing, 0)
        XCTAssertEqual(model.settings.portraitLight, 0)
        XCTAssertEqual(model.settings.backgroundBlur, 0)
        XCTAssertTrue(model.settings.faceSkinSmoothing.isEmpty)
        XCTAssertTrue(model.settings.facePortraitLight.isEmpty)
        XCTAssertNil(model.settings.selectedSkinFaceIndex)
        model.selectFilter(.sepia)
        model.loadCapture(first)
        XCTAssertEqual(model.settings.filter, .sepia)
    }

    func testInvalidRetakePreservesPhotoAndAllSettings() async throws {
        let model = EditorModel(sample: SampleImage.catalog[0])
        let data = try await BundleSampleInput().load(SampleImage.catalog[0])
        model.loadCapture(data)
        model.setSkinSmoothing(0.4)
        let previous = model.settings
        model.loadCapture(Data([0, 1, 2]))
        XCTAssertEqual(model.originalData, data)
        XCTAssertEqual(model.settings, previous)
        XCTAssertTrue(model.canEdit)
        XCTAssertNotNil(model.renderError)
    }

    func testReplacementFailureKeepsEditsAndSuccessfulReplacementResetsThem() async throws {
        let model = EditorModel(sample: SampleImage.catalog[0])
        let data = try await BundleSampleInput().load(SampleImage.catalog[0])
        model.loadCapture(data)
        model.setIntensity(0.9)
        let settings = model.settings
        model.replacePhoto(Data(), title: "broken")
        XCTAssertEqual(model.originalData, data)
        XCTAssertEqual(model.settings, settings)
        model.reportReplacementFailure(ImageServiceError.inputUnavailable)
        XCTAssertTrue(model.canEdit)
        XCTAssertEqual(model.originalData, data)
        let next = try await BundleSampleInput().load(SampleImage.catalog[1])
        model.replacePhoto(next, title: "new")
        XCTAssertEqual(model.originalData, next)
        XCTAssertEqual(model.settings, EditSettings())
        XCTAssertNil(model.renderError)
    }

    func testBrightPortraitControlsClampResetAndDoNotAlterOriginal() async throws {
        let model = EditorModel(sample: SampleImage.catalog[0])
        await model.load(SampleImage.catalog[0], using: BundleSampleInput())
        let original = model.originalData
        model.selectFilter(.brightPortrait)
        XCTAssertEqual(model.settings.intensity, 0.5)
        XCTAssertEqual(model.settings.portraitBrightness, 0.65)
        XCTAssertEqual(model.settings.portraitWarmth, 0.15)
        XCTAssertEqual(model.settings.skinSmoothing, 0)
        let revision = model.previewRevision
        model.setPortraitBrightness(2)
        model.setPortraitWarmth(-2)
        XCTAssertNotEqual(revision, model.previewRevision)
        XCTAssertEqual(model.settings.portraitBrightness, 1)
        XCTAssertEqual(model.settings.portraitWarmth, -1)
        model.setPortraitBrightness(.nan)
        model.setPortraitWarmth(.infinity)
        XCTAssertEqual(model.settings.portraitBrightness, 1)
        XCTAssertEqual(model.settings.portraitWarmth, -1)
        XCTAssertEqual(model.originalData, original)
        model.reset()
        XCTAssertEqual(model.settings, EditSettings())
        model.selectFilter(.brightPortrait)
        model.setPortraitBrightness(0)
        await model.load(SampleImage.catalog[1], using: BundleSampleInput())
        XCTAssertEqual(model.settings, EditSettings())
    }

    func testResetPreservesOriginalAndRestoresDefaults() async throws {
        let model = EditorModel(sample: SampleImage.catalog[0])
        XCTAssertEqual(model.phase, .idle)
        await model.load(SampleImage.catalog[0], using: BundleSampleInput())
        XCTAssertEqual(model.phase, .ready)
        let original = try XCTUnwrap(model.originalData)
        model.selectFilter(.sepia)
        model.setIntensity(0.8)
        XCTAssertEqual(model.settings.filter, .sepia)
        XCTAssertEqual(model.settings.intensity, 0.8)
        XCTAssertEqual(model.originalData, original)
        model.reset()
        XCTAssertEqual(model.settings, EditSettings())
        XCTAssertEqual(model.originalData, original)
    }

    func testPhotoChangeResetsSettingsAndReplacesOriginal() async throws {
        let model = EditorModel(sample: SampleImage.catalog[0])
        await model.load(SampleImage.catalog[0], using: BundleSampleInput())
        let first = try XCTUnwrap(model.originalData)
        model.selectFilter(.warm)
        model.setIntensity(1)
        await model.load(SampleImage.catalog[1], using: BundleSampleInput())
        XCTAssertEqual(model.sample.id, SampleImage.catalog[1].id)
        XCTAssertNotEqual(model.originalData, first)
        XCTAssertEqual(model.settings, EditSettings())
        XCTAssertEqual(model.phase, .ready)
    }

    func testFailureClearsPreviousPhotoAndRetryRecovers() async {
        let model = EditorModel(sample: SampleImage.catalog[0])
        await model.load(SampleImage.catalog[0], using: BundleSampleInput())
        await model.load(SampleImage.catalog[1], using: FailingImageInput(error: .inputUnavailable))
        XCTAssertEqual(model.phase, .failed(ImageServiceError.inputUnavailable.localizedDescription))
        XCTAssertNil(model.originalData)
        XCTAssertNil(model.originalImage)
        XCTAssertFalse(model.canEdit)
        model.selectFilter(.cool)
        XCTAssertEqual(model.settings, EditSettings())
        await model.load(SampleImage.catalog[1], using: BundleSampleInput())
        XCTAssertEqual(model.phase, .ready)
        XCTAssertNil(model.errorMessage)
    }

    func testIntensityClampsAndRejectsNonFiniteValues() async {
        let model = EditorModel(sample: SampleImage.catalog[0])
        model.setIntensity(1)
        XCTAssertEqual(model.settings.intensity, 0.5)
        await model.load(SampleImage.catalog[0], using: BundleSampleInput())
        model.setIntensity(-5)
        XCTAssertEqual(model.settings.intensity, 0)
        model.setIntensity(5)
        XCTAssertEqual(model.settings.intensity, 1)
        model.setIntensity(.nan)
        model.setIntensity(.infinity)
        XCTAssertEqual(model.settings.intensity, 1)
    }

    func testSkinSmoothingClampsInvalidatesPreviewAndResets() async {
        let model = EditorModel(sample: SampleImage.catalog[0])
        await model.load(SampleImage.catalog[0], using: BundleSampleInput())
        let revision = model.previewRevision
        model.setSkinSmoothing(0.65)
        XCTAssertEqual(model.settings.skinSmoothing, 0.65)
        XCTAssertNotEqual(model.previewRevision, revision)
        model.setSkinSmoothing(4)
        XCTAssertEqual(model.settings.skinSmoothing, 1)
        model.setSkinSmoothing(.nan)
        XCTAssertEqual(model.settings.skinSmoothing, 1)
        model.reset()
        XCTAssertEqual(model.settings.skinSmoothing, 0)
    }

    func testPersonSpecificSmoothingAndRestore() async {
        var settings = EditSettings()
        settings.setSkinSmoothing(0.6)
        settings.selectSkinFace(1)
        settings.setSkinSmoothing(0)
        XCTAssertEqual(settings.skinSmoothing(forFaceAt: 0), 0.6)
        XCTAssertEqual(settings.skinSmoothing(forFaceAt: 1), 0)
        XCTAssertEqual(settings.activeSkinSmoothing, 0)
        settings.resetSelectedSkinSmoothing()
        XCTAssertEqual(settings.skinSmoothing(forFaceAt: 1), 0)
        settings.selectSkinFace(nil)
        settings.setSkinSmoothing(0)
        XCTAssertEqual(settings.skinSmoothing(forFaceAt: 0), 0)
        XCTAssertEqual(settings.skinSmoothing(forFaceAt: 1), 0)
    }

    func testPortraitLightCanBeAdjustedPerPersonAndBackgroundBlurResets() {
        var settings = EditSettings()
        settings.setPortraitLight(0.4)
        settings.selectSkinFace(1)
        settings.setPortraitLight(0.8)
        settings.setBackgroundBlur(2)
        XCTAssertEqual(settings.portraitLight(forFaceAt: 0), 0.4)
        XCTAssertEqual(settings.portraitLight(forFaceAt: 1), 0.8)
        XCTAssertEqual(settings.backgroundBlur, 1)
        settings.resetSelectedPortraitEffects()
        XCTAssertEqual(settings.activePortraitLight, 0)
        settings.setBackgroundBlur(.nan)
        XCTAssertEqual(settings.backgroundBlur, 1)
        settings.selectSkinFace(nil)
        settings.resetSelectedPortraitEffects()
        XCTAssertEqual(settings.portraitLight, 0)
        XCTAssertEqual(settings.facePortraitLight, [:])
        XCTAssertEqual(settings.backgroundBlur, 1)
    }

    func testAllPeopleAdjustmentReplacesOnlyTheCorrespondingIndividualValues() {
        var settings = EditSettings()
        settings.setSkinSmoothing(0.6)
        settings.setPortraitLight(0.4)
        settings.selectSkinFace(0)
        settings.resetSelectedSkinSmoothing()
        settings.resetSelectedPortraitEffects()
        settings.selectSkinFace(1)
        settings.setSkinSmoothing(0.8)
        settings.setPortraitLight(0.9)
        settings.selectSkinFace(nil)
        // Reapplying even the same global value deliberately replaces overrides.
        settings.setSkinSmoothing(0.6)
        XCTAssertEqual(settings.skinSmoothing(forFaceAt: 0), 0.6)
        XCTAssertEqual(settings.skinSmoothing(forFaceAt: 1), 0.6)
        XCTAssertEqual(settings.portraitLight(forFaceAt: 0), 0)
        XCTAssertEqual(settings.portraitLight(forFaceAt: 1), 0.9)
        settings.setPortraitLight(0.4)
        XCTAssertEqual(settings.portraitLight(forFaceAt: 0), 0.4)
        XCTAssertEqual(settings.portraitLight(forFaceAt: 1), 0.4)
        XCTAssertTrue(settings.faceSkinSmoothing.isEmpty)
        XCTAssertTrue(settings.facePortraitLight.isEmpty)
    }

    func testSelectingEditingTargetDoesNotInvalidatePreviewAndResetOnlyChangesTarget() async {
        let model = EditorModel(sample: SampleImage.catalog[0])
        await model.load(SampleImage.catalog[0], using: BundleSampleInput())
        model.setSkinSmoothing(0.6)
        model.setPortraitLight(0.4)
        model.setBackgroundBlur(0.3)
        let revision = model.previewRevision
        model.selectSkinFace(0)
        model.selectSkinFace(1)
        model.selectSkinFace(nil)
        XCTAssertEqual(model.previewRevision, revision)
        model.selectSkinFace(0)
        model.resetSelectedSkinSmoothing()
        model.resetSelectedPortraitEffects()
        XCTAssertNotEqual(model.previewRevision, revision)
        XCTAssertEqual(model.settings.skinSmoothing(forFaceAt: 0), 0)
        XCTAssertEqual(model.settings.portraitLight(forFaceAt: 0), 0)
        XCTAssertEqual(model.settings.skinSmoothing(forFaceAt: 1), 0.6)
        XCTAssertEqual(model.settings.portraitLight(forFaceAt: 1), 0.4)
        XCTAssertEqual(model.settings.backgroundBlur, 0.3)
        model.reset()
        XCTAssertEqual(model.settings, EditSettings())
    }

    func testEditorDetectsMultiplePeopleInSyntheticImage() async throws {
        let url = try XCTUnwrap(Bundle(for: EditorModelTests.self).url(forResource: "synthetic-face", withExtension: "jpg"))
        let face = try XCTUnwrap(UIImage(data: Data(contentsOf: url))?.cgImage)
        let canvas = CGSize(width: 1320, height: 660)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let pair = UIGraphicsImageRenderer(size: canvas, format: format).image { renderer in
            UIColor.darkGray.setFill()
            renderer.fill(CGRect(origin: .zero, size: canvas))
            renderer.cgContext.draw(face, in: CGRect(x: 0, y: 0, width: 620, height: 620))
            renderer.cgContext.draw(face, in: CGRect(x: 700, y: 0, width: 620, height: 620))
        }
        let model = EditorModel(sample: SampleImage.catalog[0])
        model.load(try XCTUnwrap(pair.jpegData(compressionQuality: 1)), title: "합성 인물 두 명")
        for _ in 0..<100 where model.detectedFaceCount != 2 {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(model.detectedFaceCount, 2)
        let revision = model.previewRevision
        model.selectSkinFace(1)
        model.setSkinSmoothing(0.8)
        XCTAssertEqual(model.settings.selectedSkinFaceIndex, 1)
        XCTAssertEqual(model.settings.activeSkinSmoothing, 0.8)
        XCTAssertNotEqual(model.previewRevision, revision)
        model.resetSelectedSkinSmoothing()
        XCTAssertEqual(model.settings.activeSkinSmoothing, 0)
    }

    func testOlderInputCannotOverwriteNewPhoto() async throws {
        let data = try await BundleSampleInput().load(SampleImage.catalog[0])
        let delayed = ControlledInput()
        let model = EditorModel(sample: SampleImage.catalog[0])
        let first = Task { await model.load(SampleImage.catalog[0], using: delayed) }
        await delayed.waitUntilRequested()
        XCTAssertEqual(model.phase, .loading)
        XCTAssertNil(model.originalData)
        await model.load(SampleImage.catalog[1], using: BundleSampleInput())
        let latest = model.originalData
        await delayed.finish(data)
        await first.value
        XCTAssertEqual(model.sample.id, SampleImage.catalog[1].id)
        XCTAssertEqual(model.originalData, latest)
        XCTAssertEqual(model.phase, .ready)
    }

    func testCancellationReturnsToIdleWithoutError() async throws {
        let data = try await BundleSampleInput().load(SampleImage.catalog[0])
        let delayed = ControlledInput()
        let model = EditorModel(sample: SampleImage.catalog[0])
        let request = Task { await model.load(SampleImage.catalog[0], using: delayed) }
        await delayed.waitUntilRequested()
        request.cancel()
        await delayed.finish(data)
        await request.value
        XCTAssertEqual(model.phase, .idle)
        XCTAssertNil(model.originalData)
        XCTAssertNil(model.errorMessage)
    }

    func testPickerDataReplacesSampleAndKeepsImageOrientationMetadata() async throws {
        let data = try await BundleSampleInput().load(SampleImage.catalog[1])
        let model = EditorModel(sample: SampleImage.catalog[0])
        model.load(data, title: "선택한 사진")
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.sample.title, "선택한 사진")
        XCTAssertEqual(model.originalData, data)
        XCTAssertEqual(model.originalImage?.imageOrientation, .up)
    }

    func testPickerInvalidDataBecomesRecoverableInputError() {
        let model = EditorModel(sample: SampleImage.catalog[0])
        model.load(Data("not an image".utf8), title: "선택한 사진")
        XCTAssertEqual(model.phase, .failed(ImageServiceError.invalidImage.localizedDescription))
        XCTAssertNil(model.originalData)
        XCTAssertFalse(model.canEdit)
    }
}

private actor ControlledInput: ImageInputService {
    private var pending: CheckedContinuation<Data, Never>?
    private var started: CheckedContinuation<Void, Never>?

    func load(_ sample: SampleImage) async throws -> Data {
        await withCheckedContinuation { continuation in
            pending = continuation
            started?.resume()
            started = nil
        }
    }

    func waitUntilRequested() async {
        if pending != nil { return }
        await withCheckedContinuation { started = $0 }
    }

    func finish(_ data: Data) {
        pending?.resume(returning: data)
        pending = nil
    }
}

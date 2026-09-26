import XCTest
@testable import PictureFilterApp

@MainActor
final class EditorModelTests: XCTestCase {
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

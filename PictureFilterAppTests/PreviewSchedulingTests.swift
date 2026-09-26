import XCTest
@testable import PictureFilterApp

@MainActor
final class PreviewSchedulingTests: XCTestCase {
    func testLatestRenderWinsEvenWhenOldWorkIgnoresCancellation() async throws {
        let worker = ControlledRenderer()
        let model = EditorModel(sample: SampleImage.catalog[0], renderer: worker, waitForQuiet: {})
        await model.load(SampleImage.catalog[0], using: BundleSampleInput())
        let landscape = try XCTUnwrap(model.originalData)
        let portrait = try await BundleSampleInput().load(SampleImage.catalog[1])
        model.selectFilter(.sepia)
        let first = Task { await model.refreshPreview() }
        await worker.waitForCalls(1)
        model.selectFilter(.cool)
        let last = Task { await model.refreshPreview() }
        await worker.waitForCalls(2)
        await worker.finish(1, result: .success(portrait))
        await last.value
        XCTAssertEqual(model.previewImage?.size.width, 480)
        await worker.finish(0, result: .success(landscape))
        await first.value
        XCTAssertEqual(model.previewImage?.size.width, 480)
        XCTAssertFalse(model.isRendering)
        XCTAssertNil(model.renderError)
    }

    func testPhotoChangeClearsPreviewAndDiscardsOldFailure() async throws {
        let worker = ControlledRenderer()
        let model = EditorModel(sample: SampleImage.catalog[0], renderer: worker, waitForQuiet: {})
        await model.load(SampleImage.catalog[0], using: BundleSampleInput())
        let first = Task { await model.refreshPreview() }
        await worker.waitForCalls(1)
        await model.load(SampleImage.catalog[1], using: BundleSampleInput())
        XCTAssertNil(model.previewImage)
        let last = Task { await model.refreshPreview() }
        await worker.waitForCalls(2)
        await worker.finish(0, result: .failure(ImageServiceError.invalidImage))
        await first.value
        XCTAssertTrue(model.isRendering)
        XCTAssertNil(model.renderError)
        await worker.finish(1, result: .success(try XCTUnwrap(model.originalData)))
        await last.value
        XCTAssertEqual(model.previewImage?.size.width, 480)
    }

    func testBurstOnlySubmitsFinalSettingsAfterQuietWindow() async throws {
        let gate = QuietGate()
        let worker = ControlledRenderer()
        let model = EditorModel(sample: SampleImage.catalog[0], renderer: worker, waitForQuiet: { await gate.pause() })
        await model.load(SampleImage.catalog[0], using: BundleSampleInput())
        model.selectFilter(.sepia)
        let first = Task { await model.refreshPreview() }
        await gate.waitForCalls(1)
        model.setIntensity(0.9)
        let last = Task { await model.refreshPreview() }
        await gate.waitForCalls(2)
        await gate.release(0)
        await first.value
        let before = await worker.count
        XCTAssertEqual(before, 0)
        await gate.release(1)
        await worker.waitForCalls(1)
        let submitted = await worker.settings[0]
        XCTAssertEqual(submitted.intensity, 0.9)
        await worker.finish(0, result: .success(try XCTUnwrap(model.originalData)))
        await last.value
    }

    func testCancellationBeforeRenderDoesNotSubmitOrShowError() async {
        let gate = QuietGate()
        let worker = ControlledRenderer()
        let model = EditorModel(sample: SampleImage.catalog[0], renderer: worker, waitForQuiet: { await gate.pause() })
        await model.load(SampleImage.catalog[0], using: BundleSampleInput())
        let task = Task { await model.refreshPreview() }
        await gate.waitForCalls(1)
        task.cancel()
        await gate.release(0)
        await task.value
        let count = await worker.count
        XCTAssertEqual(count, 0)
        XCTAssertFalse(model.isRendering)
        XCTAssertNil(model.renderError)
    }

    func testIdenticalSettingsDoNotInvalidatePreview() async {
        let model = EditorModel(sample: SampleImage.catalog[0])
        await model.load(SampleImage.catalog[0], using: BundleSampleInput())
        let revision = model.previewRevision
        model.selectFilter(.original)
        model.setIntensity(0.5)
        model.setIntensity(.nan)
        XCTAssertEqual(model.previewRevision, revision)
    }
}

private actor ControlledRenderer: PreviewRendering {
    private var pending: [CheckedContinuation<Data, Error>] = []
    private var observers: [Int: CheckedContinuation<Void, Never>] = [:]
    private(set) var settings: [EditSettings] = []
    var count: Int { pending.count }
    func render(_ data: Data, settings: EditSettings, maxDimension: Int) async throws -> Data {
        self.settings.append(settings)
        return try await withCheckedThrowingContinuation {
            pending.append($0)
            observers.removeValue(forKey: pending.count)?.resume()
        }
    }
    func waitForCalls(_ count: Int) async {
        if pending.count >= count { return }
        await withCheckedContinuation { observers[count] = $0 }
    }
    func finish(_ index: Int, result: Result<Data, Error>) { pending[index].resume(with: result) }
}

private actor QuietGate {
    private var pending: [CheckedContinuation<Void, Never>] = []
    private var observers: [Int: CheckedContinuation<Void, Never>] = [:]
    func pause() async {
        await withCheckedContinuation {
            pending.append($0)
            observers.removeValue(forKey: pending.count)?.resume()
        }
    }
    func waitForCalls(_ count: Int) async {
        if pending.count >= count { return }
        await withCheckedContinuation { observers[count] = $0 }
    }
    func release(_ index: Int) { pending[index].resume() }
}

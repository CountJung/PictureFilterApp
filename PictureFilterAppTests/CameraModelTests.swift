import AVFoundation
import XCTest
@testable import PictureFilterApp

private actor TestCamera: CameraServing {
    nonisolated var session: AVCaptureSession? { nil }
    nonisolated let events: AsyncStream<CameraEvent>
    nonisolated let sink: AsyncStream<CameraEvent>.Continuation
    var state = CameraCapabilities(canSwitch: true, supportsFocus: true, exposureRange: -2...2, flashModes: [.off, .auto, .on])
    var startFailure: CameraFailure?
    var captures = 0
    var stops = 0
    var exposure: Float = 0
    var lastFocus: CGPoint?
    var selectedFlash: CameraFlash?
    private var pending: CheckedContinuation<Data, Error>?
    private var starting: CheckedContinuation<CameraCapabilities, Error>?
    private var holdStart = false

    init(failure: CameraFailure? = nil, holdStart: Bool = false) {
        let stream = AsyncStream<CameraEvent>.makeStream()
        events = stream.stream
        sink = stream.continuation
        startFailure = failure
        self.holdStart = holdStart
    }
    func allow() { startFailure = nil }
    func start() async throws -> CameraCapabilities {
        if let startFailure { throw startFailure }
        if holdStart { return try await withCheckedThrowingContinuation { starting = $0 } }
        return state
    }
    func finishStart() { starting?.resume(returning: state); starting = nil }
    var isStarting: Bool { starting != nil }
    func stop() async { stops += 1 }
    func switchCamera() async throws -> CameraCapabilities {
        state.isFront.toggle()
        state.flashModes = state.isFront ? [.off] : [.off, .auto, .on]
        state.exposureBias = 0
        return state
    }
    func focus(at point: CGPoint) async throws { lastFocus = point }
    func setExposure(_ value: Float) async throws { exposure = value; state.exposureBias = value }
    func capture(flash: CameraFlash) async throws -> Data {
        captures += 1
        selectedFlash = flash
        return try await withCheckedThrowingContinuation { pending = $0 }
    }
    func complete(_ result: Result<Data, Error>) { pending?.resume(with: result); pending = nil }
}

@MainActor
final class CameraModelTests: XCTestCase {
    private func waitFor(_ condition: () async -> Bool) async throws {
        for _ in 0..<100 {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Camera transition did not finish")
    }

    func testPermissionDeniedCanRecoverAndUnavailableIsExplicit() async {
        let service = TestCamera(failure: .denied)
        let model = CameraModel(service: service)
        await model.start()
        XCTAssertEqual(model.phase, .denied)
        XCTAssertFalse(model.canCapture)
        await service.allow()
        await model.start()
        XCTAssertEqual(model.phase, .ready)
        await model.stop()
        let unavailable = CameraModel(service: TestCamera(failure: .unavailable))
        await unavailable.start()
        XCTAssertEqual(unavailable.phase, .unavailable)
    }

    func testSwitchResetsUnsupportedFlashAndExposure() async {
        let service = TestCamera()
        let model = CameraModel(service: service)
        await model.start()
        model.selectFlash(.on)
        await model.setExposure(20)
        XCTAssertEqual(model.exposure, 2)
        await model.switchCamera()
        XCTAssertTrue(model.capabilities.isFront)
        XCTAssertEqual(model.flash, .off)
        XCTAssertEqual(model.exposure, 0)
        model.selectFlash(.on)
        XCTAssertEqual(model.flash, .off)
        await model.stop()
    }

    func testFocusAndExposureAreForwardedOnlyWhenReady() async {
        let service = TestCamera()
        let model = CameraModel(service: service)
        await model.setExposure(1)
        let initialExposure = await service.exposure
        XCTAssertEqual(initialExposure, 0)
        await model.start()
        await model.focus(at: CGPoint(x: 0.3, y: 0.7))
        let point = await service.lastFocus
        XCTAssertEqual(point, CGPoint(x: 0.3, y: 0.7))
        await model.setExposure(-10)
        await model.setExposure(.nan)
        let applied = await service.exposure
        XCTAssertEqual(applied, -2)
        await model.stop()
    }

    func testRepeatedShutterIsIgnoredAndCaptureBytesReachEditorUnchanged() async throws {
        let data = try await BundleSampleInput().load(SampleImage.catalog[0])
        let service = TestCamera()
        let model = CameraModel(service: service)
        await model.start()
        model.selectFlash(.auto)
        let first = Task { await model.capture() }
        try await waitFor { await service.captures == 1 }
        XCTAssertFalse(model.canCapture)
        let second = await model.capture()
        XCTAssertNil(second)
        await model.switchCamera()
        XCTAssertFalse(model.capabilities.isFront)
        await service.complete(.success(data))
        let firstResult = await first.value
        let captured = try XCTUnwrap(firstResult)
        XCTAssertEqual(captured, data)
        let editor = EditorModel(sample: SampleImage.catalog[0])
        editor.load(captured, title: "카메라 사진")
        XCTAssertEqual(editor.originalData, data)
        let count = await service.captures
        let flash = await service.selectedFlash
        XCTAssertEqual(count, 1)
        XCTAssertEqual(flash, .auto)
        await model.stop()
    }

    func testCancelDiscardsLateCapture() async throws {
        let data = try await BundleSampleInput().load(SampleImage.catalog[0])
        let service = TestCamera()
        let model = CameraModel(service: service)
        await model.start()
        let shot = Task { await model.capture() }
        try await waitFor { await service.captures == 1 }
        model.close()
        await service.complete(.success(data))
        let result = await shot.value
        XCTAssertNil(result)
        XCTAssertEqual(model.phase, .idle)
    }

    func testInterruptedCaptureAndAutomaticRecovery() async throws {
        let service = TestCamera()
        let model = CameraModel(service: service)
        await model.start()
        let shot = Task { await model.capture() }
        try await waitFor { await service.captures == 1 }
        service.sink.yield(.interrupted)
        try await waitFor { model.phase == .interrupted }
        XCTAssertFalse(model.canCapture)
        await service.complete(.failure(CameraFailure.interrupted))
        let result = await shot.value
        XCTAssertNil(result)
        service.sink.yield(.recovered(CameraCapabilities()))
        try await waitFor { model.phase == .ready }
        XCTAssertTrue(model.canCapture)
        await model.stop()
        service.sink.yield(.recovered(CameraCapabilities()))
        await Task.yield()
        XCTAssertEqual(model.phase, .idle)
    }

    func testCaptureFailureAndInvalidBytesAllowRetry() async throws {
        let service = TestCamera()
        let model = CameraModel(service: service)
        await model.start()
        for result in [Result<Data, Error>.failure(CameraFailure.captureFailed), .success(Data([1, 2, 3]))] {
            let before = await service.captures
            let shot = Task { await model.capture() }
            try await waitFor { await service.captures > before }
            await service.complete(result)
            let data = await shot.value
            XCTAssertNil(data)
            XCTAssertNotNil(model.message)
            XCTAssertTrue(model.canCapture)
        }
        await model.stop()
    }

    func testBackgroundWhilePermissionOrStartupPendingCannotReopenCamera() async throws {
        let service = TestCamera(holdStart: true)
        let model = CameraModel(service: service)
        let opening = Task { await model.start() }
        try await waitFor { await service.isStarting }
        await model.stop()
        await service.finishStart()
        await opening.value
        XCTAssertEqual(model.phase, .idle)
        XCTAssertFalse(model.canCapture)
    }

    func testResumeReflectsActualExposureAndRuntimeFailureRequiresRetry() async throws {
        let service = TestCamera()
        let model = CameraModel(service: service)
        await model.start()
        await model.setExposure(1)
        await model.stop()
        await model.start()
        XCTAssertEqual(model.exposure, 1)
        service.sink.yield(.failed(.configuration))
        try await waitFor { model.phase == .failed }
        await model.start()
        XCTAssertTrue(model.canCapture)
        await model.stop()
    }

    func testProductionSimulatorCameraReportsUnavailable() async throws {
        #if targetEnvironment(simulator)
        let model = CameraModel(service: CameraService())
        await model.start()
        XCTAssertEqual(model.phase, .unavailable)
        await model.stop()
        #else
        throw XCTSkip("Simulator-specific camera fallback")
        #endif
    }
}

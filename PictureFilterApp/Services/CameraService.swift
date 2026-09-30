import AVFoundation
import Foundation

struct CameraCapabilities: Equatable, Sendable {
    var isFront = false
    var canSwitch = false
    var supportsFocus = false
    var exposureBias: Float = 0
    var exposureRange: ClosedRange<Float> = 0...0
    var flashModes: [CameraFlash] = [.off]
}

enum CameraFlash: String, CaseIterable, Sendable {
    case off, auto, on
    var title: String {
        switch self { case .off: return "끔"; case .auto: return "자동"; case .on: return "켬" }
    }
    var avMode: AVCaptureDevice.FlashMode {
        switch self { case .off: return .off; case .auto: return .auto; case .on: return .on }
    }
}

enum CameraFailure: Error, Equatable, LocalizedError {
    case denied, unavailable, interrupted, captureFailed, busy, configuration
    var errorDescription: String? {
        switch self {
        case .denied: return "설정에서 카메라 접근을 허용해 주세요."
        case .unavailable: return "이 기기에서는 카메라를 사용할 수 없습니다. 사진 선택이나 샘플 편집을 이용해 주세요."
        case .interrupted: return "촬영이 중단되었습니다. 카메라를 다시 시작해 주세요."
        case .captureFailed: return "사진을 촬영하지 못했습니다. 다시 시도해 주세요."
        case .busy: return "사진을 처리하고 있습니다."
        case .configuration: return "카메라를 준비하지 못했습니다. 다시 시도해 주세요."
        }
    }
}

enum CameraEvent: Sendable {
    case interrupted
    case recovered(CameraCapabilities)
    case failed(CameraFailure)
}

protocol CameraServing: AnyObject, Sendable {
    var session: AVCaptureSession? { get }
    var events: AsyncStream<CameraEvent> { get }
    func start() async throws -> CameraCapabilities
    func stop() async
    func switchCamera() async throws -> CameraCapabilities
    func focus(at point: CGPoint) async throws
    func setExposure(_ value: Float) async throws
    func capture(flash: CameraFlash) async throws -> Data
}

/// All session configuration, device locking, and capture state live on one queue.
final class CameraService: NSObject, CameraServing, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let captureSession = AVCaptureSession()
    var session: AVCaptureSession? { captureSession }
    let events: AsyncStream<CameraEvent>
    private let eventSink: AsyncStream<CameraEvent>.Continuation
    private let queue = DispatchQueue(label: "PictureFilter.camera", qos: .userInitiated)
    private let photoOutput = AVCapturePhotoOutput()
    private var input: AVCaptureDeviceInput?
    private var observers: [NSObjectProtocol] = []
    private var desiredRunning = false
    private var generation = 0
    private var interrupted = false
    private var pending: (id: Int64, continuation: CheckedContinuation<Data, Error>)?
    private var processedData: Data?

    override init() {
        let stream = AsyncStream<CameraEvent>.makeStream()
        events = stream.stream
        eventSink = stream.continuation
        super.init()
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: captureSession, queue: nil) { [weak self] _ in
            self?.queue.async { [weak self] in
                guard let self, self.desiredRunning else { return }
                self.interrupted = true
                self.finishCapture(.failure(CameraFailure.interrupted))
                self.eventSink.yield(.interrupted)
            }
        })
        observers.append(center.addObserver(forName: AVCaptureSession.interruptionEndedNotification, object: captureSession, queue: nil) { [weak self] _ in
            self?.queue.async { [weak self] in self?.recover() }
        })
        observers.append(center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: captureSession, queue: nil) { [weak self] note in
            let reset = (note.userInfo?[AVCaptureSessionErrorKey] as? AVError)?.code == .mediaServicesWereReset
            self?.queue.async { [weak self] in
                guard let self, self.desiredRunning else { return }
                self.finishCapture(.failure(CameraFailure.captureFailed))
                if reset { self.recover() }
                else {
                    self.interrupted = true
                    if self.captureSession.isRunning { self.captureSession.stopRunning() }
                    self.eventSink.yield(.failed(.configuration))
                }
            }
        })
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        eventSink.finish()
    }

    private func perform<T>(_ operation: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do { continuation.resume(returning: try operation()) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    func start() async throws -> CameraCapabilities {
        let ticket = try await perform { self.generation += 1; return self.generation }
        #if targetEnvironment(simulator)
        throw CameraFailure.unavailable
        #else
        let granted: Bool
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: granted = true
        case .notDetermined: granted = await AVCaptureDevice.requestAccess(for: .video)
        default: granted = false
        }
        guard granted else { throw CameraFailure.denied }
        try Task.checkCancellation()
        return try await perform {
            guard ticket == self.generation else { throw CancellationError() }
            if self.input == nil { try self.configure() }
            self.desiredRunning = true
            self.interrupted = false
            if !self.captureSession.isRunning { self.captureSession.startRunning() }
            guard !self.captureSession.isInterrupted else {
                self.interrupted = true
                throw CameraFailure.interrupted
            }
            guard self.captureSession.isRunning else { throw CameraFailure.configuration }
            return self.capabilities()
        }
        #endif
    }

    func stop() async {
        _ = try? await perform {
            self.generation += 1
            self.desiredRunning = false
            self.finishCapture(.failure(CancellationError()))
            if self.captureSession.isRunning { self.captureSession.stopRunning() }
        }
    }

    private func configure() throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else { throw CameraFailure.unavailable }
        let newInput = try AVCaptureDeviceInput(device: device)
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        captureSession.sessionPreset = .photo
        guard captureSession.canAddInput(newInput) else { throw CameraFailure.configuration }
        captureSession.addInput(newInput)
        guard captureSession.canAddOutput(photoOutput) else {
            captureSession.removeInput(newInput)
            throw CameraFailure.configuration
        }
        captureSession.addOutput(photoOutput)
        input = newInput
        photoOutput.maxPhotoQualityPrioritization = .quality
    }

    private func capabilities() -> CameraCapabilities {
        guard let device = input?.device else { return CameraCapabilities() }
        let otherPosition: AVCaptureDevice.Position = device.position == .front ? .back : .front
        return CameraCapabilities(isFront: device.position == .front,
            canSwitch: AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: otherPosition) != nil,
            supportsFocus: device.isFocusPointOfInterestSupported || device.isExposurePointOfInterestSupported,
            exposureBias: device.exposureTargetBias,
            exposureRange: max(-2, device.minExposureTargetBias)...min(2, device.maxExposureTargetBias),
            flashModes: CameraFlash.allCases.filter { photoOutput.supportedFlashModes.contains($0.avMode) })
    }

    func switchCamera() async throws -> CameraCapabilities {
        try await perform {
            guard self.desiredRunning, !self.interrupted, self.pending == nil, let old = self.input else { throw CameraFailure.busy }
            let position: AVCaptureDevice.Position = old.device.position == .front ? .back : .front
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else { throw CameraFailure.unavailable }
            let replacement = try AVCaptureDeviceInput(device: device)
            self.captureSession.beginConfiguration()
            self.captureSession.removeInput(old)
            guard self.captureSession.canAddInput(replacement) else {
                if self.captureSession.canAddInput(old) { self.captureSession.addInput(old) }
                self.captureSession.commitConfiguration()
                throw CameraFailure.configuration
            }
            self.captureSession.addInput(replacement)
            self.input = replacement
            self.captureSession.commitConfiguration()
            try device.lockForConfiguration()
            device.setExposureTargetBias(0)
            device.unlockForConfiguration()
            return self.capabilities()
        }
    }

    func focus(at point: CGPoint) async throws {
        guard point.x.isFinite, point.y.isFinite else { return }
        try await perform {
            guard self.desiredRunning, !self.interrupted, self.pending == nil, let device = self.input?.device else { throw CameraFailure.interrupted }
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            let clamped = CGPoint(x: min(1, max(0, point.x)), y: min(1, max(0, point.y)))
            if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = clamped; device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposurePointOfInterest = clamped; device.exposureMode = .continuousAutoExposure
            }
        }
    }

    func setExposure(_ value: Float) async throws {
        guard value.isFinite else { return }
        try await perform {
            guard self.desiredRunning, !self.interrupted, self.pending == nil, let device = self.input?.device else { throw CameraFailure.interrupted }
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.setExposureTargetBias(min(device.maxExposureTargetBias, max(device.minExposureTargetBias, value)))
        }
    }

    func capture(flash: CameraFlash) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                guard self.desiredRunning, self.captureSession.isRunning, !self.interrupted else {
                    continuation.resume(throwing: CameraFailure.interrupted); return
                }
                guard self.pending == nil else { continuation.resume(throwing: CameraFailure.busy); return }
                let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
                settings.photoQualityPrioritization = .quality
                settings.flashMode = self.photoOutput.supportedFlashModes.contains(flash.avMode) ? flash.avMode : .off
                if let connection = self.photoOutput.connection(with: .video) {
                    if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
                    // Match the explicitly unmirrored portrait preview, including front camera.
                    if connection.isVideoMirroringSupported {
                        connection.automaticallyAdjustsVideoMirroring = false
                        connection.isVideoMirrored = false
                    }
                }
                self.pending = (settings.uniqueID, continuation)
                self.processedData = nil
                self.photoOutput.capturePhoto(with: settings, delegate: self)
                self.queue.asyncAfter(deadline: .now() + 20) { [weak self] in
                    guard self?.pending?.id == settings.uniqueID else { return }
                    self?.finishCapture(.failure(CameraFailure.captureFailed))
                }
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let id = photo.resolvedSettings.uniqueID
        let data = error == nil ? photo.fileDataRepresentation() : nil
        queue.async {
            guard self.pending?.id == id else { return }
            self.processedData = data
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        queue.async {
            guard self.pending?.id == resolvedSettings.uniqueID else { return }
            if error == nil, let data = self.processedData { self.finishCapture(.success(data)) }
            else { self.finishCapture(.failure(CameraFailure.captureFailed)) }
        }
    }

    private func finishCapture(_ result: Result<Data, Error>) {
        let continuation = pending?.continuation
        pending = nil
        processedData = nil
        continuation?.resume(with: result)
    }

    private func recover() {
        guard desiredRunning else { return }
        interrupted = false
        if !captureSession.isRunning { captureSession.startRunning() }
        if captureSession.isInterrupted {
            interrupted = true
            eventSink.yield(.interrupted)
        } else if captureSession.isRunning { eventSink.yield(.recovered(capabilities())) }
        else { eventSink.yield(.failed(.configuration)) }
    }
}

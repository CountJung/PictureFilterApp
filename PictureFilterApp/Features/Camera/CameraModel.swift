import AVFoundation
import Observation
import UIKit

@MainActor @Observable
final class CameraModel {
    enum Phase: Equatable { case idle, starting, ready, denied, unavailable, interrupted, failed }
    private(set) var phase: Phase = .idle
    private(set) var capabilities = CameraCapabilities()
    private(set) var isCapturing = false
    private(set) var isSwitching = false
    private(set) var isZooming = false
    private(set) var zoom = CameraZoom()
    @ObservationIgnored private var pendingZoom: Double?
    private(set) var exposure: Float = 0
    private(set) var flash: CameraFlash = .off
    private(set) var message: String?
    @ObservationIgnored let service: any CameraServing
    @ObservationIgnored private var eventTask: Task<Void, Never>?
    @ObservationIgnored private var revision = UUID()
    @ObservationIgnored private var active = false

    init(service: any CameraServing) { self.service = service }
    deinit { eventTask?.cancel() }
    var canCapture: Bool { phase == .ready && !isCapturing && !isSwitching && !isZooming }
    var canAdjustZoom: Bool { phase == .ready && !isCapturing && !isSwitching }

    func start() async {
        guard !Task.isCancelled, phase != .starting, phase != .ready else { return }
        active = true
        revision = UUID()
        let ticket = revision
        phase = .starting
        message = nil
        if eventTask == nil {
            let events = service.events
            eventTask = Task { [weak self] in
                for await event in events {
                    guard !Task.isCancelled else { return }
                    self?.receive(event)
                }
            }
        }
        do {
            let state = try await service.start()
            guard active, ticket == revision, !Task.isCancelled else { return }
            update(state)
            phase = .ready
        } catch {
            guard active, ticket == revision, !Task.isCancelled else { return }
            fail(error)
        }
    }

    private func invalidateSession() {
        active = false
        revision = UUID()
        phase = .idle
        isCapturing = false
        isSwitching = false
        isZooming = false
        pendingZoom = nil
    }

    func stop() async {
        invalidateSession()
        await service.stop()
    }

    func close() {
        invalidateSession()
        let service = service
        Task { await service.stop() }
    }

    func switchCamera() async {
        guard canCapture, capabilities.canSwitch else { return }
        isSwitching = true
        let ticket = revision
        do {
            let state = try await service.switchCamera()
            guard active, ticket == revision else { return }
            update(state)
            message = nil
        } catch {
            guard active, ticket == revision else { return }
            fail(error)
        }
        isSwitching = false
    }

    func selectFlash(_ value: CameraFlash) {
        guard canCapture, capabilities.flashModes.contains(value) else { return }
        flash = value
    }

    func focus(at point: CGPoint) async {
        guard canCapture, capabilities.supportsFocus else { return }
        let ticket = revision
        do { try await service.focus(at: point) }
        catch { if active, ticket == revision { message = error.localizedDescription } }
    }

    func setExposure(_ value: Float) async {
        guard canCapture, value.isFinite else { return }
        let ticket = revision
        let clamped = min(capabilities.exposureRange.upperBound, max(capabilities.exposureRange.lowerBound, value))
        exposure = clamped
        do { try await service.setExposure(clamped) }
        catch { if active, ticket == revision { message = error.localizedDescription } }
    }

    func capture() async -> Data? {
        guard canCapture else { return nil }
        let ticket = revision
        isCapturing = true
        defer { if ticket == revision { isCapturing = false } }
        message = nil
        do {
            let data = try await service.capture(flash: flash)
            guard active, ticket == revision, !Task.isCancelled else { return nil }
            guard UIImage(data: data) != nil else { throw CameraFailure.captureFailed }
            isCapturing = false
            // Preserve AVCapturePhoto bytes, including orientation; never JPEG re-encode.
            return data
        } catch {
            guard active, ticket == revision else { return nil }
            isCapturing = false
            message = error.localizedDescription
            return nil
        }
    }

    func setZoom(_ displayValue: Double) async {
        guard canAdjustZoom, displayValue.isFinite else { return }
        pendingZoom = zoom.clamped(displayValue / zoom.displayMultiplier)
        guard !isZooming else { return }
        isZooming = true
        let ticket = revision
        defer { if ticket == revision { isZooming = false; pendingZoom = nil } }
        while let requested = pendingZoom {
            pendingZoom = nil
            do {
                let state = try await service.setZoom(requested)
                guard active, ticket == revision else { return }
                update(state)
            } catch {
                guard active, ticket == revision else { return }
                message = error.localizedDescription
                return
            }
        }
    }

    private func update(_ state: CameraCapabilities) {
        capabilities = state
        zoom = state.zoom
        exposure = state.exposureBias
        if !state.flashModes.contains(flash) { flash = .off }
    }

    private func fail(_ error: Error) {
        message = error.localizedDescription
        switch error as? CameraFailure {
        case .denied: phase = .denied
        case .unavailable: phase = .unavailable
        case .interrupted: phase = .interrupted
        default: phase = .failed
        }
    }

    private func receive(_ event: CameraEvent) {
        guard active else { return }
        switch event {
        case .capabilitiesChanged(let state):
            guard phase == .ready else { return }
            update(state)
        case .interrupted:
            revision = UUID()
            isCapturing = false
            isSwitching = false
            isZooming = false
            pendingZoom = nil
            phase = .interrupted
            message = CameraFailure.interrupted.localizedDescription
        case .recovered(let state):
            update(state)
            phase = .ready
            message = nil
        case .failed(let error):
            revision = UUID()
            isCapturing = false
            isSwitching = false
            isZooming = false
            pendingZoom = nil
            fail(error)
        }
    }
}

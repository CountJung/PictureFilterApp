import SwiftUI
import UIKit
import AVFoundation

struct CameraCaptureSheet: View {
    let onCapture: (Data) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: CameraModel

    init(service: (any CameraServing)? = nil, onCapture: @escaping (Data) -> Void) {
        self.onCapture = onCapture
        let selected: any CameraServing
        if let service { selected = service }
        else {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-test-camera") {
                selected = SimulatedCameraService()
            } else { selected = CameraService() }
            #else
            selected = CameraService()
            #endif
        }
        _model = State(initialValue: CameraModel(service: selected))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if model.phase == .ready {
                    if let session = model.service.session {
                        CameraPreview(session: session, isFront: model.capabilities.isFront) { point in
                            Task { await model.focus(at: point) }
                        }
                        .background(.black)
                        .frame(minHeight: 120, maxHeight: .infinity)
                    } else {
                        ContentUnavailableView("촬영 테스트", systemImage: "camera", description: Text("시뮬레이터용 합성 사진을 사용합니다."))
                            .frame(maxHeight: 240)
                    }
                    Text(model.capabilities.isFront ? "전면 카메라 · 좌우 반전 없이 저장" : "후면 카메라")
                        .font(.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("cameraFacing")
                    if model.capabilities.supportsFocus {
                        Text("미리보기를 눌러 초점과 측광 위치를 선택하세요.").font(.caption)
                    }
                    if model.capabilities.exposureRange.lowerBound < model.capabilities.exposureRange.upperBound {
                        HStack {
                            Text("노출")
                            Slider(value: Binding(get: { model.exposure }, set: { value in Task { await model.setExposure(value) } }), in: model.capabilities.exposureRange)
                                .accessibilityIdentifier("cameraExposure")
                            Text(model.exposure, format: .number.precision(.fractionLength(1)))
                        }
                        .disabled(!model.canCapture)
                    }
                    if model.capabilities.flashModes.count > 1 {
                        Picker("플래시", selection: Binding(get: { model.flash }, set: { model.selectFlash($0) })) {
                            ForEach(model.capabilities.flashModes, id: \.self) { mode in Text(mode.title).tag(mode) }
                        }
                        .pickerStyle(.segmented)
                        .disabled(!model.canCapture)
                        .accessibilityIdentifier("cameraFlash")
                    }
                    HStack(spacing: 36) {
                        Button { Task { await model.switchCamera() } } label: {
                            Label("전후면 전환", systemImage: "arrow.triangle.2.circlepath.camera")
                        }
                        .labelStyle(.iconOnly)
                        .disabled(!model.canCapture || !model.capabilities.canSwitch)
                        .accessibilityIdentifier("cameraSwitch")
                        Button {
                            Task {
                                if let data = await model.capture() { onCapture(data) }
                            }
                        } label: {
                            Label(model.isCapturing ? "사진 처리 중" : "촬영", systemImage: "camera.circle.fill")
                                .font(.title2).padding(12)
                        }
                        .disabled(!model.canCapture)
                        .accessibilityIdentifier("cameraShutter")
                    }
                } else if model.phase == .starting || model.phase == .idle {
                    ProgressView("카메라 준비 중")
                } else {
                    ContentUnavailableView {
                        Label(model.phase == .unavailable ? "카메라를 사용할 수 없습니다" : "카메라 확인이 필요합니다", systemImage: "camera")
                    } description: {
                        Text(model.message ?? "카메라를 다시 시작해 주세요.")
                    } actions: {
                        if model.phase == .denied {
                            Button("카메라 접근 설정 열기") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                            }
                            .accessibilityIdentifier("cameraSettings")
                        }
                        if model.phase != .unavailable {
                            Button("다시 시도") { Task { await model.start() } }
                                .accessibilityIdentifier("cameraRetry")
                        }
                        Button("닫기") { model.close(); dismiss() }
                    }
                }
                if model.phase == .ready, let message = model.message {
                    Text(message).font(.footnote).foregroundStyle(.red)
                        .accessibilityIdentifier("cameraError")
                }
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("사진 촬영")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { model.close(); dismiss() }.accessibilityIdentifier("cameraCancel")
                }
            }
        }
        .task(id: scenePhase) {
            if scenePhase == .active { await model.start() }
            else { await model.stop() }
        }
        .onDisappear { model.close() }
    }
}

#if DEBUG
/// Opt-in UI-test stand-in only; normal simulator use reports unavailable.
private actor SimulatedCameraService: CameraServing {
    nonisolated var session: AVCaptureSession? { nil }
    nonisolated let events: AsyncStream<CameraEvent> = AsyncStream { _ in }
    private var front = false
    func start() async throws -> CameraCapabilities { state }
    func stop() async {}
    func switchCamera() async throws -> CameraCapabilities { front.toggle(); return state }
    func focus(at point: CGPoint) async throws {}
    func setExposure(_ value: Float) async throws {}
    func capture(flash: CameraFlash) async throws -> Data {
        try await Task.sleep(for: .milliseconds(400))
        return try await BundleSampleInput().load(SampleImage.catalog[0])
    }
    private var state: CameraCapabilities {
        CameraCapabilities(isFront: front, canSwitch: true, supportsFocus: true,
                           exposureRange: -2...2, flashModes: front ? [.off] : [.off, .auto, .on])
    }
}
#endif

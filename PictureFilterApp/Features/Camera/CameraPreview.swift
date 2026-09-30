import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let isFront: Bool
    let onFocus: (CGPoint) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspect
        view.onFocus = onFocus
        view.accessibilityLabel = "카메라 미리보기"
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        view.onFocus = onFocus
        view.configureConnection()
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        var onFocus: ((CGPoint) -> Void)?
        override init(frame: CGRect) {
            super.init(frame: frame)
            addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func layoutSubviews() { super.layoutSubviews(); configureConnection() }
        func configureConnection() {
            guard let connection = previewLayer.connection else { return }
            if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
        }
        @objc private func tapped(_ gesture: UITapGestureRecognizer) {
            let location = gesture.location(in: self)
            // Ignore taps on the letterbox; convert using AVFoundation's actual layout.
            let point = previewLayer.captureDevicePointConverted(fromLayerPoint: location)
            guard (0...1).contains(point.x), (0...1).contains(point.y) else { return }
            onFocus?(point)
        }
    }
}

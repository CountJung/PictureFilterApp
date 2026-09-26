import SwiftUI
import UIKit

struct CameraCaptureSheet: View {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                CameraImagePicker(onCapture: onCapture, onCancel: { dismiss() })
                    .ignoresSafeArea()
            } else {
                ContentUnavailableView {
                    Label("카메라를 사용할 수 없습니다", systemImage: "camera")
                } description: {
                    Text("이 기기에서는 카메라를 지원하지 않습니다. 사진 선택이나 샘플 편집을 이용해 주세요.")
                } actions: {
                    Button("닫기") { dismiss() }.buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

private struct CameraImagePicker: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture, onCancel: onCancel) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.cameraDevice = UIImagePickerController.isCameraDeviceAvailable(.front) ? .front : .rear
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let onCancel: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { onCapture(image) }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onCancel() }
    }
}

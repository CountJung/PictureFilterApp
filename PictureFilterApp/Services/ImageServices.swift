import Foundation
import Photos
import UIKit

struct SampleImage: Identifiable, Sendable {
    let id: String
    let title: String

    static let catalog = [
        SampleImage(id: "sample-landscape", title: "가로 색상표"),
        SampleImage(id: "sample-portrait", title: "세로 색상표")
    ]
}

enum ImageServiceError: Error, Equatable, LocalizedError {
    case inputUnavailable
    case invalidImage
    case permissionDenied
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .inputUnavailable: return "이미지를 불러올 수 없습니다."
        case .invalidImage: return "읽을 수 없는 이미지입니다."
        case .permissionDenied: return "사진 저장 권한이 없습니다."
        case .saveFailed: return "이미지를 저장하지 못했습니다."
        }
    }
}

protocol ImageInputService: Sendable {
    func load(_ sample: SampleImage) async throws -> Data
}

protocol ImageOutputService: Sendable {
    func save(_ data: Data) async throws -> UUID
    func saveToPhotoLibrary(_ data: Data) async throws
}

struct BundleSampleInput: ImageInputService {
    func load(_ sample: SampleImage) async throws -> Data {
        guard SampleImage.catalog.contains(where: { $0.id == sample.id }) else {
            throw ImageServiceError.inputUnavailable
        }
        return try await Task.detached {
            try Task.checkCancellation()
            guard let url = Bundle.main.url(forResource: sample.id, withExtension: "png"),
                  let data = try? Data(contentsOf: url) else {
                throw ImageServiceError.inputUnavailable
            }
            guard UIImage(data: data) != nil else { throw ImageServiceError.invalidImage }
            return data
        }.value
    }
}

struct FailingImageInput: ImageInputService {
    let error: ImageServiceError

    func load(_ sample: SampleImage) async throws -> Data {
        throw error
    }
}

/// Simulator/test double only. It never writes to the system photo library.
actor MemoryImageOutput: ImageOutputService {
    private var images: [UUID: Data] = [:]
    private let failure: ImageServiceError?
    private let delay: Duration

    init(failure: ImageServiceError? = nil, delay: Duration = .zero) {
        self.failure = failure
        self.delay = delay
    }

    func save(_ data: Data) async throws -> UUID {
        try Task.checkCancellation()
        if delay > .zero { try await Task.sleep(for: delay) }
        try Task.checkCancellation()
        if let failure { throw failure }
        guard UIImage(data: data) != nil else { throw ImageServiceError.invalidImage }
        let id = UUID()
        images[id] = data
        return id
    }

    func saveToPhotoLibrary(_ data: Data) async throws {
        _ = try await save(data)
    }

    func image(for id: UUID) -> Data? { images[id] }
    var count: Int { images.count }
    func removeAll() { images.removeAll() }
}

struct PhotoLibraryImageOutput: ImageOutputService {
    func save(_ data: Data) async throws -> UUID {
        let id = UUID()
        let directory = FileManager.default.temporaryDirectory
        let url = directory.appendingPathComponent("PictureFilterApp-\(id.uuidString).jpg")
        defer { try? FileManager.default.removeItem(at: url) }
        try data.write(to: url, options: .atomic)
        try await saveToPhotoLibrary(data, fileURL: url)
        return id
    }

    func saveToPhotoLibrary(_ data: Data) async throws {
        guard UIImage(data: data) != nil else { throw ImageServiceError.invalidImage }
        let id = UUID()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PictureFilterApp-\(id.uuidString).jpg")
        defer { try? FileManager.default.removeItem(at: url) }
        try data.write(to: url, options: .atomic)
        try await saveToPhotoLibrary(data, fileURL: url)
    }

    private func saveToPhotoLibrary(_ data: Data, fileURL: URL) async throws {
        guard UIImage(data: data) != nil else { throw ImageServiceError.invalidImage }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw ImageServiceError.permissionDenied
        }
        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: fileURL)
            } completionHandler: { success, error in
                if success { continuation.resume() }
                else if let error { continuation.resume(throwing: error) }
                else { continuation.resume(throwing: ImageServiceError.saveFailed) }
            }
        }
    }
}

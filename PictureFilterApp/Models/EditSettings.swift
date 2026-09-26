import Foundation

enum PhotoFilter: String, CaseIterable, Identifiable, Sendable {
    case original, monochrome, sepia, warm, cool
    var id: String { rawValue }
    var title: String {
        switch self {
        case .original: return "원본"
        case .monochrome: return "흑백"
        case .sepia: return "세피아"
        case .warm: return "따뜻함"
        case .cool: return "차가움"
        }
    }
}

struct EditSettings: Equatable, Sendable {
    private(set) var filter: PhotoFilter = .original
    private(set) var intensity: Double = 0.5
    private(set) var skinSmoothing: Double = 0

    mutating func select(_ filter: PhotoFilter) { self.filter = filter }
    mutating func setIntensity(_ value: Double) {
        guard value.isFinite else { return }
        intensity = min(1, max(0, value))
    }

    mutating func setSkinSmoothing(_ value: Double) {
        guard value.isFinite else { return }
        skinSmoothing = min(1, max(0, value))
    }
}

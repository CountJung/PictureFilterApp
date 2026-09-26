import Foundation

enum PhotoFilter: String, CaseIterable, Identifiable, Sendable {
    case original, monochrome, sepia, warm, cool, softFilm, goldenHour, cinematic, vivid
    static let basic: [PhotoFilter] = [.original, .monochrome, .sepia, .warm, .cool]
    static let styles: [PhotoFilter] = [.softFilm, .goldenHour, .cinematic, .vivid]
    var id: String { rawValue }
    var title: String {
        switch self {
        case .original: return "원본"
        case .monochrome: return "흑백"
        case .sepia: return "세피아"
        case .warm: return "따뜻함"
        case .cool: return "차가움"
        case .softFilm: return "소프트 필름"
        case .goldenHour: return "골든아워"
        case .cinematic: return "시네마틱"
        case .vivid: return "비비드"
        }
    }
}

struct EditSettings: Equatable, Sendable {
    private(set) var filter: PhotoFilter = .original
    private(set) var intensity: Double = 0.5
    private(set) var skinSmoothing: Double = 0
    private(set) var selectedSkinFaceIndex: Int?
    private(set) var faceSkinSmoothing: [Int: Double] = [:]
    private(set) var portraitLight: Double = 0
    private(set) var facePortraitLight: [Int: Double] = [:]
    private(set) var backgroundBlur: Double = 0

    var activeSkinSmoothing: Double {
        guard let selectedSkinFaceIndex else { return skinSmoothing }
        return faceSkinSmoothing[selectedSkinFaceIndex] ?? skinSmoothing
    }

    var activePortraitLight: Double {
        guard let selectedSkinFaceIndex else { return portraitLight }
        return facePortraitLight[selectedSkinFaceIndex] ?? portraitLight
    }

    mutating func select(_ filter: PhotoFilter) { self.filter = filter }
    mutating func setIntensity(_ value: Double) {
        guard value.isFinite else { return }
        intensity = min(1, max(0, value))
    }

    mutating func setSkinSmoothing(_ value: Double) {
        guard value.isFinite else { return }
        let clamped = min(1, max(0, value))
        if let selectedSkinFaceIndex {
            if clamped == skinSmoothing {
                faceSkinSmoothing.removeValue(forKey: selectedSkinFaceIndex)
            } else {
                faceSkinSmoothing[selectedSkinFaceIndex] = clamped
            }
        } else {
            skinSmoothing = clamped
            faceSkinSmoothing.removeAll()
        }
    }

    mutating func selectSkinFace(_ index: Int?) {
        selectedSkinFaceIndex = index.map { max(0, $0) }
    }

    func skinSmoothing(forFaceAt index: Int) -> Double {
        faceSkinSmoothing[index] ?? skinSmoothing
    }

    mutating func resetSelectedSkinSmoothing() {
        guard let selectedSkinFaceIndex else {
            skinSmoothing = 0
            faceSkinSmoothing.removeAll()
            return
        }
        // A reset explicitly opts this face out of a nonzero global value.
        faceSkinSmoothing[selectedSkinFaceIndex] = 0
    }

    mutating func setPortraitLight(_ value: Double) {
        guard value.isFinite else { return }
        let clamped = min(1, max(0, value))
        if let selectedSkinFaceIndex {
            if clamped == portraitLight {
                facePortraitLight.removeValue(forKey: selectedSkinFaceIndex)
            } else {
                facePortraitLight[selectedSkinFaceIndex] = clamped
            }
        } else {
            portraitLight = clamped
            facePortraitLight.removeAll()
        }
    }

    func portraitLight(forFaceAt index: Int) -> Double {
        facePortraitLight[index] ?? portraitLight
    }

    mutating func setBackgroundBlur(_ value: Double) {
        guard value.isFinite else { return }
        backgroundBlur = min(1, max(0, value))
    }

    mutating func resetSelectedPortraitEffects() {
        guard let selectedSkinFaceIndex else {
            portraitLight = 0
            facePortraitLight.removeAll()
            return
        }
        facePortraitLight[selectedSkinFaceIndex] = 0
    }
}

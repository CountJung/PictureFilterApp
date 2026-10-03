import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import UniformTypeIdentifiers
import Vision

/// Serial worker; each result is rendered from the input, never a prior preview.
protocol PreviewRendering: Sendable {
    func render(_ data: Data, settings: EditSettings, maxDimension: Int) async throws -> Data
}

protocol OutputRendering: Sendable {
    func renderOutput(_ data: Data, settings: EditSettings, maxDimension: Int) async throws -> Data
}

protocol FaceCounting: Sendable {
    func faceCount(in data: Data) async -> Int
    func faceAnalysis(in data: Data, retry: Bool) async -> FaceAnalysisState
    func backgroundAnalysis(in data: Data) async -> FaceAnalysisState
}

enum FaceAnalysisState: Equatable, Sendable {
    case idle, analyzing, ready(Int), failed
}

actor FilterRenderer: PreviewRendering, OutputRendering, FaceCounting {
    private let portraitFaceDetector: any PortraitFaceDetecting
    private let landmarkDetector: @Sendable (CGImage) throws -> [VNFaceObservation]
    private let maskDetector: @Sendable (CGImage) throws -> CIImage?
    private var cachedData: Data?
    private var analysisImage: CGImage?
    private var landmarks: Result<[VNFaceObservation], Error>?
    private var personMask: Result<CIImage?, Error>?
    private var brightFaces: [CGRect]?

    init(portraitFaceDetector: any PortraitFaceDetecting = VisionPortraitFaceDetector(),
         landmarkDetector: @escaping @Sendable (CGImage) throws -> [VNFaceObservation] = { try FilterRenderer.detectLandmarks($0) },
         maskDetector: @escaping @Sendable (CGImage) throws -> CIImage? = { try PortraitEffects.personMask(source: $0) }) {
        self.portraitFaceDetector = portraitFaceDetector
        self.landmarkDetector = landmarkDetector
        self.maskDetector = maskDetector
    }

    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private lazy var context = CIContext(options: [.workingColorSpace: colorSpace])

    func render(_ data: Data, settings: EditSettings, maxDimension: Int = 1600) throws -> Data {
        try render(data, settings: settings, maxDimension: maxDimension, jpegQuality: nil)
    }

    func renderOutput(_ data: Data, settings: EditSettings, maxDimension: Int = 4096) throws -> Data {
        try render(data, settings: settings, maxDimension: maxDimension, jpegQuality: 0.9)
    }

    func faceCount(in data: Data) async -> Int {
        if case .ready(let count) = await faceAnalysis(in: data, retry: false) { return count }
        return 0
    }

    func faceAnalysis(in data: Data, retry: Bool = false) async -> FaceAnalysisState {
        do {
            try prepareAnalysis(data)
            if retry { landmarks = nil; personMask = nil; brightFaces = nil }
            return .ready(try cachedLandmarks().count)
        } catch { return .failed }
    }

    func backgroundAnalysis(in data: Data) async -> FaceAnalysisState {
        guard data == cachedData, let personMask else { return .idle }
        switch personMask {
        case .success(let mask): return .ready(mask == nil ? 0 : 1)
        case .failure: return .failed
        }
    }

    private static func detectLandmarks(_ image: CGImage) throws -> [VNFaceObservation] {
        let request = VNDetectFaceLandmarksRequest()
        try VNImageRequestHandler(cgImage: image, orientation: .up).perform([request])
        return request.results ?? []
    }

    private func prepareAnalysis(_ data: Data) throws {
        try Task.checkCancellation()
        if cachedData == data { return }
        cachedData = nil; analysisImage = nil; landmarks = nil; personMask = nil; brightFaces = nil
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1600
              ] as CFDictionary) else { throw ImageServiceError.invalidImage }
        cachedData = data
        analysisImage = image
    }

    private func cachedLandmarks() throws -> [VNFaceObservation] {
        try Task.checkCancellation()
        if landmarks == nil, let image = analysisImage {
            landmarks = Result { try landmarkDetector(image).sorted { $0.boundingBox.midX < $1.boundingBox.midX } }
        }
        return try landmarks?.get() ?? []
    }

    private func cachedPersonMask() throws -> CIImage? {
        try Task.checkCancellation()
        if personMask == nil, let image = analysisImage { personMask = Result { try maskDetector(image) } }
        return try personMask?.get() ?? nil
    }

    private func render(_ data: Data, settings: EditSettings, maxDimension: Int, jpegQuality: CGFloat?) throws -> Data {
        try Task.checkCancellation()
        try prepareAnalysis(data)
        guard maxDimension > 0,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimension
              ] as CFDictionary) else { throw ImageServiceError.invalidImage }
        try Task.checkCancellation()
        let original = CIImage(cgImage: thumbnail)
        var result = original
        if settings.filter != .original && settings.intensity > 0 {
            let filtered: CIImage
            switch settings.filter {
            case .brightPortrait:
                if brightFaces == nil, let image = analysisImage { brightFaces = portraitFaceDetector.faces(in: image) }
                let faces = brightFaces ?? []
                filtered = try BrightPortraitFilter.apply(to: original, faces: faces,
                    brightness: settings.portraitBrightness, warmth: settings.portraitWarmth)
            case .original: filtered = original
            case .monochrome:
                let filter = CIFilter.colorControls()
                filter.inputImage = original
                filter.saturation = 0
                guard let output = filter.outputImage else { throw ImageServiceError.invalidImage }
                filtered = output
            case .sepia:
                let filter = CIFilter.sepiaTone()
                filter.inputImage = original
                filter.intensity = 1
                guard let output = filter.outputImage else { throw ImageServiceError.invalidImage }
                filtered = output
            case .warm, .cool:
                let filter = CIFilter.colorMatrix()
                filter.inputImage = original
                let warm = settings.filter == .warm
                filter.rVector = CIVector(x: warm ? 1.08 : 0.94, y: 0, z: 0, w: 0)
                filter.gVector = CIVector(x: 0, y: 1, z: 0, w: 0)
                filter.bVector = CIVector(x: 0, y: 0, z: warm ? 0.94 : 1.08, w: 0)
                guard let output = filter.outputImage else { throw ImageServiceError.invalidImage }
                filtered = output
            case .softFilm:
                let toned = colorControls(original, saturation: 0.84, contrast: 0.91, brightness: 0.035)
                let shadows = highlightShadow(toned, shadows: 0.22, highlights: 0.88)
                filtered = vignette(shadows, amount: 0.12, extent: original.extent)
            case .goldenHour:
                let toned = colorControls(original, saturation: 1.08, contrast: 1.02, brightness: 0.025)
                let warm = colorMatrix(toned, red: 1.045, green: 1.0, blue: 0.94, redOffset: 0.012, blueOffset: -0.004)
                filtered = highlightShadow(warm, shadows: 0.16, highlights: 0.93)
            case .cinematic:
                let toned = colorControls(original, saturation: 0.88, contrast: 1.13, brightness: -0.018)
                let coolShadows = colorMatrix(toned, red: 0.975, green: 1.015, blue: 1.065, redOffset: -0.006, blueOffset: 0.012)
                filtered = vignette(coolShadows, amount: 0.2, extent: original.extent)
            case .vivid:
                let toned = colorControls(original, saturation: 1.22, contrast: 1.08, brightness: 0.006)
                filtered = highlightShadow(toned, shadows: 0.13, highlights: 0.96)
            }
            let blend = CIFilter.dissolveTransition()
            blend.inputImage = original
            blend.targetImage = filtered
            blend.time = Float(settings.intensity)
            guard let output = blend.outputImage else { throw ImageServiceError.invalidImage }
            result = output.cropped(to: original.extent)
        }
        if settings.skinSmoothing > 0 || settings.faceSkinSmoothing.values.contains(where: { $0 > 0 }) {
            result = try FaceSkinSmoother.apply(to: result, source: thumbnail,
                                                allIntensity: settings.skinSmoothing,
                                                faceIntensities: settings.faceSkinSmoothing,
                                                analyzedFaces: (try? cachedLandmarks()) ?? [])
        }
        if settings.portraitLight > 0 || settings.facePortraitLight.values.contains(where: { $0 > 0 }) {
            result = PortraitEffects.applyLighting(to: result, source: thumbnail,
                                                   allIntensity: settings.portraitLight,
                                                   faceIntensities: settings.facePortraitLight,
                                                   analyzedFaces: (try? cachedLandmarks()) ?? [])
        }
        if settings.backgroundBlur > 0 {
            result = PortraitEffects.applyBackgroundBlur(to: result, mask: try? cachedPersonMask(),
                                                        intensity: settings.backgroundBlur)
        }
        try Task.checkCancellation()
        if jpegQuality != nil {
            let background = CIImage(color: .white).cropped(to: result.extent)
            result = result.composited(over: background).cropped(to: original.extent)
        }
        guard let cgImage = context.createCGImage(result, from: original.extent, format: .RGBA8, colorSpace: colorSpace) else {
            throw ImageServiceError.invalidImage
        }
        try Task.checkCancellation()
        let output = NSMutableData()
        let type = jpegQuality == nil ? UTType.png.identifier : UTType.jpeg.identifier
        guard let destination = CGImageDestinationCreateWithData(output, type as CFString, 1, nil) else {
            throw ImageServiceError.invalidImage
        }
        let properties: CFDictionary? = jpegQuality.map { [kCGImageDestinationLossyCompressionQuality: $0] as CFDictionary }
        CGImageDestinationAddImage(destination, cgImage, properties)
        guard CGImageDestinationFinalize(destination) else { throw ImageServiceError.invalidImage }
        try Task.checkCancellation()
        return output as Data
    }

    private func colorControls(_ image: CIImage, saturation: Float, contrast: Float, brightness: Float) -> CIImage {
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.saturation = saturation
        filter.contrast = contrast
        filter.brightness = brightness
        return filter.outputImage ?? image
    }

    private func highlightShadow(_ image: CIImage, shadows: Float, highlights: Float) -> CIImage {
        let filter = CIFilter.highlightShadowAdjust()
        filter.inputImage = image
        filter.shadowAmount = shadows
        filter.highlightAmount = highlights
        return filter.outputImage ?? image
    }

    private func colorMatrix(_ image: CIImage, red: CGFloat, green: CGFloat, blue: CGFloat,
                             redOffset: CGFloat = 0, blueOffset: CGFloat = 0) -> CIImage {
        let filter = CIFilter.colorMatrix()
        filter.inputImage = image
        filter.rVector = CIVector(x: red, y: 0, z: 0, w: 0)
        filter.gVector = CIVector(x: 0, y: green, z: 0, w: 0)
        filter.bVector = CIVector(x: 0, y: 0, z: blue, w: 0)
        filter.biasVector = CIVector(x: redOffset, y: 0, z: blueOffset, w: 0)
        return filter.outputImage ?? image
    }

    private func vignette(_ image: CIImage, amount: Float, extent: CGRect) -> CIImage {
        let filter = CIFilter.vignette()
        filter.inputImage = image
        filter.intensity = amount
        filter.radius = Float(max(extent.width, extent.height) * 0.72)
        return (filter.outputImage ?? image).cropped(to: extent)
    }
}

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

actor FilterRenderer: PreviewRendering, OutputRendering {
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private lazy var context = CIContext(options: [.workingColorSpace: colorSpace])

    func render(_ data: Data, settings: EditSettings, maxDimension: Int = 1600) throws -> Data {
        try render(data, settings: settings, maxDimension: maxDimension, jpegQuality: nil)
    }

    func renderOutput(_ data: Data, settings: EditSettings, maxDimension: Int = 4096) throws -> Data {
        try render(data, settings: settings, maxDimension: maxDimension, jpegQuality: 0.9)
    }

    private func render(_ data: Data, settings: EditSettings, maxDimension: Int, jpegQuality: CGFloat?) throws -> Data {
        try Task.checkCancellation()
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
            }
            let blend = CIFilter.dissolveTransition()
            blend.inputImage = original
            blend.targetImage = filtered
            blend.time = Float(settings.intensity)
            guard let output = blend.outputImage else { throw ImageServiceError.invalidImage }
            result = output.cropped(to: original.extent)
        }
        if settings.skinSmoothing > 0 {
            result = try FaceSkinSmoother.apply(to: result, source: thumbnail, intensity: settings.skinSmoothing)
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
}

import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

/// Normalized lower-left coordinates, independent of preview/export resolution.
protocol PortraitFaceDetecting: Sendable {
    func faces(in image: CGImage) -> [CGRect]
}

struct VisionPortraitFaceDetector: PortraitFaceDetecting {
    func faces(in image: CGImage) -> [CGRect] {
        let request = VNDetectFaceRectanglesRequest()
        do {
            try VNImageRequestHandler(cgImage: image, orientation: .up).perform([request])
            return (request.results ?? []).map(\.boundingBox)
        } catch {
            // The preset still provides a global tone adjustment without Vision.
            return []
        }
    }
}

/// A bounded, monotonic tone lift: no geometry changes or automatic skin blur.
/// The cube operates in the renderer's sRGB working space. The brightest
/// channel limits the gain so colored highlights are protected as well as white.
enum BrightPortraitFilter {
    static func apply(to image: CIImage, faces: [CGRect], brightness: Double,
                      warmth: Double) throws -> CIImage {
        guard brightness > 0 || warmth != 0 else { return image }
        let base = try tone(image, brightness: brightness * 0.55, warmth: warmth)
        guard let mask = faceMask(faces, extent: image.extent) else { return base }
        let faceTone = try tone(image, brightness: brightness, warmth: warmth)
        let blend = CIFilter.blendWithMask()
        blend.inputImage = faceTone
        blend.backgroundImage = base
        blend.maskImage = mask
        guard let result = blend.outputImage else { throw ImageServiceError.invalidImage }
        return result.cropped(to: image.extent)
    }

    private static func tone(_ image: CIImage, brightness: Double, warmth: Double) throws -> CIImage {
        let dimension = 33
        var cube = [Float]()
        cube.reserveCapacity(dimension * dimension * dimension * 4)
        for b in 0..<dimension {
            try Task.checkCancellation()
            for g in 0..<dimension {
                for r in 0..<dimension {
                    let red = Double(r) / Double(dimension - 1)
                    let green = Double(g) / Double(dimension - 1)
                    let blue = Double(b) / Double(dimension - 1)
                    let peak = max(red, green, blue)
                    let gain = 1 + 1.5 * brightness * pow(1 - peak, 2)
                    // Equal gain preserves channel ratios when warmth is neutral.
                    // c*(1-c) tapers color changes to zero at black and white.
                    let rr = red * gain
                    let gg = green * gain
                    let bb = blue * gain
                    let shift = warmth * 0.07 * min(rr * (1 - rr), gg * (1 - gg), bb * (1 - bb))
                    // Keep weighted luminance stable when changing the color balance.
                    cube.append(Float(rr + shift))
                    cube.append(Float(gg - shift * (0.2126 - 0.0722) / 0.7152))
                    cube.append(Float(bb - shift))
                    cube.append(1)
                }
            }
        }
        let filter = CIFilter.colorCube()
        filter.inputImage = image
        filter.cubeDimension = Float(dimension)
        filter.cubeData = cube.withUnsafeBufferPointer { Data(buffer: $0) }
        guard let output = filter.outputImage else { throw ImageServiceError.invalidImage }
        return output.cropped(to: image.extent)
    }

    private static func faceMask(_ faces: [CGRect], extent: CGRect) -> CIImage? {
        guard !faces.isEmpty, extent.width > 0, extent.height > 0 else { return nil }
        // A normalized mask gives the same feather width at either output size.
        let scale = 512 / max(extent.width, extent.height)
        let width = max(1, Int((extent.width * scale).rounded()))
        let height = max(1, Int((extent.height * scale).rounded()))
        guard let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(gray: 1, alpha: 1)
        var drewFace = false
        for face in faces {
            guard face.origin.x.isFinite, face.origin.y.isFinite,
                  face.width.isFinite, face.height.isFinite else { continue }
            let box = face.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
            guard !box.isNull, box.width > 0, box.height > 0 else { continue }
            let rect = CGRect(x: box.minX * CGFloat(width), y: box.minY * CGFloat(height),
                              width: box.width * CGFloat(width), height: box.height * CGFloat(height))
            context.fillEllipse(in: rect.insetBy(dx: rect.width * 0.08, dy: rect.height * 0.05))
            drewFace = true
        }
        guard drewFace, let mask = context.makeImage() else { return nil }
        return CIImage(cgImage: mask)
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: max(1, Double(min(width, height)) * 0.015)])
            .cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
            .transformed(by: CGAffineTransform(scaleX: extent.width / CGFloat(width), y: extent.height / CGFloat(height)))
            .transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
            .cropped(to: extent)
    }
}

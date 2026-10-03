import CoreGraphics
import CoreImage
import ImageIO
import Vision

@main
struct FaceSmoothingValidation {
    static func main() throws {
        guard CommandLine.arguments.count == 3 else {
            fatalError("Usage: validate-face-smoothing-macos <input-image> <output-image>")
        }
        let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
        guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
              let original = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            fatalError("Could not read input image: \(inputURL.path)")
        }

        let request = VNDetectFaceLandmarksRequest()
        try VNImageRequestHandler(cgImage: original, orientation: .up).perform([request])
        let faces = request.results ?? []
        let landmarkFaces = faces.filter { $0.landmarks != nil }.count
        guard faces.count == 1, landmarkFaces == 1 else {
            fatalError("Expected one face with landmarks; found \(faces.count) face(s), \(landmarkFaces) landmark set(s)")
        }

        let input = CIImage(cgImage: original)
        let output = try FaceSkinSmoother.apply(to: input, source: original, allIntensity: 0.8, faceIntensities: [:])
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CIContext(options: [.workingColorSpace: colorSpace])
        guard let rendered = context.createCGImage(output, from: input.extent, format: .RGBA8, colorSpace: colorSpace),
              let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, "public.png" as CFString, 1, nil) else {
            fatalError("Could not render output image")
        }
        CGImageDestinationAddImage(destination, rendered, nil)
        guard CGImageDestinationFinalize(destination) else { fatalError("Could not save output image") }

        func render(_ image: CIImage) -> CGImage {
            context.createCGImage(image, from: input.extent, format: .RGBA8, colorSpace: colorSpace)!
        }
        // Compare identical rendering/color-conversion paths, not decoded JPEG
        // bytes against a color-managed output.
        let before = pixels(render(input), colorSpace: colorSpace)
        let after = pixels(rendered, colorSpace: colorSpace)
        let zero = try FaceSkinSmoother.apply(to: input, source: original, allIntensity: 0, faceIntensities: [:])
        guard pixels(render(zero), colorSpace: colorSpace) == before else {
            fatalError("Zero intensity changed source pixels")
        }
        let fullBlur = input.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [
            kCIInputRadiusKey: max(1, min(input.extent.width, input.extent.height) * 0.004)
        ]).cropped(to: input.extent)
        let blurred = pixels(render(fullBlur), colorSpace: colorSpace)
        let box = faces[0].boundingBox
        // CGContext pixel rows use the same bottom-left coordinates as Vision.
        let faceRect = CGRect(x: box.minX * CGFloat(original.width), y: box.minY * CGFloat(original.height),
                              width: box.width * CGFloat(original.width), height: box.height * CGFloat(original.height))
        let featherMargin = max(1, min(input.extent.width, input.extent.height) * 0.012) * 4
        let protectedBackground = faceRect.insetBy(dx: -featherMargin, dy: -featherMargin)
        var faceDelta = 0.0
        var blurDelta = 0.0
        var faceSamples = 0
        var backgroundMaxDelta = 0
        for y in 0..<original.height {
            for x in 0..<original.width {
                let point = CGPoint(x: x, y: y)
                let offset = (y * original.width + x) * 4
                for channel in 0..<3 {
                    let delta = abs(Int(before[offset + channel]) - Int(after[offset + channel]))
                    if faceRect.contains(point) {
                        faceDelta += Double(delta)
                        blurDelta += Double(abs(Int(before[offset + channel]) - Int(blurred[offset + channel])))
                        faceSamples += 1
                    } else if !protectedBackground.contains(point) {
                        backgroundMaxDelta = max(backgroundMaxDelta, delta)
                    }
                }
            }
        }
        guard faceSamples > 0, faceDelta > 0 else { fatalError("No effect inside detected face") }
        guard faceDelta < blurDelta else { fatalError("Partial smoothing must preserve more source detail than full blur") }
        guard backgroundMaxDelta <= 1 else { fatalError("Effect leaked outside feathered face: \(backgroundMaxDelta)") }
        print("PASS: one landmark face; zero intensity preserves all pixels")
        print("Face mean delta: \(faceDelta / Double(faceSamples)); full blur: \(blurDelta / Double(faceSamples))")
        print("Background max delta: \(backgroundMaxDelta); output: \(outputURL.path)")
        print("Scope: macOS synthetic regression only; natural skin quality and iPhone Vision remain unverified.")
    }

    private static func pixels(_ image: CGImage, colorSpace: CGColorSpace) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                                    bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                    space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return bytes
    }
}

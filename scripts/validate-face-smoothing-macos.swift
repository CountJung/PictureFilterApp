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

        let before = pixels(original, colorSpace: colorSpace)
        let after = pixels(rendered, colorSpace: colorSpace)
        var changedPixels = 0
        var changedBounds = CGRect.null
        for y in 0..<original.height {
            for x in 0..<original.width {
                let offset = (y * original.width + x) * 4
                let delta = max(abs(Int(before[offset]) - Int(after[offset])),
                                max(abs(Int(before[offset + 1]) - Int(after[offset + 1])),
                                    abs(Int(before[offset + 2]) - Int(after[offset + 2]))))
                if delta > 8 {
                    changedPixels += 1
                    changedBounds = changedBounds.union(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        guard changedPixels > 1_000 else {
            fatalError("Skin smoothing did not change enough pixels (\(changedPixels))")
        }
        print("Detected \(faces.count) face with landmarks; changed \(changedPixels) pixels. Output: \(outputURL.path)")
        print("Changed pixel bounds: \(changedBounds.integral)")
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

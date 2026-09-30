import XCTest
import UIKit
@testable import PictureFilterApp

final class BrightPortraitTests: XCTestCase {
    private struct Faces: PortraitFaceDetecting {
        var boxes: [CGRect]
        func faces(in image: CGImage) -> [CGRect] { boxes }
    }

    private func settings(intensity: Double = 0.5, brightness: Double = 0.65,
                          warmth: Double = 0.15) -> EditSettings {
        var value = EditSettings()
        value.select(.brightPortrait)
        value.setIntensity(intensity)
        value.setPortraitBrightness(brightness)
        value.setPortraitWarmth(warmth)
        return value
    }

    private func patches(_ colors: [[Int]], size: Int = 64) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: size * colors.count, height: size), format: format).image { context in
            for (index, c) in colors.enumerated() {
                UIColor(red: CGFloat(c[0]) / 255, green: CGFloat(c[1]) / 255, blue: CGFloat(c[2]) / 255, alpha: 1).setFill()
                context.fill(CGRect(x: index * size, y: 0, width: size, height: size))
            }
        }.pngData())
    }

    private func pixel(_ data: Data, x: Int, y: Int = 32) throws -> [Int] {
        let image = try XCTUnwrap(UIImage(data: data)?.cgImage)
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return (0..<3).map { Int(bytes[(y * image.width + x) * 4 + $0]) }
    }

    func testZeroStrengthAndNeutralControlsAreIdentityInPreviewAndExport() async throws {
        let input = try patches([[60, 35, 25], [180, 130, 100], [248, 248, 248]])
        let renderer = FilterRenderer(portraitFaceDetector: Faces(boxes: []))
        for output in [false, true] {
            func render(_ s: EditSettings) async throws -> Data {
                if output { return try await renderer.renderOutput(input, settings: s) }
                return try await renderer.render(input, settings: s)
            }
            let original = try await render(EditSettings())
            let zero = try await render(settings(intensity: 0, brightness: 1, warmth: 1))
            let neutral = try await render(settings(intensity: 1, brightness: 0, warmth: 0))
            XCTAssertEqual(zero, original)
            XCTAssertEqual(neutral, original)
        }
    }

    func testDefaultAndMaximumLiftShadowsAndPreserveHighlightStepsWithoutVision() async throws {
        let levels = [0, 32, 64, 128, 192, 224, 240, 248, 255]
        let input = try patches(levels.map { [$0, $0, $0] })
        let renderer = FilterRenderer(portraitFaceDetector: Faces(boxes: []))
        for strength in [0.5, 1.0] {
            let output = try await renderer.render(input, settings: settings(intensity: strength, brightness: 1, warmth: 0))
            let values = try levels.indices.map { try pixel(output, x: $0 * 64 + 32)[0] }
            XCTAssertEqual(values.first, 0)
            XCTAssertEqual(values.last, 255)
            for i in 1..<values.count { XCTAssertGreaterThan(values[i], values[i - 1]) }
            for i in 1...4 { XCTAssertGreaterThan(values[i], levels[i] + 1) }
            XCTAssertLessThanOrEqual(values[7] - levels[7], 2, "Near-white detail must not be lifted into clipping")
        }
    }

    func testSkinColorRangeAndWarmthRemainBounded() async throws {
        let colors = [[70, 43, 30], [130, 85, 60], [190, 137, 105], [235, 200, 177], [255, 40, 20], [250, 250, 250]]
        let input = try patches(colors)
        let renderer = FilterRenderer(portraitFaceDetector: Faces(boxes: []))
        for warmth in [-1.0, 0, 1] {
            let output = try await renderer.render(input, settings: settings(intensity: 1, brightness: 1, warmth: warmth))
            for i in 0..<4 {
                let p = try pixel(output, x: i * 64 + 32)
                func luminance(_ c: [Int]) -> Double {
                    Double(c[0]) * 0.2126 + Double(c[1]) * 0.7152 + Double(c[2]) * 0.0722
                }
                XCTAssertGreaterThan(luminance(p), luminance(colors[i]))
                XCTAssertGreaterThan(p[0], p[1]); XCTAssertGreaterThan(p[1], p[2])
                XCTAssertLessThan(p.max()!, 255)
                let before = Double(colors[i][0] - colors[i][2]) / Double(colors[i][0])
                let after = Double(p[0] - p[2]) / Double(p[0])
                XCTAssertLessThan(abs(after - before), 0.08, "Avoid a large skin saturation shift")
            }
            let white = try pixel(output, x: 5 * 64 + 32)
            XCTAssertLessThanOrEqual(white.max()! - white.min()!, 1)
        }
    }

    func testFaceRegionsGetExtraLiftAndMultipleFacesAreIndependentOfSelection() async throws {
        let input = try patches([[128, 100, 80]], size: 512)
        let boxes = [CGRect(x: 0.05, y: 0.1, width: 0.35, height: 0.8), CGRect(x: 0.6, y: 0.1, width: 0.35, height: 0.8)]
        let renderer = FilterRenderer(portraitFaceDetector: Faces(boxes: boxes))
        let fallback = FilterRenderer(portraitFaceDetector: Faces(boxes: []))
        var value = settings(intensity: 1)
        let global = try await fallback.render(input, settings: value)
        let result = try await renderer.render(input, settings: value)
        for x in [115, 397] {
            XCTAssertGreaterThan(try pixel(result, x: x, y: 256)[0], try pixel(global, x: x, y: 256)[0] + 3)
        }
        XCTAssertEqual(try pixel(result, x: 256, y: 256), try pixel(global, x: 256, y: 256))
        value.selectSkinFace(1)
        let selected = try await renderer.render(input, settings: value)
        XCTAssertEqual(selected, result)
    }

    func testPreviewAndJPEGExportAgreeAtCorrespondingFaceAndBackgroundLocations() async throws {
        let input = try patches([[128, 100, 80]], size: 1024)
        let renderer = FilterRenderer(portraitFaceDetector: Faces(boxes: [CGRect(x: 0.1, y: 0.1, width: 0.4, height: 0.8)]))
        let preview = try await renderer.render(input, settings: settings(), maxDimension: 512)
        let output = try await renderer.renderOutput(input, settings: settings(), maxDimension: 1024)
        XCTAssertEqual(UIImage(data: output)?.cgImage?.width, 1024)
        for x in [150, 430] {
            let a = try pixel(preview, x: x, y: 256)
            let b = try pixel(output, x: x * 2, y: 512)
            for c in 0..<3 { XCTAssertEqual(Double(a[c]), Double(b[c]), accuracy: 3) }
        }
    }

    func testSimulatorProductionDetectorStillProducesUsablePreset() async throws {
        let input = try patches([[128, 100, 80]])
        let renderer = FilterRenderer()
        let original = try await renderer.render(input, settings: EditSettings())
        let result = try await renderer.render(input, settings: settings())
        XCTAssertNotEqual(result, original, "No-face or failed detection must retain global tone correction")
    }

    func testSyntheticPortraitReviewAttachments() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "synthetic-face", withExtension: "jpg"))
        let input = try Data(contentsOf: url)
        let renderer = FilterRenderer(portraitFaceDetector: Faces(boxes: [CGRect(x: 0.28, y: 0.18, width: 0.44, height: 0.64)]))
        for strength in [0.0, 0.5, 1.0] {
            let output = try await renderer.render(input, settings: settings(intensity: strength), maxDimension: 1000)
            let attachment = XCTAttachment(image: try XCTUnwrap(UIImage(data: output)))
            attachment.name = "PF027-synthetic-portrait-\(strength)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}

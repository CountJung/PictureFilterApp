import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import PictureFilterApp

final class FilterRendererTests: XCTestCase {
    private func settings(_ filter: PhotoFilter, _ intensity: Double) -> EditSettings {
        var value = EditSettings()
        value.select(filter)
        value.setIntensity(intensity)
        return value
    }

    private func pixel(_ data: Data) throws -> [Int] {
        let image = try XCTUnwrap(UIImage(data: data)?.cgImage)
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        let index = ((image.height / 2) * image.width + image.width / 3) * 4
        return bytes[index..<index+3].map(Int.init)
    }

    func testZeroStrengthMatchesOriginalForEveryFilter() async throws {
        let input = try await BundleSampleInput().load(SampleImage.catalog[0])
        let renderer = FilterRenderer()
        let original = try await renderer.render(input, settings: settings(.original, 1))
        for filter in PhotoFilter.allCases {
            let output = try await renderer.render(input, settings: settings(filter, 0))
            XCTAssertEqual(output, original)
        }
    }

    func testFullStrengthFiltersChangePixelsAsExpected() async throws {
        let input = try await BundleSampleInput().load(SampleImage.catalog[0])
        let renderer = FilterRenderer()
        let original = try pixel(await renderer.render(input, settings: settings(.original, 1)))
        let gray = try pixel(await renderer.render(input, settings: settings(.monochrome, 1)))
        XCTAssertLessThanOrEqual(abs(gray[0] - gray[1]), 1)
        XCTAssertLessThanOrEqual(abs(gray[1] - gray[2]), 1)
        XCTAssertNotEqual(gray, original)
        let warm = try pixel(await renderer.render(input, settings: settings(.warm, 1)))
        let cool = try pixel(await renderer.render(input, settings: settings(.cool, 1)))
        XCTAssertGreaterThan(warm[0], cool[0])
        XCTAssertLessThan(warm[2], cool[2])
        let sepia = try pixel(await renderer.render(input, settings: settings(.sepia, 1)))
        XCTAssertGreaterThan(sepia[0], sepia[2])
    }

    func testIntermediateStrengthAndNonAccumulation() async throws {
        let input = try await BundleSampleInput().load(SampleImage.catalog[0])
        let renderer = FilterRenderer()
        let start = try pixel(await renderer.render(input, settings: settings(.original, 1)))
        let fullData = try await renderer.render(input, settings: settings(.sepia, 1))
        let full = try pixel(fullData)
        let half = try pixel(await renderer.render(input, settings: settings(.sepia, 0.5)))
        for channel in 0..<3 {
            XCTAssertGreaterThanOrEqual(half[channel], min(start[channel], full[channel]) - 1)
            XCTAssertLessThanOrEqual(half[channel], max(start[channel], full[channel]) + 1)
        }
        _ = try await renderer.render(input, settings: settings(.cool, 1))
        let repeated = try await renderer.render(input, settings: settings(.sepia, 1))
        XCTAssertEqual(repeated, fullData)
    }

    func testPreviewDimensionsAndInvalidData() async throws {
        let renderer = FilterRenderer()
        let input = try await BundleSampleInput().load(SampleImage.catalog[1])
        let output = try await renderer.render(input, settings: settings(.warm, 1), maxDimension: 160)
        let image = try XCTUnwrap(UIImage(data: output))
        XCTAssertEqual(image.size, CGSize(width: 120, height: 160))
        XCTAssertEqual(image.imageOrientation, .up)
        do {
            _ = try await renderer.render(Data(), settings: EditSettings())
            XCTFail("Invalid image must fail")
        } catch { XCTAssertEqual(error as? ImageServiceError, .invalidImage) }
    }

    func testOutputUsesJPEGAndPreservesSourceDimensionsWithinLimit() async throws {
        let input = try await BundleSampleInput().load(SampleImage.catalog[0])
        let output = try await FilterRenderer().renderOutput(input, settings: settings(.sepia, 0.5))
        let source = try XCTUnwrap(CGImageSourceCreateWithData(output as CFData, nil))
        XCTAssertEqual(CGImageSourceGetType(source) as String?, UTType.jpeg.identifier)
        let image = try XCTUnwrap(UIImage(data: output))
        XCTAssertEqual(image.size, CGSize(width: 640, height: 480))
        XCTAssertEqual(image.imageOrientation, .up)
    }

    func testSkinSmoothingPathProducesDecodableOutput() async throws {
        let input = try await BundleSampleInput().load(SampleImage.catalog[0])
        var value = EditSettings()
        value.setSkinSmoothing(0.8)
        let output = try await FilterRenderer().render(input, settings: value)
        XCTAssertNotNil(UIImage(data: output))
    }

    func testSyntheticPortraitFixtureExercisesSkinSmoothingRenderPath() async throws {
        let url = try XCTUnwrap(Bundle(for: FilterRendererTests.self).url(forResource: "synthetic-face", withExtension: "jpg"))
        let input = try Data(contentsOf: url)
        var value = EditSettings()
        value.setSkinSmoothing(0.8)
        let output = try await FilterRenderer().render(input, settings: value)
        XCTAssertNotNil(UIImage(data: output))
    }
}

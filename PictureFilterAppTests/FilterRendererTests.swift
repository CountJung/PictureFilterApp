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

    private func highResolutionFixture() throws -> Data {
        let url = try XCTUnwrap(Bundle(for: FilterRendererTests.self)
            .url(forResource: "synthetic-high-resolution", withExtension: "jpg"))
        return try Data(contentsOf: url)
    }

    private func dimensions(_ data: Data) throws -> (width: Int, height: Int) {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        let width = try XCTUnwrap(properties[kCGImagePropertyPixelWidth] as? Int)
        let height = try XCTUnwrap(properties[kCGImagePropertyPixelHeight] as? Int)
        return (width, height)
    }

    private func averageColor(_ data: Data, xFraction: Double) throws -> [Double] {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 1200
        ] as CFDictionary))
        let width = image.width
        let height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        let centerX = Int(Double(width) * xFraction)
        let centerY = height / 2
        var totals = [Double](repeating: 0, count: 3)
        var count = 0
        for y in (centerY - 8)...(centerY + 8) {
            for x in (centerX - 8)...(centerX + 8) {
                let offset = (y * width + x) * 4
                for channel in 0..<3 { totals[channel] += Double(bytes[offset + channel]) }
                count += 1
            }
        }
        return totals.map { $0 / Double(count) }
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

    func testHighResolutionOutputPreservesDimensionsAndChartColors() async throws {
        let input = try highResolutionFixture()
        let inputDimensions = try dimensions(input)
        XCTAssertEqual(inputDimensions.width, 4032)
        XCTAssertEqual(inputDimensions.height, 3024)

        let output = try await FilterRenderer().renderOutput(input, settings: EditSettings(), maxDimension: 4096)
        let outputDimensions = try dimensions(output)
        XCTAssertEqual(outputDimensions.width, 4032)
        XCTAssertEqual(outputDimensions.height, 3024)

        let expected: [(x: Double, rgb: [Double])] = [
            (1.0 / 24.0, [18, 18, 18]),
            (3.0 / 24.0, [230, 40, 45]),
            (5.0 / 24.0, [245, 125, 35]),
            (7.0 / 24.0, [245, 220, 35]),
            (9.0 / 24.0, [50, 185, 75]),
            (11.0 / 24.0, [30, 160, 190]),
            (13.0 / 24.0, [40, 90, 220]),
            (15.0 / 24.0, [125, 60, 190]),
            (17.0 / 24.0, [240, 115, 155]),
            (19.0 / 24.0, [180, 180, 180]),
            (21.0 / 24.0, [70, 70, 70]),
            (23.0 / 24.0, [245, 245, 245])
        ]
        for patch in expected {
            let actual = try averageColor(output, xFraction: patch.x)
            for channel in 0..<3 {
                XCTAssertLessThanOrEqual(abs(actual[channel] - patch.rgb[channel]), 12,
                    "Chart color drift at x=\(patch.x), channel=\(channel)")
            }
        }
    }

    func testRepeatedHighResolutionPreviewAndOutputRecordsSpeedAndThermalState() async throws {
        let input = try highResolutionFixture()
        let renderer = FilterRenderer()
        let thermalBefore = ProcessInfo.processInfo.thermalState
        var thermalSamples = [String(describing: thermalBefore)]
        var elapsedMilliseconds: [Double] = []

        for iteration in 0..<40 {
            let start = ProcessInfo.processInfo.systemUptime
            let preview = try await renderer.render(input, settings: settings(.warm, 0.7), maxDimension: 1600)
            let previewSize = try dimensions(preview)
            XCTAssertEqual(previewSize.width, 1600)
            XCTAssertEqual(previewSize.height, 1200)

            let output = try await renderer.renderOutput(input, settings: settings(.sepia, 0.6), maxDimension: 4096)
            let outputSize = try dimensions(output)
            XCTAssertEqual(outputSize.width, 4032)
            XCTAssertEqual(outputSize.height, 3024)
            elapsedMilliseconds.append((ProcessInfo.processInfo.systemUptime - start) * 1_000)
            if (iteration + 1).isMultiple(of: 10) {
                thermalSamples.append(String(describing: ProcessInfo.processInfo.thermalState))
            }
        }

        let thermalAfter = ProcessInfo.processInfo.thermalState
        let sortedTimes = elapsedMilliseconds.sorted()
        let averageTime = elapsedMilliseconds.reduce(0, +) / Double(elapsedMilliseconds.count)
        let attachment = XCTAttachment(string: "12 MP iPhone render workload (40 preview + output cycles)\n"
            + "average_ms=\(String(format: "%.1f", averageTime)), "
            + "median_ms=\(String(format: "%.1f", sortedTimes[sortedTimes.count / 2])), "
            + "max_ms=\(String(format: "%.1f", sortedTimes.last ?? 0))\n"
            + "thermal_samples_every_10_cycles=\(thermalSamples.joined(separator: ",")), "
            + "thermal_after=\(thermalAfter)")
        attachment.name = "PF-019 high-resolution timing and thermal sample"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
import Vision
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

    private func detectedFaceCount(_ data: Data) throws -> Int {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let request = VNDetectFaceRectanglesRequest()
        try VNImageRequestHandler(cgImage: image, orientation: .up).perform([request])
        return request.results?.count ?? 0
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

    private func portraitPairFixture() throws -> Data {
        let url = try XCTUnwrap(Bundle(for: FilterRendererTests.self).url(forResource: "synthetic-face", withExtension: "jpg"))
        let face = try XCTUnwrap(UIImage(data: Data(contentsOf: url))?.cgImage)
        let canvas = CGSize(width: 1320, height: 660)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: canvas, format: format).image { renderer in
            UIColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1).setFill()
            renderer.fill(CGRect(origin: .zero, size: canvas))
            renderer.cgContext.draw(face, in: CGRect(x: 0, y: 0, width: 620, height: 620))
            renderer.cgContext.draw(face, in: CGRect(x: 700, y: 0, width: 620, height: 620))
        }
        return try XCTUnwrap(image.jpegData(compressionQuality: 1))
    }

    private func meanDifference(_ first: Data, _ second: Data, xRange: Range<Int>) throws -> Double {
        let a = try XCTUnwrap(UIImage(data: first)?.cgImage)
        let b = try XCTUnwrap(UIImage(data: second)?.cgImage)
        XCTAssertEqual(a.width, b.width)
        XCTAssertEqual(a.height, b.height)
        var aBytes = [UInt8](repeating: 0, count: a.width * a.height * 4)
        var bBytes = [UInt8](repeating: 0, count: b.width * b.height * 4)
        func draw(_ image: CGImage, into bytes: inout [UInt8]) throws {
            try bytes.withUnsafeMutableBytes { buffer in
                let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                    bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            }
        }
        try draw(a, into: &aBytes)
        try draw(b, into: &bBytes)
        var total = 0
        var pixels = 0
        for y in 0..<a.height {
            for x in xRange {
                let offset = (y * a.width + x) * 4
                for channel in 0..<3 { total += abs(Int(aBytes[offset + channel]) - Int(bBytes[offset + channel])) }
                pixels += 3
            }
        }
        return Double(total) / Double(pixels)
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

    func testExpressiveStylesRenderDistinctLooksOnPortraitAndLandscapeSamples() async throws {
        let inputService = BundleSampleInput()
        let renderer = FilterRenderer()
        for sample in [SampleImage.catalog[0], SampleImage.catalog[1]] {
            let input = try await inputService.load(sample)
            var outputs = [Data]()
            for style in PhotoFilter.styles {
                outputs.append(try await renderer.render(input, settings: settings(style, 1)))
            }
            XCTAssertEqual(Set(outputs).count, PhotoFilter.styles.count, "Each style should have a distinct render for \(sample.title)")
            let original = try await renderer.render(input, settings: settings(.original, 1))
            XCTAssertTrue(outputs.allSatisfy { $0 != original }, "Each style should differ from the original for \(sample.title)")
        }
    }

    func testExpressiveStylesKeepGeneratedPortraitFaceDetectable() async throws {
        let url = try XCTUnwrap(Bundle(for: FilterRendererTests.self).url(forResource: "synthetic-face", withExtension: "jpg"))
        let input = try Data(contentsOf: url)
        let originalFaceCount = try detectedFaceCount(input)
        XCTAssertEqual(originalFaceCount, 1)

        let renderer = FilterRenderer()
        for style in PhotoFilter.styles {
            let output = try await renderer.render(input, settings: settings(style, 1), maxDimension: 1600)
            let outputDimensions = try dimensions(output)
            let inputDimensions = try dimensions(input)
            XCTAssertEqual(outputDimensions.width, inputDimensions.width)
            XCTAssertEqual(outputDimensions.height, inputDimensions.height)
            XCTAssertEqual(try detectedFaceCount(output), originalFaceCount, "\(style.title) should preserve portrait geometry")
            let attachment = XCTAttachment(data: output, uniformTypeIdentifier: "public.png")
            attachment.name = "PF-023-\(style.rawValue)-synthetic-portrait"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testExpressiveStylesRespectIntensityAndRenderFromOriginal() async throws {
        let input = try await BundleSampleInput().load(SampleImage.catalog[0])
        let renderer = FilterRenderer()
        let original = try await renderer.render(input, settings: settings(.original, 1))
        for style in PhotoFilter.styles {
            let zero = try await renderer.render(input, settings: settings(style, 0))
            XCTAssertEqual(zero, original)
            let half = try await renderer.render(input, settings: settings(style, 0.5))
            let full = try await renderer.render(input, settings: settings(style, 1))
            XCTAssertNotEqual(half, original)
            XCTAssertNotEqual(full, original)
            let repeated = try await renderer.render(input, settings: settings(style, 1))
            XCTAssertEqual(repeated, full)
        }
    }

    func testExpressiveStylesFollowTheirIntendedColorDirection() async throws {
        let input = try highResolutionFixture()
        let renderer = FilterRenderer()
        let coolPatch = 11.0 / 24.0
        let bluePatch = 13.0 / 24.0
        let redPatch = 3.0 / 24.0
        let originalCool = try averageColor(input, xFraction: coolPatch)
        let originalBlue = try averageColor(input, xFraction: bluePatch)
        let originalRed = try averageColor(input, xFraction: redPatch)
        let softFilm = try await renderer.render(input, settings: settings(.softFilm, 1), maxDimension: 4096)
        let goldenHour = try await renderer.render(input, settings: settings(.goldenHour, 1), maxDimension: 4096)
        let cinematic = try await renderer.render(input, settings: settings(.cinematic, 1), maxDimension: 4096)
        let vivid = try await renderer.render(input, settings: settings(.vivid, 1), maxDimension: 4096)

        let softCool = try averageColor(softFilm, xFraction: coolPatch)
        let goldenRed = try averageColor(goldenHour, xFraction: redPatch)
        let cinematicBlue = try averageColor(cinematic, xFraction: bluePatch)
        let vividCool = try averageColor(vivid, xFraction: coolPatch)
        XCTAssertLessThan(abs(softCool[1] - softCool[2]), abs(originalCool[1] - originalCool[2]), "Soft Film should mute saturation")
        XCTAssertGreaterThan(goldenRed[0] - goldenRed[2], originalRed[0] - originalRed[2], "Golden Hour should warm the image")
        XCTAssertGreaterThan(cinematicBlue[2] - cinematicBlue[0], originalBlue[2] - originalBlue[0], "Cinematic should cool blue tones")
        XCTAssertGreaterThan(abs(vividCool[1] - vividCool[2]), abs(originalCool[1] - originalCool[2]), "Vivid should increase color separation")
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

    func testPersonSelectionSmoothsOnlySelectedSyntheticPortrait() async throws {
        let input = try portraitPairFixture()
        let renderer = FilterRenderer()
        let faceCount = await renderer.faceCount(in: input)
        XCTAssertEqual(faceCount, 2)

        var selectedLeft = EditSettings()
        selectedLeft.selectSkinFace(0)
        selectedLeft.setSkinSmoothing(1)
        let leftOutput = try await renderer.render(input, settings: selectedLeft, maxDimension: 1600)
        XCTAssertGreaterThan(try meanDifference(input, leftOutput, xRange: 0..<620), 0.01)
        XCTAssertEqual(try meanDifference(input, leftOutput, xRange: 700..<1320), 0, accuracy: 0.001)

        var selectedRight = EditSettings()
        selectedRight.selectSkinFace(1)
        selectedRight.setSkinSmoothing(1)
        let rightOutput = try await renderer.render(input, settings: selectedRight, maxDimension: 1600)
        XCTAssertEqual(try meanDifference(input, rightOutput, xRange: 0..<620), 0, accuracy: 0.001)
        XCTAssertGreaterThan(try meanDifference(input, rightOutput, xRange: 700..<1320), 0.01)
    }

    func testPortraitLightChangesOnlySelectedSyntheticFace() async throws {
        let input = try portraitPairFixture()
        do {
            guard try detectedFaceCount(input) == 2 else { throw XCTSkip("Vision did not detect the synthetic faces on this runtime.") }
        } catch is XCTSkip {
            throw XCTSkip("Vision face analysis is unavailable on this runtime.")
        } catch {
            throw XCTSkip("Vision face analysis is unavailable on this runtime: \(error.localizedDescription)")
        }

        var settings = EditSettings()
        settings.selectSkinFace(0)
        settings.setPortraitLight(1)
        let renderer = FilterRenderer()
        let original = try await renderer.render(input, settings: EditSettings(), maxDimension: 1400)
        let lit = try await renderer.render(input, settings: settings, maxDimension: 1400)
        XCTAssertGreaterThan(try meanDifference(original, lit, xRange: 25..<640), 0.1)
        XCTAssertLessThan(try meanDifference(original, lit, xRange: 680..<1310), 0.01)
    }

    func testBothPeopleKeepTheirEditsAcrossSelectionInPreviewAndExport() async throws {
        let input = try portraitPairFixture()
        let renderer = FilterRenderer()
        let faceCount = await renderer.faceCount(in: input)
        XCTAssertEqual(faceCount, 2, "This regression requires real Vision inference.")
        for lighting in [false, true] {
            var settings = EditSettings()
            settings.selectSkinFace(0)
            if lighting { settings.setPortraitLight(0.8) } else { settings.setSkinSmoothing(0.8) }
            settings.selectSkinFace(1)
            if lighting { settings.setPortraitLight(0.4) } else { settings.setSkinSmoothing(0.4) }
            for exporting in [false, true] {
                func render(_ value: EditSettings) async throws -> Data {
                    if exporting { return try await renderer.renderOutput(input, settings: value, maxDimension: 4096) }
                    return try await renderer.render(input, settings: value, maxDimension: 1600)
                }
                let original = try await render(EditSettings())
                let both = try await render(settings)
                // This is a preservation regression, not a minimum-strength quality test.
                // Weak smoothing can change very few JPEG pixels, but must not vanish.
                XCTAssertGreaterThan(try meanDifference(original, both, xRange: 25..<620), 0)
                XCTAssertGreaterThan(try meanDifference(original, both, xRange: 700..<1310), 0)
                for selected: Int? in [0, 1, nil] {
                    settings.selectSkinFace(selected)
                    let output = try await render(settings)
                    XCTAssertEqual(output, both, "Changing selection must not change preview or export.")
                }
            }
        }
    }

    func testIndividualResetRestoresOnlyThatPersonDespiteNonzeroGlobalStrength() async throws {
        let input = try portraitPairFixture()
        let renderer = FilterRenderer()
        for lighting in [false, true] {
            var settings = EditSettings()
            if lighting { settings.setPortraitLight(0.6) } else { settings.setSkinSmoothing(0.6) }
            let allPeople = settings
            settings.selectSkinFace(0)
            if lighting { settings.resetSelectedPortraitEffects() } else { settings.resetSelectedSkinSmoothing() }
            var rightOnly = EditSettings()
            rightOnly.selectSkinFace(1)
            if lighting { rightOnly.setPortraitLight(0.6) } else { rightOnly.setSkinSmoothing(0.6) }
            for exporting in [false, true] {
                func render(_ value: EditSettings) async throws -> Data {
                    if exporting { return try await renderer.renderOutput(input, settings: value, maxDimension: 4096) }
                    return try await renderer.render(input, settings: value, maxDimension: 1600)
                }
                let original = try await render(EditSettings())
                let both = try await render(allPeople)
                let reset = try await render(settings)
                let expected = try await render(rightOnly)
                XCTAssertEqual(reset, expected)
                XCTAssertEqual(try meanDifference(original, reset, xRange: 25..<620), 0, accuracy: 0.001)
                XCTAssertEqual(try meanDifference(both, reset, xRange: 700..<1310), 0, accuracy: 0.001)
                XCTAssertGreaterThan(try meanDifference(original, reset, xRange: 700..<1310), 0.01)
            }
        }
    }

    func testBackgroundBlurUsesOnDevicePersonMask() async throws {
        let input = try portraitPairFixture()
        var settings = EditSettings()
        settings.setBackgroundBlur(1)
        let renderer = FilterRenderer()
        let original = try await renderer.render(input, settings: EditSettings(), maxDimension: 1400)
        let blurred = try await renderer.render(input, settings: settings, maxDimension: 1400)
        XCTAssertGreaterThan(try meanDifference(original, blurred, xRange: 0..<1320), 0.01)
        let originalSubject = try averageColor(original, xFraction: 0.24)
        let blurredSubject = try averageColor(blurred, xFraction: 0.24)
        XCTAssertLessThan(zip(originalSubject, blurredSubject).map { abs($0 - $1) }.max() ?? 0, 1)
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

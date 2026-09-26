import XCTest
import UIKit
@testable import PictureFilterApp

final class ImageServicesTests: XCTestCase {
    func testBundledSamplesDecodeWithExpectedDimensions() async throws {
        let input = BundleSampleInput()
        for (sample, size) in zip(SampleImage.catalog, [CGSize(width: 640, height: 480), CGSize(width: 480, height: 640)]) {
            let data = try await input.load(sample)
            let image = try XCTUnwrap(UIImage(data: data))
            XCTAssertEqual(image.size, size)
            XCTAssertEqual(image.imageOrientation, .up)
        }
    }

    func testMemorySaveRoundTripsAndKeepsSeparateResults() async throws {
        let data = try await BundleSampleInput().load(SampleImage.catalog[0])
        let output = MemoryImageOutput()
        let first = try await output.save(data)
        let second = try await output.save(data)
        XCTAssertNotEqual(first, second)
        let restored = await output.image(for: first)
        XCTAssertEqual(restored, data)
        let count = await output.count
        XCTAssertEqual(count, 2)
        await output.removeAll()
        let emptyCount = await output.count
        XCTAssertEqual(emptyCount, 0)
    }

    func testSimulatorPhotoLibrarySaveUsesMemoryService() async throws {
        let data = try await BundleSampleInput().load(SampleImage.catalog[0])
        let output = MemoryImageOutput()
        try await output.saveToPhotoLibrary(data)
        let count = await output.count
        XCTAssertEqual(count, 1)
    }

    func testUnknownSampleFails() async {
        do {
            _ = try await BundleSampleInput().load(SampleImage(id: "missing", title: "missing"))
            XCTFail("Unknown sample must fail")
        } catch { XCTAssertEqual(error as? ImageServiceError, .inputUnavailable) }
    }

    func testInjectedInputFailure() async {
        do {
            _ = try await AppServices.failingInput().input.load(SampleImage.catalog[0])
            XCTFail("Input failure must propagate")
        } catch { XCTAssertEqual(error as? ImageServiceError, .inputUnavailable) }
    }

    func testSaveFailuresDoNotStoreImages() async throws {
        let data = try await BundleSampleInput().load(SampleImage.catalog[0])
        for failure in [ImageServiceError.permissionDenied, .saveFailed] {
            let output = MemoryImageOutput(failure: failure)
            let services = AppServices(input: BundleSampleInput(), output: output)
            do {
                try await services.output.saveToPhotoLibrary(data)
                XCTFail("Injected save failure must propagate")
            } catch { XCTAssertEqual(error as? ImageServiceError, failure) }
            let count = await output.count
            XCTAssertEqual(count, 0)
        }
    }

    func testInvalidDataIsRejected() async {
        let output = MemoryImageOutput()
        do {
            _ = try await output.save(Data("not an image".utf8))
            XCTFail("Invalid image must not be saved")
        } catch { XCTAssertEqual(error as? ImageServiceError, .invalidImage) }
        let count = await output.count
        XCTAssertEqual(count, 0)
    }
}

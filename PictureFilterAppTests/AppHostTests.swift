import XCTest
@testable import PictureFilterApp

final class AppHostTests: XCTestCase {
    func testApplicationTargetIsLoaded() {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "com.local.PictureFilterApp")
    }
}

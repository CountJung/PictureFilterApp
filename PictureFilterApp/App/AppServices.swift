import SwiftUI

struct AppServices: Sendable {
    let input: any ImageInputService
    let output: any ImageOutputService

    static func samples() -> AppServices {
        AppServices(input: BundleSampleInput(), output: PhotoLibraryImageOutput())
    }

    static func failingInput() -> AppServices {
        AppServices(input: FailingImageInput(error: .inputUnavailable), output: MemoryImageOutput())
    }

    static func failingSave(_ error: ImageServiceError = .saveFailed) -> AppServices {
        AppServices(input: BundleSampleInput(), output: MemoryImageOutput(failure: error))
    }

    static func slowSave(_ duration: Duration) -> AppServices {
        AppServices(input: BundleSampleInput(), output: MemoryImageOutput(delay: duration))
    }
}

private struct AppServicesKey: EnvironmentKey {
    static let defaultValue = AppServices.samples()
}

extension EnvironmentValues {
    var imageServices: AppServices {
        get { self[AppServicesKey.self] }
        set { self[AppServicesKey.self] = newValue }
    }
}

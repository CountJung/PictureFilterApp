import SwiftUI

@main
struct PictureFilterApp: App {
    private let services: AppServices = {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--ui-test-photo-save-denied") {
            return .failingSave(.permissionDenied)
        }
        if arguments.contains("--ui-test-photo-save-fails") {
            return .failingSave(.saveFailed)
        }
        if arguments.contains("--ui-test-photo-save-slow") {
            return .slowSave(.seconds(5))
        }
        return .samples()
    }()

    var body: some Scene {
        WindowGroup {
            WelcomeView()
                .environment(\.imageServices, services)
        }
    }
}

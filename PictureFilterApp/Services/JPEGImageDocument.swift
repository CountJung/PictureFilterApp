import SwiftUI
import UniformTypeIdentifiers

struct JPEGImageDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.jpeg] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw ImageServiceError.invalidImage
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

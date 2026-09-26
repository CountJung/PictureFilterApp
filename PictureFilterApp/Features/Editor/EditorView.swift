import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

struct EditorView: View {
    let initialSample: SampleImage
    @Environment(\.imageServices) private var services
    @State private var model: EditorModel
    @State private var selectedSample: SampleImage
    @State private var pickerItem: PhotosPickerItem?
    @State private var isShowingPhotoPicker = false
    @State private var isShowingCamera = false
    @State private var isShowingFileImporter = false
    @State private var isShowingFileExporter = false
    @State private var exportDocument: JPEGImageDocument?
    @State private var isSaving = false
    @State private var saveMessage: String?
    @State private var saveRetryTarget: SaveRetryTarget?
    @State private var shouldOpenPhotoSettings = false
    @GestureState private var comparingOriginal = false
    @State private var requestID = UUID()

    init(initialSample: SampleImage) {
        self.initialSample = initialSample
        _model = State(initialValue: EditorModel(sample: initialSample))
        _selectedSample = State(initialValue: initialSample)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(model.sample.title)
                    .font(.headline)
                    .accessibilityIdentifier("sampleTitle")
                Button {
                    isShowingPhotoPicker = true
                } label: {
                    Label("사진 선택", systemImage: "photo.badge.plus")
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.bordered)
                .disabled(isSaving || isShowingFileExporter)
                .accessibilityIdentifier("pickPhoto")
                Button {
                    isShowingCamera = true
                } label: {
                    Label("카메라로 촬영", systemImage: "camera")
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.bordered)
                .disabled(isSaving || isShowingFileExporter)
                .accessibilityIdentifier("capturePhoto")
                photoPreview
                if let errorMessage = model.errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                    Button("다시 시도") { requestID = UUID() }
                }
                if let error = model.renderError {
                    Text(error).foregroundStyle(.red)
                    Button("미리보기 재시도") {
                        model.retryPreview()
                    }
                }
                if let saveMessage {
                    HStack(spacing: 8) {
                        if isSaving { ProgressView().controlSize(.small) }
                        Text(saveMessage).font(.footnote)
                    }
                    .foregroundStyle(shouldOpenPhotoSettings ? Color.red : Color.secondary)
                    .accessibilityIdentifier("saveStatus")
                    if let saveRetryTarget {
                        Button("다시 저장") { retrySave(saveRetryTarget) }
                            .disabled(isSaving)
                            .accessibilityIdentifier("retrySave")
                    }
                    if shouldOpenPhotoSettings {
                        Button("사진 접근 설정 열기", systemImage: "gear") { openPhotoSettings() }
                            .accessibilityIdentifier("openPhotoSettings")
                    }
                }
                Text("누르는 동안 원본 보기")
                    .font(.subheadline)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(.quaternary, in: Capsule())
                    .gesture(DragGesture(minimumDistance: 0).updating($comparingOriginal) { _, state, _ in state = true })
                    .accessibilityIdentifier("compareOriginal")
                filterControls
                outputControls
            }
            .padding(20)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("사진 편집")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("사진 변경") {
                    ForEach(SampleImage.catalog) { sample in
                        Button(sample.title) {
                            selectedSample = sample
                            pickerItem = nil
                            saveMessage = nil
                            saveRetryTarget = nil
                            shouldOpenPhotoSettings = false
                            requestID = UUID()
                        }
                    }
                }
                .disabled(isSaving || isShowingFileExporter)
                .accessibilityIdentifier("changeSample")
            }
        }
        .task(id: model.previewRevision) {
            await model.refreshPreview()
        }
        .task(id: requestID) {
            await model.load(selectedSample, using: services.input)
        }
        .task(id: pickerItem) {
            guard let pickerItem else { return }
            do {
                guard let data = try await pickerItem.loadTransferable(type: Data.self) else {
                    throw ImageServiceError.inputUnavailable
                }
                try Task.checkCancellation()
                model.load(data, title: "선택한 사진")
                saveMessage = nil
                saveRetryTarget = nil
                shouldOpenPhotoSettings = false
            } catch {
                guard !Task.isCancelled else { return }
                model.failLoading(error)
            }
        }
        .photosPicker(isPresented: $isShowingPhotoPicker, selection: $pickerItem, matching: .images, photoLibrary: .shared())
        .sheet(isPresented: $isShowingCamera) {
            CameraCaptureSheet { image in
                defer { isShowingCamera = false }
                guard let data = image.jpegData(compressionQuality: 0.95) else {
                    saveMessage = "촬영한 사진을 불러오지 못했습니다. 다시 촬영해 주세요."
                    return
                }
                model.load(data, title: "카메라 사진")
                selectedSample = model.sample
                saveMessage = nil
                saveRetryTarget = nil
                shouldOpenPhotoSettings = false
            }
        }
        .fileImporter(isPresented: $isShowingFileImporter,
                      allowedContentTypes: [.jpeg, .png, .heic],
                      allowsMultipleSelection: false) { result in
            do {
                guard let url = try result.get().first else { return }
                let hasAccess = url.startAccessingSecurityScopedResource()
                defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                model.load(data, title: url.deletingPathExtension().lastPathComponent)
                selectedSample = model.sample
                saveMessage = nil
                saveRetryTarget = nil
                shouldOpenPhotoSettings = false
            } catch {
                if !error.isUserCancelled {
                    saveMessage = "파일을 열지 못했습니다: \(error.localizedDescription)"
                    saveRetryTarget = nil
                    shouldOpenPhotoSettings = false
                }
            }
        }
        .fileExporter(isPresented: $isShowingFileExporter,
                      document: exportDocument,
                      contentType: .jpeg,
                      defaultFilename: "PictureFilter-\(Date.now.formatted(.iso8601.year().month().day()))") { result in
            switch result {
            case .success(let url):
                saveMessage = "파일을 저장했습니다: \(url.lastPathComponent)"
                saveRetryTarget = nil
                shouldOpenPhotoSettings = false
            case .failure(let error):
                if error.isUserCancelled {
                    saveMessage = nil
                    saveRetryTarget = nil
                } else {
                    saveMessage = "파일 저장에 실패했습니다. 다시 시도해 주세요."
                    saveRetryTarget = .file
                }
            }
            isSaving = false
        }
    }

    private var photoPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20).fill(Color.secondary.opacity(0.08))
            if let image = comparingOriginal ? model.originalImage : (model.previewImage ?? model.originalImage) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(12)
                    .accessibilityLabel(model.sample.title + " 미리보기")
                    .accessibilityIdentifier("imagePreview")
            }
            if model.phase == .loading { ProgressView("사진 불러오는 중") }
            if model.isRendering { ProgressView("필터 적용 중") }
        }
        .frame(height: 320)
    }

    private var filterControls: some View {
        Group {
            Text(comparingOriginal ? "원본 비교 중" : "선택: " + model.settings.filter.title)
                .font(.caption).foregroundStyle(.secondary)
                .accessibilityIdentifier("filterStatus")
            Text("필터").font(.headline)
            ScrollView(.horizontal) {
                HStack {
                    ForEach(PhotoFilter.allCases) { filter in
                        Button { model.selectFilter(filter) } label: {
                            Text(filter.title)
                                .padding(.horizontal, 16).padding(.vertical, 12)
                                .background(filter == model.settings.filter ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(.plain)
                .disabled(!model.canEdit || isSaving || isShowingFileExporter)
                        .accessibilityIdentifier("filter-" + filter.rawValue)
                        .accessibilityAddTraits(filter == model.settings.filter ? .isSelected : [])
                    }
                }
            }
            .accessibilityIdentifier("filterList")
            VStack(alignment: .leading) {
                Text("강도")
                Slider(value: Binding(get: { model.settings.intensity }, set: { model.setIntensity($0) }), in: 0...1)
                    .disabled(!model.canEdit || model.settings.filter == .original || isSaving || isShowingFileExporter)
                    .accessibilityLabel("필터 강도")
                    .accessibilityIdentifier("intensitySlider")
            }
            VStack(alignment: .leading) {
                Text("피부 보정")
                Slider(value: Binding(get: { model.settings.skinSmoothing }, set: { model.setSkinSmoothing($0) }), in: 0...1)
                    .disabled(!model.canEdit || isSaving || isShowingFileExporter)
                    .accessibilityLabel("피부 보정 강도")
                    .accessibilityIdentifier("skinSmoothingSlider")
                Text(model.settings.skinSmoothing == 0 ? "얼굴을 자동 인식해 선택적으로 보정합니다." : "얼굴 피부 영역을 부드럽게 보정합니다.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var outputControls: some View {
        Group {
            HStack {
                Button("초기화") { model.reset() }.disabled(!model.canEdit || isSaving || isShowingFileExporter)
                Spacer()
                Menu("내보내기") {
                    Button("파일로 저장", systemImage: "folder") { Task { await exportFile() } }
                    Button("사진 앱에 저장", systemImage: "photo") { Task { await saveToPhotoLibrary() } }
                }
                .disabled(!model.canEdit || isSaving || isShowingFileExporter)
                .buttonStyle(.borderedProminent)
            }
            Button("파일에서 사진 열기") { isShowingFileImporter = true }
                .disabled(isSaving || isShowingFileExporter)
                .accessibilityIdentifier("openImageFile")
            Text("사진을 고른 뒤 필터를 적용하고 파일이나 사진 앱에 저장할 수 있습니다.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    @MainActor
    private func exportFile() async {
        guard !isSaving, !isShowingFileExporter else { return }
        isSaving = true
        saveMessage = "파일 내보내기 준비 중입니다."
        saveRetryTarget = nil
        shouldOpenPhotoSettings = false
        do {
            let data = try await model.renderOutput()
            exportDocument = JPEGImageDocument(data: data)
            isShowingFileExporter = true
        } catch {
            saveMessage = "파일 저장에 실패했습니다. 다시 시도해 주세요."
            saveRetryTarget = .file
            isSaving = false
        }
    }

    @MainActor
    private func saveToPhotoLibrary() async {
        guard !isSaving, !isShowingFileExporter else { return }
        isSaving = true
        saveMessage = "사진 앱에 저장 중입니다."
        saveRetryTarget = nil
        shouldOpenPhotoSettings = false
        defer { isSaving = false }
        do {
            let data = try await model.renderOutput()
            try await services.output.saveToPhotoLibrary(data)
            saveMessage = "편집한 사진을 사진 앱에 저장했습니다."
            saveRetryTarget = nil
        } catch {
            saveMessage = error.imageSaveFailureMessage
            saveRetryTarget = .photoLibrary
            shouldOpenPhotoSettings = (error as? ImageServiceError) == .permissionDenied
        }
    }

    @MainActor
    private func retrySave(_ target: SaveRetryTarget) {
        switch target {
        case .file: Task { await exportFile() }
        case .photoLibrary: Task { await saveToPhotoLibrary() }
        }
    }

    private func openPhotoSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private enum SaveRetryTarget {
    case file
    case photoLibrary
}

private extension Error {
    var isUserCancelled: Bool {
        if self is CancellationError { return true }
        return (self as? CocoaError)?.code == .userCancelled
    }

    var imageSaveFailureMessage: String {
        if (self as? ImageServiceError) == .permissionDenied {
            return "사진 저장 권한이 없습니다. 설정에서 사진 접근을 허용한 뒤 다시 저장해 주세요."
        }
        return "사진 저장에 실패했습니다. 잠시 후 다시 시도해 주세요."
    }
}

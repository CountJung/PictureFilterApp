import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

struct EditorView: View {
    enum Entry { case sample, camera, library }
    private let entry: Entry
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
    @State private var shouldLoadSample: Bool
    @State private var didStartEntry = false

    init(initialSample: SampleImage) {
        entry = .sample
        _shouldLoadSample = State(initialValue: true)
        _model = State(initialValue: Self.makeModel(sample: initialSample))
        _selectedSample = State(initialValue: initialSample)
    }

    init(entry: Entry) {
        self.entry = entry
        let empty = SampleImage(id: "empty", title: "사진을 촬영하거나 선택하세요")
        _model = State(initialValue: Self.makeModel(sample: empty))
        _selectedSample = State(initialValue: empty)
        _shouldLoadSample = State(initialValue: false)
    }

    private static func makeModel(sample: SampleImage) -> EditorModel {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-no-faces") {
            return EditorModel(sample: sample, renderer: FilterRenderer(landmarkDetector: { _ in [] }))
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-test-face-failure") {
            return EditorModel(sample: sample, renderer: FilterRenderer(landmarkDetector: { _ in
                throw ImageServiceError.inputUnavailable
            }))
        }
        #endif
        return EditorModel(sample: sample)
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
                    pickerItem = nil
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
                    Button("다시 시도") {
                        if SampleImage.catalog.contains(where: { $0.id == selectedSample.id }) {
                            shouldLoadSample = true
                            requestID = UUID()
                        } else { isShowingPhotoPicker = true }
                    }
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
                portraitControls
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
                            shouldLoadSample = true
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
            if shouldLoadSample {
                shouldLoadSample = false
                await model.load(selectedSample, using: services.input)
            }
        }
        .task {
            guard !didStartEntry else { return }
            didStartEntry = true
            if entry == .camera { isShowingCamera = true }
            if entry == .library { isShowingPhotoPicker = true }
        }
        .task(id: pickerItem) {
            guard let pickerItem else { return }
            do {
                guard let data = try await pickerItem.loadTransferable(type: Data.self) else {
                    throw ImageServiceError.inputUnavailable
                }
                try Task.checkCancellation()
                model.replacePhoto(data, title: "선택한 사진")
                saveMessage = nil
                saveRetryTarget = nil
                shouldOpenPhotoSettings = false
            } catch {
                guard !Task.isCancelled else { return }
                model.reportReplacementFailure(error)
            }
        }
        .photosPicker(isPresented: $isShowingPhotoPicker, selection: $pickerItem, matching: .images, photoLibrary: .shared())
        .sheet(isPresented: $isShowingCamera) {
            CameraCaptureSheet { data in
                defer { isShowingCamera = false }
                pickerItem = nil
                model.loadCapture(data)
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
                model.replacePhoto(data, title: url.deletingPathExtension().lastPathComponent)
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
            Text("인물 추천").font(.headline)
            filterChoices([.brightPortrait])
            if model.settings.filter == .brightPortrait {
                VStack(alignment: .leading, spacing: 8) {
                    Text("밝은 부분의 디테일을 지키며 중간 밝기와 그림자를 부드럽게 올립니다.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("밝기")
                    Slider(value: Binding(get: { model.settings.portraitBrightness }, set: { model.setPortraitBrightness($0) }), in: 0...1)
                        .accessibilityLabel("화사한 인물 밝기")
                        .accessibilityIdentifier("portraitBrightnessSlider")
                    Text("따뜻함")
                    Slider(value: Binding(get: { model.settings.portraitWarmth }, set: { model.setPortraitWarmth($0) }), in: -1...1)
                        .accessibilityLabel("화사한 인물 따뜻함")
                        .accessibilityIdentifier("portraitWarmthSlider")
                    Text("얼굴을 찾으면 얼굴 중심으로 더 밝게 보정합니다. 찾지 못해도 사진 전체의 밝기와 색감을 조절합니다. 피부 질감은 아래에서 별도로 조절할 수 있습니다.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("brightPortraitGuidance")
                }
                .disabled(!model.canEdit || isSaving || isShowingFileExporter)
            }
            Text("기본 필터").font(.headline)
            filterChoices(PhotoFilter.basic)
            Text("사진 스타일").font(.headline)
            filterChoices(PhotoFilter.styles)
            VStack(alignment: .leading) {
                Text("강도")
                Slider(value: Binding(get: { model.settings.intensity }, set: { model.setIntensity($0) }), in: 0...1)
                    .disabled(!model.canEdit || model.settings.filter == .original || isSaving || isShowingFileExporter)
                    .accessibilityLabel("필터 강도")
                    .accessibilityIdentifier("intensitySlider")
            }
            VStack(alignment: .leading) {
                Text("인물 보정")
                if model.faceAnalysis == .analyzing {
                    ProgressView("인물 분석 중")
                        .accessibilityIdentifier("faceAnalysisProgress")
                } else if model.faceAnalysis == .failed {
                    Text("인물 분석에 실패해 얼굴 보정이 적용되지 않습니다.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("인물 분석 다시 시도") { model.retryFaceAnalysis() }
                        .accessibilityIdentifier("retryFaceAnalysis")
                }
                if model.detectedFaceCount > 1 {
                    Picker("보정 대상", selection: Binding<Int?>(
                        get: { model.settings.selectedSkinFaceIndex },
                        set: { model.selectSkinFace($0) }
                    )) {
                        Text("모든 인물").tag(Int?.none)
                        ForEach(0..<model.detectedFaceCount, id: \.self) { index in
                            Text("인물 \(index + 1)").tag(Int?.some(index))
                        }
                    }
                    .accessibilityIdentifier("skinFacePicker")
                    Text("사진에서 왼쪽에 있는 얼굴부터 번호를 붙입니다.")
                        .font(.footnote).foregroundStyle(.secondary)
                } else if model.detectedFaceCount == 1 {
                    Text("인물 1").font(.subheadline).foregroundStyle(.secondary)
                } else if model.faceAnalysis == .ready(0) {
                    Text("인물을 찾지 못하면 원본을 유지합니다.").font(.footnote).foregroundStyle(.secondary)
                }
                Text(model.settings.selectedSkinFaceIndex == nil
                     ? "전체 강도를 바꾸면 모든 인물의 피부 보정에 같은 값이 적용됩니다."
                     : "선택한 인물의 피부 보정만 바꿉니다. 다른 인물의 보정은 유지됩니다.")
                    .font(.footnote).foregroundStyle(.secondary)
                Slider(value: Binding(get: { model.settings.activeSkinSmoothing }, set: { model.setSkinSmoothing($0) }), in: 0...1)
                    .disabled(!model.canEdit || isSaving || isShowingFileExporter)
                    .accessibilityLabel("피부 보정 강도")
                    .accessibilityIdentifier("skinSmoothingSlider")
                Text(model.settings.activeSkinSmoothing == 0 ? "얼굴 특징과 피부 질감을 보존하며 약하게 보정합니다." : "눈·눈썹·입을 보호해 인식된 피부 영역만 보정합니다.")
                    .font(.footnote).foregroundStyle(.secondary)
                if model.settings.selectedSkinFaceIndex != nil {
                    Button("이 인물 피부 보정 끄기") { model.resetSelectedSkinSmoothing() }
                        .disabled(!model.canEdit || isSaving || isShowingFileExporter)
                        .accessibilityIdentifier("resetSelectedSkinSmoothing")
                }
            }
        }
    }

    private var portraitControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("인물 조명과 배경 깊이")
                .font(.headline)
            Text(model.settings.selectedSkinFaceIndex == nil
                 ? "전체 강도를 바꾸면 모든 인물의 조명에 같은 값이 적용됩니다."
                 : "선택한 인물의 조명만 바꿉니다. 다른 인물의 보정은 유지됩니다.")
                .font(.footnote).foregroundStyle(.secondary)
            VStack(alignment: .leading) {
                Text("인물 조명")
                Slider(value: Binding(get: { model.settings.activePortraitLight }, set: { model.setPortraitLight($0) }), in: 0...1)
                    .disabled(!model.canEdit || model.detectedFaceCount == 0 || isSaving || isShowingFileExporter)
                    .accessibilityLabel("인물 조명 강도")
                    .accessibilityIdentifier("portraitLightSlider")
                Text(model.faceAnalysis == .ready(0) ? "얼굴을 찾지 못해 조명 보정을 사용할 수 없습니다." : "얼굴 윤곽 안쪽에 부드러운 빛을 더합니다.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if model.settings.selectedSkinFaceIndex != nil {
                Button("이 인물 조명 끄기") { model.resetSelectedPortraitEffects() }
                    .disabled(!model.canEdit || isSaving || isShowingFileExporter)
                    .accessibilityIdentifier("resetSelectedPortraitLight")
            }
            VStack(alignment: .leading) {
                Text("배경 흐림")
                Slider(value: Binding(get: { model.settings.backgroundBlur }, set: { model.setBackgroundBlur($0) }), in: 0...1)
                    .disabled(!model.canEdit || isSaving || isShowingFileExporter)
                    .accessibilityLabel("배경 흐림 강도")
                    .accessibilityIdentifier("backgroundBlurSlider")
                if model.settings.backgroundBlur > 0 {
                    if model.isRendering {
                        ProgressView("배경 효과 처리 중")
                    } else if model.backgroundAnalysis == .failed {
                        Text("인물 영역 분석에 실패해 배경 흐림이 적용되지 않습니다.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button("배경 분석 다시 시도") { model.retryFaceAnalysis() }
                            .accessibilityIdentifier("retryBackgroundAnalysis")
                    } else if model.backgroundAnalysis == .ready(0) {
                        Text("인물 영역을 찾지 못해 배경 흐림이 적용되지 않습니다.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Text("Vision이 인물을 분리하지 못하면 원본을 유지합니다. 사진은 기기에서 처리됩니다.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func filterChoices(_ filters: [PhotoFilter]) -> some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(filters) { filter in
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
        .accessibilityIdentifier(filters == [.brightPortrait] ? "portraitFilterList" : (filters == PhotoFilter.basic ? "basicFilterList" : "styleFilterList"))
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

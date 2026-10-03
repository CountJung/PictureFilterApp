import Observation
import UIKit

@MainActor
@Observable
final class EditorModel {
    enum Phase: Equatable {
        case idle, loading, ready
        case failed(String)
    }

    private(set) var sample: SampleImage
    private(set) var phase: Phase = .idle
    private(set) var originalData: Data?
    private(set) var originalImage: UIImage?
    private(set) var settings = EditSettings()
    private(set) var previewImage: UIImage?
    private(set) var isRendering = false
    private(set) var renderError: String?
    private(set) var detectedFaceCount = 0
    private(set) var faceAnalysis: FaceAnalysisState = .idle
    private(set) var backgroundAnalysis: FaceAnalysisState = .idle
    @ObservationIgnored private var analysisTask: Task<Void, Never>?
    private(set) var previewRevision = UUID()
    @ObservationIgnored private let renderer: any PreviewRendering
    @ObservationIgnored private let faceCounter: (any FaceCounting)?
    @ObservationIgnored private let waitForQuiet: @Sendable () async throws -> Void
    @ObservationIgnored private var activeRender = UUID()
    @ObservationIgnored private var activeRequest = UUID()

    init(sample: SampleImage, renderer: any PreviewRendering = FilterRenderer(),
         waitForQuiet: @escaping @Sendable () async throws -> Void = {
             try await Task.sleep(for: .milliseconds(120))
         }) {
        self.sample = sample
        self.renderer = renderer
        self.faceCounter = renderer as? any FaceCounting
        self.waitForQuiet = waitForQuiet
    }

    deinit { analysisTask?.cancel() }

    var canEdit: Bool { phase == .ready }
    var errorMessage: String? {
        if case .failed(let message) = phase { return message }
        return nil
    }

    func selectFilter(_ filter: PhotoFilter) {
        guard canEdit, settings.filter != filter else { return }
        settings.select(filter)
        invalidatePreview()
    }

    func setIntensity(_ value: Double) {
        guard canEdit else { return }
        let previous = settings
        settings.setIntensity(value)
        guard previous != settings else { return }
        invalidatePreview()
    }

    func setPortraitBrightness(_ value: Double) {
        guard canEdit else { return }
        let previous = settings
        settings.setPortraitBrightness(value)
        guard previous != settings else { return }
        invalidatePreview()
    }

    func setPortraitWarmth(_ value: Double) {
        guard canEdit else { return }
        let previous = settings
        settings.setPortraitWarmth(value)
        guard previous != settings else { return }
        invalidatePreview()
    }

    func setSkinSmoothing(_ value: Double) {
        guard canEdit else { return }
        let previous = settings
        settings.setSkinSmoothing(value)
        guard previous != settings else { return }
        invalidatePreview()
    }

    func setPortraitLight(_ value: Double) {
        guard canEdit else { return }
        let previous = settings
        settings.setPortraitLight(value)
        guard previous != settings else { return }
        invalidatePreview()
    }

    func setBackgroundBlur(_ value: Double) {
        guard canEdit else { return }
        let previous = settings
        settings.setBackgroundBlur(value)
        guard previous != settings else { return }
        invalidatePreview()
    }

    func selectSkinFace(_ index: Int?) {
        guard canEdit else { return }
        // Selecting an editing target does not change the rendered photograph.
        settings.selectSkinFace(index)
    }

    func resetSelectedSkinSmoothing() {
        guard canEdit else { return }
        let previous = settings
        settings.resetSelectedSkinSmoothing()
        guard previous != settings else { return }
        invalidatePreview()
    }

    func resetSelectedPortraitEffects() {
        guard canEdit else { return }
        let previous = settings
        settings.resetSelectedPortraitEffects()
        guard previous != settings else { return }
        invalidatePreview()
    }

    func reset() {
        guard canEdit else { return }
        settings = EditSettings()
        invalidatePreview()
    }

    func retryPreview() {
        guard canEdit else { return }
        invalidatePreview()
    }

    func renderOutput(using renderer: any OutputRendering = FilterRenderer()) async throws -> Data {
        guard canEdit, let originalData else { throw ImageServiceError.inputUnavailable }
        let source = originalData
        let settings = settings
        let output = try await renderer.renderOutput(source, settings: settings, maxDimension: 4096)
        try Task.checkCancellation()
        guard UIImage(data: output) != nil else { throw ImageServiceError.invalidImage }
        return output
    }

    /// Installs image data received from a system picker. This path is kept
    /// separate from the sample input service so the simulator and the real
    /// photo library can share the same editor state machine.
    func load(_ data: Data, title: String) {
        let request = beginLoading(SampleImage(id: "photo-\(UUID().uuidString)", title: title))
        do {
            try finishLoading(data, request: request)
        } catch {
            failLoading(error, request: request)
        }
    }

    /// Retakes preserve the selected look, but never another photo's face edits.
    func loadCapture(_ data: Data) {
        guard UIImage(data: data) != nil else {
            renderError = ImageServiceError.invalidImage.localizedDescription
            return
        }
        let previous = settings
        let hadPhoto = originalData != nil
        load(data, title: "카메라 사진")
        settings.select(hadPhoto ? previous.filter : .brightPortrait)
        if hadPhoto {
            settings.setIntensity(previous.intensity)
            settings.setPortraitBrightness(previous.portraitBrightness)
            settings.setPortraitWarmth(previous.portraitWarmth)
        }
        invalidatePreview()
    }

    func replacePhoto(_ data: Data, title: String) {
        guard UIImage(data: data) != nil else {
            reportReplacementFailure(ImageServiceError.invalidImage)
            return
        }
        load(data, title: title)
    }

    func reportReplacementFailure(_ error: Error) {
        if canEdit { renderError = error.localizedDescription }
        else { failLoading(error) }
    }

    /// Reports a picker or data-provider failure using the normal editor error
    /// state. A cancelled picker does not call this method.
    func failLoading(_ error: Error, title: String = "선택한 사진") {
        let request = beginLoading(SampleImage(id: "photo-\(UUID().uuidString)", title: title))
        failLoading(error, request: request)
    }

    private func invalidatePreview() {
        previewRevision = UUID()
        activeRender = UUID()
        renderError = nil
        isRendering = false
    }

    func refreshPreview() async {
        guard canEdit, let originalData else { return }
        let revision = previewRevision
        let renderID = UUID()
        activeRender = renderID
        let snapshot = settings
        isRendering = true
        do {
            try await waitForQuiet()
            try Task.checkCancellation()
            guard revision == previewRevision, renderID == activeRender else { return }
            let output = try await renderer.render(originalData, settings: snapshot, maxDimension: 1600)
            let backgroundState = await faceCounter?.backgroundAnalysis(in: originalData) ?? .idle
            try Task.checkCancellation()
            guard revision == previewRevision, renderID == activeRender else { return }
            guard let image = UIImage(data: output) else { throw ImageServiceError.invalidImage }
            previewImage = image
            backgroundAnalysis = backgroundState
            isRendering = false
        } catch {
            guard revision == previewRevision, renderID == activeRender else { return }
            isRendering = false
            if !(error is CancellationError) && !Task.isCancelled {
                renderError = "미리보기를 만들지 못했습니다. 다시 시도해 주세요."
            }
        }
    }

    /// Changes input independently from any edit settings or rendered output.
    func load(_ sample: SampleImage, using input: any ImageInputService) async {
        let request = beginLoading(sample)
        do {
            let data = try await input.load(sample)
            try Task.checkCancellation()
            guard activeRequest == request else { return }
            try finishLoading(data, request: request)
        } catch {
            guard activeRequest == request else { return }
            if error is CancellationError || Task.isCancelled { phase = .idle }
            else { failLoading(error, request: request) }
        }
    }

    private func beginLoading(_ sample: SampleImage) -> UUID {
        analysisTask?.cancel()
        faceAnalysis = .idle
        backgroundAnalysis = .idle
        let request = UUID()
        activeRequest = request
        self.sample = sample
        phase = .loading
        invalidatePreview()
        previewImage = nil
        originalData = nil
        originalImage = nil
        detectedFaceCount = 0
        settings = EditSettings()
        return request
    }

    private func finishLoading(_ data: Data, request: UUID) throws {
        guard activeRequest == request else { return }
        guard let image = UIImage(data: data) else { throw ImageServiceError.invalidImage }
        originalData = data
        originalImage = image
        phase = .ready
        invalidatePreview()
        startFaceAnalysis(data, request: request, retry: false)
    }

    func retryFaceAnalysis() {
        guard canEdit, let data = originalData else { return }
        startFaceAnalysis(data, request: activeRequest, retry: true)
    }

    private func startFaceAnalysis(_ data: Data, request: UUID, retry: Bool) {
        analysisTask?.cancel()
        guard let faceCounter else { faceAnalysis = .idle; return }
        faceAnalysis = .analyzing
        detectedFaceCount = 0
        analysisTask = Task { [weak self] in
            let state = await faceCounter.faceAnalysis(in: data, retry: retry)
            guard !Task.isCancelled, let self, self.activeRequest == request else { return }
            self.faceAnalysis = state
            if case .ready(let count) = state { self.detectedFaceCount = count }
            else { self.detectedFaceCount = 0 }
            if retry { self.invalidatePreview() }
        }
    }

    private func failLoading(_ error: Error, request: UUID) {
        guard activeRequest == request else { return }
        phase = .failed(error.localizedDescription)
    }
}

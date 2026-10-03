import SwiftUI

struct WelcomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "camera.filters")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text("사진 한 장, 새로운 느낌")
                        .font(.largeTitle.bold())
                        .accessibilityIdentifier("welcomeTitle")
                    Text("사진을 고르고, 원하는 색감을 찾고, 새로운 이미지로 간직하세요.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    NavigationLink {
                        EditorView(entry: .camera)
                    } label: {
                        Label("사진 촬영", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("start-camera")
                    NavigationLink {
                        EditorView(entry: .library)
                    } label: {
                        Label("사진 선택", systemImage: "photo.badge.plus")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("start-library")
                    Text("샘플로 둘러보기").font(.headline)
                    ForEach(SampleImage.catalog) { sample in
                        NavigationLink {
                            EditorView(initialSample: sample)
                        } label: {
                            Label(sample.title + "로 시작", systemImage: "photo")
                                .frame(maxWidth: .infinity, minHeight: 36)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("start-" + sample.id)
                    }
                    Text("샘플 이미지로 먼저 둘러보세요.")
                        .foregroundStyle(.secondary)

                }
                .padding(24)
                .frame(maxWidth: 600, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("PictureFilterApp")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

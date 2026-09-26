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
                    ForEach(SampleImage.catalog) { sample in
                        NavigationLink {
                            EditorView(initialSample: sample)
                        } label: {
                            Label(sample.title + "로 시작", systemImage: "photo")
                                .frame(maxWidth: .infinity, minHeight: 36)
                        }
                        .buttonStyle(.borderedProminent)
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

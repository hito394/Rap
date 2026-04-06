import SwiftUI

/// Full-screen sheet for GPT-4o deep dive on a selected lyric.
struct DeepDiveView: View {
    let entry: LyricEntry
    let deepDiveText: String
    let isLoading: Bool
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Selected lyric
                    VStack(alignment: .leading, spacing: 10) {
                        Label("解析対象ライン", systemImage: "text.quote")
                            .font(.monoSmall)
                            .foregroundColor(.gold)
                        HStack(alignment: .top, spacing: 10) {
                            GoldBar()
                            Text(entry.lyric)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .cardStyle()

                    // AI analysis
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Label("ディープダイブ解析", systemImage: "sparkles")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.gold)
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .tint(.gold)
                                    .scaleEffect(0.8)
                            }
                        }

                        if deepDiveText.isEmpty && isLoading {
                            LoadingPlaceholder()
                        } else {
                            Text(deepDiveText)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .lineSpacing(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .cardStyle()

                    Spacer(minLength: 40)
                }
                .padding(16)
            }
            .background(Color.appBg)
            .navigationTitle("Deep Dive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる", action: onClose)
                        .foregroundColor(.gold)
                }
            }
        }
    }
}

// MARK: - Loading placeholder
private struct LoadingPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.cardBorder)
                    .frame(height: 12)
                    .frame(maxWidth: i == 4 ? 200 : .infinity)
                    .shimmer()
            }
        }
    }
}

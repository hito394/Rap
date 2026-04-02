import SwiftUI

@Observable
class VideoSearchViewModel {
    var searchText = ""
    var videos: [YouTubeVideo] = []
    var isLoading = false
    var toastMessage: String?
    var hasSearched = false
    var apiKeyMissing = false

    func search(query: String? = nil) async {
        let q = (query ?? searchText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        if YouTubeService.apiKey.isEmpty {
            apiKeyMissing = true
            return
        }

        isLoading = true
        videos = []
        hasSearched = true

        do {
            videos = try await YouTubeService.search(query: q)
        } catch {
            toastMessage = (error as? YouTubeError)?.errorDescription ?? "接続を確認してください"
        }

        isLoading = false
    }
}

struct VideoSearchView: View {
    @State private var vm = VideoSearchViewModel()
    @State private var selectedVideo: YouTubeVideo?
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Search bar
                    searchBar

                    // Category chips
                    if !vm.hasSearched {
                        categorySection
                        popularSection
                    }

                    // API key warning
                    if vm.apiKeyMissing {
                        apiKeyWarning
                            .padding(.horizontal, 20)
                    }

                    // Loading
                    if vm.isLoading {
                        VStack(spacing: 16) {
                            AnalyzingIndicator()
                            ForEach(0..<4, id: \.self) { _ in
                                VideoRowSkeleton()
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Results
                    if !vm.videos.isEmpty {
                        LazyVStack(spacing: 0) {
                            ForEach(vm.videos) { video in
                                VideoRow(video: video) {
                                    selectedVideo = video
                                }
                                Divider().background(Color.divider)
                                    .padding(.leading, 80)
                            }
                        }
                        .padding(.horizontal, 20)
                        .cardStyle()
                    }

                    // Empty state
                    if vm.hasSearched && vm.videos.isEmpty && !vm.isLoading {
                        EmptyTabMessage(text: "動画が見つかりませんでした\n別のキーワードで検索してみてください",
                                        icon: "video.slash")
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.top, 8)
            }
            .background(Color.appBackground)
            .navigationTitle("VIDEO")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(item: $selectedVideo) { video in
                VideoDetailView(video: video)
            }
        }
        .toast(message: $vm.toastMessage)
    }

    // MARK: Search bar
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 15))
            TextField("MCバトル、アーティスト名など...", text: $vm.searchText)
                .foregroundColor(.white)
                .tint(Color.gold)
                .focused($searchFocused)
                .onSubmit { Task { await vm.search() } }
            if !vm.searchText.isEmpty {
                Button { vm.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .cardStyle()
        .padding(.horizontal, 20)
    }

    // MARK: Category chips
    private var categorySection: some View {
        SectionGroup(title: "カテゴリ", icon: "rectangle.grid.2x2") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(VideoCategory.list) { cat in
                        CategoryChip(category: cat) {
                            vm.searchText = cat.query
                            Task { await vm.search(query: cat.query) }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: Popular battles section (static)
    private var popularSection: some View {
        SectionGroup(title: "伝説の一戦", icon: "crown.fill") {
            VStack(spacing: 0) {
                ForEach(LegendaryBattle.list) { battle in
                    LegendaryBattleRow(battle: battle) {
                        vm.searchText = battle.searchQuery
                        Task { await vm.search(query: battle.searchQuery) }
                    }
                    if battle.id != LegendaryBattle.list.last?.id {
                        Divider().background(Color.divider).padding(.leading, 56)
                    }
                }
            }
            .padding(.horizontal, 20)
            .cardStyle()
        }
    }

    // MARK: API key warning
    private var apiKeyWarning: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .foregroundColor(.orange)
                Text("YouTube APIキー未設定")
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundColor(.orange)
            }
            Text("Google Cloud ConsoleでYouTube Data API v3を有効化し、\nAPIキーをXcodeのBuild Settings → YOUTUBE_API_KEYに設定してください。")
                .font(.system(.caption))
                .foregroundColor(.white.opacity(0.7))
                .lineSpacing(4)
        }
        .padding(14)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Category chip
struct CategoryChip: View {
    let category: VideoCategory
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(category.emoji)
                    .font(.system(size: 14))
                Text(category.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Video row
struct VideoRow: View {
    let video: YouTubeVideo
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Thumbnail
                AsyncImage(url: URL(string: video.thumbnailHighURL)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color(hex: "#1a1a1a")
                }
                .frame(width: 100, height: 56)
                .cornerRadius(6)
                .clipped()

                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        Text(video.channelTitle)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(Color.gold)
                        if !video.formattedDate.isEmpty {
                            Text("· \(video.formattedDate)")
                                .font(.system(.caption))
                                .foregroundColor(.gray)
                        }
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(.gray.opacity(0.4))
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Legendary battles
struct LegendaryBattle: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let year: String
    let searchQuery: String
    let emoji: String
}

extension LegendaryBattle {
    static let list: [LegendaryBattle] = [
        LegendaryBattle(name: "Loaded Lux vs Calicoe", description: "URLの伝説的バトル。ライム密度の極致",
                        year: "2012", searchQuery: "Loaded Lux vs Calicoe URL", emoji: "🗽"),
        LegendaryBattle(name: "Drake vs Kendrick", description: "2024年最大のビーフ。世紀の応酬",
                        year: "2024", searchQuery: "Drake vs Kendrick Lamar beef Not Like Us", emoji: "🔥"),
        LegendaryBattle(name: "UMB決勝 漢 vs T-PABLOW", description: "日本語MCバトルの頂点",
                        year: "2015", searchQuery: "UMB 漢 T-PABLOW 決勝", emoji: "🇯🇵"),
        LegendaryBattle(name: "HOLLOW DA DON vs LOADED LUX", description: "URL最大の興行、NY頂上決戦",
                        year: "2014", searchQuery: "Hollow Da Don vs Loaded Lux Summer Madness 4", emoji: "👑"),
        LegendaryBattle(name: "KOK 晋平太 vs DOTAMA", description: "KOK伝説の決勝戦",
                        year: "2014", searchQuery: "KOK 晋平太 DOTAMA 決勝", emoji: "⚔️"),
        LegendaryBattle(name: "BET Hip Hop Cypher 2013", description: "Kendrick Lamar伝説のヴァース",
                        year: "2013", searchQuery: "BET hip hop awards cypher 2013 Kendrick Lamar", emoji: "🎤"),
    ]
}

struct LegendaryBattleRow: View {
    let battle: LegendaryBattle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.gold.opacity(0.1)).frame(width: 40, height: 40)
                    Text(battle.emoji).font(.system(size: 18))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(battle.name)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundColor(.white)
                    Text(battle.description)
                        .font(.system(.caption))
                        .foregroundColor(.gray)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(battle.year)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color.gold)
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.4))
                }
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Skeleton row
struct VideoRowSkeleton: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: "#1a1a1a"))
                .frame(width: 100, height: 56)
            VStack(alignment: .leading, spacing: 6) {
                SkeletonBlock(height: 14)
                SkeletonBlock(height: 14).frame(maxWidth: 160)
                SkeletonBlock(height: 10).frame(maxWidth: 100)
            }
        }
    }
}

import SwiftUI
import SwiftData

struct BeginnerGuideItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let emoji: String
    let question: String  // Pre-seeded question for FreeSearch
}

extension BeginnerGuideItem {
    static let list: [BeginnerGuideItem] = [
        BeginnerGuideItem(
            title: "ヒップホップって何？",
            subtitle: "4つの要素から始まった文化",
            emoji: "🎤",
            question: "ヒップホップとは何ですか？歴史や文化的背景を、全く知らない初心者にもわかりやすく教えてください。"
        ),
        BeginnerGuideItem(
            title: "MCバトルとは？",
            subtitle: "言葉でぶつかり合う戦い",
            emoji: "⚔️",
            question: "MCバトルとは何ですか？どんなルールで、どうやって勝ち負けが決まるのか、初心者向けに説明してください。"
        ),
        BeginnerGuideItem(
            title: "フリースタイルって？",
            subtitle: "即興でラップする技術",
            emoji: "🔥",
            question: "フリースタイルラップとは何ですか？なぜ難しいのか、どう練習するのか教えてください。"
        ),
        BeginnerGuideItem(
            title: "ライムって何がすごいの？",
            subtitle: "ただの韻踏みじゃない",
            emoji: "📖",
            question: "ラップのライム（韻）とは何ですか？どんな種類があって、なぜ難しいのか、具体例を交えて教えてください。"
        ),
        BeginnerGuideItem(
            title: "サンプリングって？",
            subtitle: "既存の音楽を使う技術",
            emoji: "🎵",
            question: "ヒップホップのサンプリングとは何ですか？どうやって使うのか、有名な例を挙げて初心者に教えてください。"
        ),
        BeginnerGuideItem(
            title: "日本語ラップの歴史",
            subtitle: "日本のシーンを知る",
            emoji: "🇯🇵",
            question: "日本語ラップの歴史を教えてください。どうやって始まって、どんなアーティストが有名なのか、初心者向けに解説してください。"
        ),
    ]
}

struct DiscoverView: View {
    @Query(sort: \HistoryItem.createdAt, order: .reverse) private var history: [HistoryItem]
    @Binding var selectedTrack: PickupTrack?
    @Binding var navigateToTrack: Bool
    @Binding var beginnerQuestion: String?
    @Binding var navigateToSearch: Bool

    private var recentHistory: [HistoryItem] { Array(history.prefix(5)) }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {

                    // Beginner Guide
                    SectionGroup(title: "ヒップホップ入門", icon: "graduationcap.fill") {
                        VStack(spacing: 0) {
                            ForEach(BeginnerGuideItem.list) { item in
                                BeginnerGuideRow(item: item) {
                                    beginnerQuestion = item.question
                                    navigateToSearch = true
                                }
                                if item.id != BeginnerGuideItem.list.last?.id {
                                    Divider().background(Color.divider).padding(.leading, 56)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .cardStyle()
                    }

                    // Pickup Tracks
                    SectionGroup(title: "Pickup Tracks", icon: "flame.fill") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(PickupTrack.list) { track in
                                    StreamingTrackCard(track: track) {
                                        selectedTrack = track
                                        navigateToTrack = true
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    // Era tiles
                    SectionGroup(title: "Era", icon: "calendar") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(EraTile.list) { era in
                                    EraTileView(era: era) {
                                        beginnerQuestion = "\(era.label)（\(era.years)）の時代のヒップホップについて、代表的なアーティスト・楽曲・特徴を初心者にわかりやすく教えてください。"
                                        navigateToSearch = true
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    // Recent
                    if !recentHistory.isEmpty {
                        SectionGroup(title: "最近の解析", icon: "clock.fill") {
                            VStack(spacing: 0) {
                                ForEach(recentHistory) { item in
                                    HistoryRow(item: item)
                                    if item.id != recentHistory.last?.id {
                                        Divider().background(Color.divider).padding(.leading, 56)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .cardStyle()
                        }
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.top, 8)
            }
            .background(Color.appBackground)
            .navigationTitle("HipHop Decoder")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

// MARK: - Beginner Guide Row
struct BeginnerGuideRow: View {
    let item: BeginnerGuideItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.gold.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Text(item.emoji)
                        .font(.system(size: 18))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundColor(.white)
                    Text(item.subtitle)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(.gray.opacity(0.4))
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Era tile
struct EraTileView: View {
    let era: EraTile
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: era.color))
                    .frame(width: 120, height: 70)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06), lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text(era.label).font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                    Text(era.years).font(.system(size: 9, design: .monospaced)).foregroundColor(.white.opacity(0.5))
                }.padding(8)
                HStack {
                    Spacer()
                    Image(systemName: era.icon).font(.system(size: 18)).foregroundColor(.white.opacity(0.12)).padding(10)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - History row
struct HistoryRow: View {
    let item: HistoryItem

    var icon: String {
        switch item.type {
        case "lyrics": return "waveform.and.mic"
        case "track": return "music.note"
        default: return "magnifyingglass"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.gold.opacity(0.1)).frame(width: 36, height: 36)
                Image(systemName: icon).font(.system(size: 14)).foregroundColor(Color.gold)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.query)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundColor(.white).lineLimit(1)
                Text(item.typeLabel + " · " + item.createdAt.formatted(.relative(presentation: .named)))
                    .font(.system(.caption, design: .monospaced)).foregroundColor(.gray)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 11)).foregroundColor(.gray.opacity(0.4))
        }
        .padding(.vertical, 10)
    }
}

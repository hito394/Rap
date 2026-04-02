import SwiftUI
import SwiftData

struct DiscoverView: View {
    @Query(sort: \HistoryItem.createdAt, order: .reverse) private var history: [HistoryItem]
    @Binding var selectedTrack: PickupTrack?
    @Binding var navigateToTrack: Bool

    private var recentHistory: [HistoryItem] {
        Array(history.prefix(6))
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    // Header
                    headerSection

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
                                        // TODO: filter by era
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
                                        Divider()
                                            .background(Color.divider)
                                            .padding(.leading, 56)
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

    // MARK: Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("今日も深掘りしよう")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Section wrapper
struct SectionGroup<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(Color.gold)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.gray)
                    .tracking(1.2)
            }
            .padding(.horizontal, 20)
            content
        }
    }
}

// MARK: - Streaming track card (vertical album art style)
struct StreamingTrackCard: View {
    let track: PickupTrack
    let action: () -> Void

    private var gradientColors: [Color] {
        let hash = abs(track.title.hashValue)
        let palettes: [[Color]] = [
            [Color(hex: "#2a1a00"), Color(hex: "#1a0d00")],
            [Color(hex: "#001a2a"), Color(hex: "#000d1a")],
            [Color(hex: "#1a002a"), Color(hex: "#0d001a")],
            [Color(hex: "#002a1a"), Color(hex: "#001a0d")],
            [Color(hex: "#2a0000"), Color(hex: "#1a0000")],
        ]
        return palettes[hash % palettes.count]
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                // Album art
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: gradientColors,
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing))
                        .frame(width: 130, height: 130)
                    Text(track.emoji)
                        .font(.system(size: 44))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                .frame(width: 130, alignment: .leading)
            }
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(era.label)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Text(era.years)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(8)

                HStack {
                    Spacer()
                    Image(systemName: era.icon)
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.12))
                        .padding(10)
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
                Circle()
                    .fill(Color.gold.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(Color.gold)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.query)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(item.typeLabel + " · " + item.createdAt.formatted(.relative(presentation: .named)))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundColor(.gray.opacity(0.4))
        }
        .padding(.vertical, 10)
    }
}

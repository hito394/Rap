import SwiftUI

// MARK: - Model
struct BattleLyricEntry: Codable, Identifiable {
    var id: Int { Int(start * 1000) }
    let start: Double
    let end: Double
    let lyric: String
    let explanation: String

    static func load(named filename: String = "battle") -> [BattleLyricEntry] {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([BattleLyricEntry].self, from: data)
        else { return [] }
        return entries.sorted { $0.start < $1.start }
    }
}

extension [BattleLyricEntry] {
    func current(at time: Double) -> BattleLyricEntry? {
        last(where: { $0.start <= time && time < $0.end + 2.0 })
    }
}

// MARK: - ViewModel
@Observable
class BattleSyncViewModel {
    var entries: [BattleLyricEntry] = []
    var currentEntry: BattleLyricEntry?
    var selectedEntry: BattleLyricEntry?
    var deepDiveText = ""
    var isDeepDiving = false
    var showDeepDive = false
    var activeTab: SyncTab = .nowPlaying

    enum SyncTab { case nowPlaying, allLyrics }

    init() {
        entries = BattleLyricEntry.load()
    }

    func updateTime(_ time: Double) {
        let matched = entries.current(at: time)
        if matched?.id != currentEntry?.id {
            currentEntry = matched
        }
    }

    func startDeepDive(for entry: BattleLyricEntry) {
        selectedEntry = entry
        deepDiveText = ""
        isDeepDiving = true
        showDeepDive = true

        Task { @MainActor in
            do {
                let result = try await AnthropicService.deepDiveLyric(
                    lyric: entry.lyric,
                    explanation: entry.explanation
                )
                deepDiveText = result
            } catch {
                deepDiveText = "エラー: \(error.localizedDescription)"
            }
            isDeepDiving = false
        }
    }

    func closeDeepDive() {
        showDeepDive = false
        selectedEntry = nil
        deepDiveText = ""
    }
}

// MARK: - Main View
struct BattleSyncView: View {
    @Bindable var vm: BattleSyncViewModel
    var onSeek: ((Double) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            if vm.entries.isEmpty {
                emptyState
            } else {
                // Tab bar
                syncTabBar

                // Content
                if vm.activeTab == .nowPlaying {
                    nowPlayingTab
                } else {
                    allLyricsTab
                }
            }
        }
        .sheet(isPresented: $vm.showDeepDive) {
            if let entry = vm.selectedEntry {
                LyricDeepDiveSheet(
                    entry: entry,
                    text: vm.deepDiveText,
                    isLoading: vm.isDeepDiving,
                    onClose: { vm.closeDeepDive() }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Empty state
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.slash")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundColor(Color.gold.opacity(0.4))
            Text("battle.json が見つかりません")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundColor(.white)
            Text("analyze_battle.py で解析後、\nbattle.json をアプリに追加してください")
                .font(.system(.caption))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    // MARK: - Tab bar
    private var syncTabBar: some View {
        HStack(spacing: 0) {
            SyncTabButton(title: "NOW PLAYING", icon: "waveform", tab: .nowPlaying, selected: $vm.activeTab)
            SyncTabButton(title: "全ライン", icon: "list.bullet", tab: .allLyrics, selected: $vm.activeTab)
        }
        .background(Color(hex: "#111111"))
        .overlay(Divider().background(Color.divider), alignment: .bottom)
    }

    // MARK: - Now Playing tab
    private var nowPlayingTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if let entry = vm.currentEntry {
                    ActiveLyricCard(entry: entry) { vm.startDeepDive(for: entry) }
                        .id(entry.id)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                } else {
                    waitingCard
                }

                Spacer().frame(height: 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: vm.currentEntry?.id)
        }
    }

    private var waitingCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "play.circle")
                .font(.system(size: 28, weight: .ultraLight))
                .foregroundColor(Color.gold.opacity(0.5))
            Text("再生するとリリックが同期されます")
                .font(.system(.caption))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .cardStyle()
    }

    // MARK: - All lyrics tab
    private var allLyricsTab: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 6) {
                    ForEach(vm.entries) { entry in
                        LyricRow(
                            entry: entry,
                            isActive: entry.id == vm.currentEntry?.id,
                            onTap: { onSeek?(entry.start) },
                            onDeepDive: { vm.startDeepDive(for: entry) }
                        )
                        .id(entry.id)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .onChange(of: vm.currentEntry?.id) { _, newID in
                guard let id = newID else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }
}

// MARK: - Active lyric card
private struct ActiveLyricCard: View {
    let entry: BattleLyricEntry
    let onDeepDive: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label(formatTime(entry.start), systemImage: "clock")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color.gold)
                Spacer()
                Button(action: onDeepDive) {
                    Label("詳しく", systemImage: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#0d0d0d"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.gold)
                        .cornerRadius(20)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)

            // Lyric
            HStack(alignment: .top, spacing: 10) {
                Rectangle()
                    .fill(Color.gold)
                    .frame(width: 3)
                    .cornerRadius(2)
                Text(entry.lyric)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            // Explanation
            Text(entry.explanation)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.65))
                .lineSpacing(5)
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
        }
        .background(Color(hex: "#141414"))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gold.opacity(0.25), lineWidth: 1))
        .shadow(color: Color.gold.opacity(0.06), radius: 12)
    }

    private func formatTime(_ t: Double) -> String {
        String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

// MARK: - Lyric row (all lyrics tab)
private struct LyricRow: View {
    let entry: BattleLyricEntry
    let isActive: Bool
    let onTap: () -> Void
    let onDeepDive: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 3) {
                    Circle()
                        .fill(isActive ? Color.gold : Color.white.opacity(0.1))
                        .frame(width: 7, height: 7)
                        .scaleEffect(isActive ? 1.4 : 1)
                        .animation(.easeInOut(duration: 0.2), value: isActive)
                    Text(formatTime(entry.start))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(isActive ? Color.gold : .gray)
                }
                .frame(width: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.lyric)
                        .font(.system(size: 13, weight: isActive ? .bold : .regular))
                        .foregroundColor(isActive ? .white : .white.opacity(0.55))
                        .lineLimit(2)
                    if isActive {
                        Text(entry.explanation)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(2)
                    }
                }

                Spacer()

                if isActive {
                    Button(action: onDeepDive) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                            .foregroundColor(Color.gold)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isActive ? Color.gold.opacity(0.05) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? Color.gold.opacity(0.2) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }

    private func formatTime(_ t: Double) -> String {
        String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

// MARK: - Sync tab button
private struct SyncTabButton: View {
    let title: String
    let icon: String
    let tab: BattleSyncViewModel.SyncTab
    @Binding var selected: BattleSyncViewModel.SyncTab

    var isSelected: Bool { selected == tab }

    var body: some View {
        Button { selected = tab } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 14))
                Text(title).font(.system(size: 9, weight: .semibold, design: .monospaced))
            }
            .foregroundColor(isSelected ? Color.gold : .gray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .overlay(
                Rectangle()
                    .fill(isSelected ? Color.gold : Color.clear)
                    .frame(height: 2),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Deep dive sheet
struct LyricDeepDiveSheet: View {
    let entry: BattleLyricEntry
    let text: String
    let isLoading: Bool
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // Lyric
                    VStack(alignment: .leading, spacing: 8) {
                        Label("解析ライン", systemImage: "text.quote")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color.gold)
                        HStack(alignment: .top, spacing: 10) {
                            Rectangle()
                                .fill(Color.gold)
                                .frame(width: 3)
                                .cornerRadius(2)
                            Text(entry.lyric)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(14)
                    .cardStyle(padding: 0)

                    // Analysis
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("ディープダイブ解析", systemImage: "sparkles")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.gold)
                            Spacer()
                            if isLoading {
                                ProgressView().tint(Color.gold).scaleEffect(0.7)
                            }
                        }
                        if text.isEmpty && isLoading {
                            ForEach(0..<4, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.06))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 12)
                            }
                        } else {
                            Text(text)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.85))
                                .lineSpacing(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(14)
                    .cardStyle(padding: 0)
                }
                .padding(16)
            }
            .background(Color.appBackground)
            .navigationTitle("Deep Dive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる", action: onClose).foregroundColor(Color.gold)
                }
            }
        }
    }
}

private func formatTime(_ t: Double) -> String {
    String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
}

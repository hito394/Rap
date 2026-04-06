import SwiftUI

struct ContentView: View {
    @State private var vm = BattleViewModel()
    @State private var selectedTab: Tab = .player

    enum Tab { case player, lyrics }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Video player (fixed 16:9 ratio)
                if !vm.videoID.isEmpty {
                    PlayerView(videoID: vm.videoID, vm: vm)
                        .aspectRatio(16/9, contentMode: .fit)
                        .background(Color.black)
                } else {
                    noVideoPlaceholder
                        .aspectRatio(16/9, contentMode: .fit)
                }

                // Battle info header
                battleHeader

                // Tab bar
                tabBar

                // Tab content
                ZStack {
                    switch selectedTab {
                    case .player:
                        playerTab
                    case .lyrics:
                        lyricsTab
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $vm.showDeepDive) {
            if let entry = vm.selectedEntry {
                DeepDiveView(
                    entry: entry,
                    deepDiveText: vm.deepDiveText,
                    isLoading: vm.isDeepDiving,
                    onClose: { vm.closeDeepDive() }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - No video placeholder
    private var noVideoPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.cardBorder)
            Text("battle.jsonに videoID を設定してください")
                .font(.monoSmall)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    // MARK: - Battle header
    private var battleHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(vm.rapper1) VS \(vm.rapper2)")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                Text("\(vm.entries.count) ライン収録")
                    .font(.monoSmall)
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            // Current time
            Text(formatTime(vm.currentTime))
                .font(.monoMedium)
                .foregroundColor(.gold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.cardBg)
    }

    // MARK: - Tab bar
    private var tabBar: some View {
        HStack(spacing: 0) {
            TabButton(title: "NOW PLAYING", icon: "waveform", tab: .player, selected: $selectedTab)
            TabButton(title: "ALL LYRICS", icon: "list.bullet", tab: .lyrics, selected: $selectedTab)
        }
        .background(Color.cardBg)
        .overlay(Divider().background(Color.cardBorder), alignment: .top)
    }

    // MARK: - Player tab (current lyric + explanation)
    private var playerTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                LyricDisplayView(
                    entry: vm.currentEntry,
                    onDeepDive: { vm.startDeepDive(for: $0) }
                )
                .padding(.horizontal, 16)
                .padding(.top, 16)

                Spacer(minLength: 60)
            }
        }
        .background(Color.appBg)
    }

    // MARK: - Lyrics tab (full scrollable list)
    private var lyricsTab: some View {
        ExplanationScrollView(
            entries: vm.entries,
            currentEntry: vm.currentEntry,
            onTap: { vm.jumpToEntry($0) }
        )
        .background(Color.appBg)
    }

    private func formatTime(_ t: Double) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Tab button
private struct TabButton: View {
    let title: String
    let icon: String
    let tab: ContentView.Tab
    @Binding var selected: ContentView.Tab

    var isSelected: Bool { selected == tab }

    var body: some View {
        Button { selected = tab } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
            }
            .foregroundColor(isSelected ? .gold : .textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .overlay(
                Rectangle()
                    .fill(isSelected ? Color.gold : Color.clear)
                    .frame(height: 2),
                alignment: .top
            )
        }
        .buttonStyle(.plain)
    }
}

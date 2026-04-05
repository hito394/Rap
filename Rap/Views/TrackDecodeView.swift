import SwiftUI
import SwiftData
import AVFoundation

@Observable
class TrackDetailViewModel {
    var titleText = ""
    var artistText = ""
    var isLoading = false
    var result: TrackDecode?
    var rawResult: String?
    var toastMessage: String?
    var selectedTab = 0

    // iTunes
    var iTunesTrack: iTunesTrack? = nil
    var isPlayingPreview = false
    private var audioPlayer: AVPlayer? = nil

    // Predictive search
    var suggestions: [iTunesTrack] = []
    var showSuggestions = false
    private var suggestTask: Task<Void, Never>? = nil

    func updateSuggestions(for title: String) {
        suggestTask?.cancel()
        guard title.count >= 2 else {
            suggestions = []
            showSuggestions = false
            return
        }
        suggestTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000) // 350ms debounce
            guard !Task.isCancelled else { return }
            let results = await iTunesService.searchByTitle(query: title)
            if !Task.isCancelled {
                suggestions = results
                showSuggestions = !results.isEmpty
            }
        }
    }

    func selectSuggestion(_ track: iTunesTrack) {
        titleText = track.trackName
        artistText = track.artistName
        iTunesTrack = track
        showSuggestions = false
        suggestions = []
        suggestTask?.cancel()
    }

    var canDecode: Bool {
        !titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !artistText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isLoading
    }

    var allSlangs: [SlangDefinition] {
        var defs: [SlangDefinition] = result?.slangGlossary.map { $0.asDefinition() } ?? []
        if let bars = result?.keyBars {
            for bar in bars {
                defs += bar.slangBreakdown?.map { $0.asDefinition() } ?? []
            }
        }
        // Deduplicate by word
        var seen = Set<String>()
        return defs.filter { seen.insert($0.word.lowercased()).inserted }
    }

    func selectPickup(_ track: PickupTrack) {
        titleText = track.title
        artistText = track.artist
        result = nil
        rawResult = nil
        selectedTab = 0
        iTunesTrack = nil
        stopPreview()
    }

    func togglePreview() {
        guard let urlStr = iTunesTrack?.previewUrl, let url = URL(string: urlStr) else { return }
        if isPlayingPreview {
            audioPlayer?.pause()
            isPlayingPreview = false
        } else {
            if audioPlayer == nil {
                audioPlayer = AVPlayer(url: url)
            }
            audioPlayer?.seek(to: .zero)
            audioPlayer?.play()
            isPlayingPreview = true
        }
    }

    func stopPreview() {
        audioPlayer?.pause()
        audioPlayer = nil
        isPlayingPreview = false
    }

    func decode(saveHistory: (HistoryItem) -> Void) async {
        guard canDecode else { return }
        isLoading = true
        result = nil
        rawResult = nil
        stopPreview()

        async let trackResult: String = AnthropicService.decodeTrack(title: titleText, artist: artistText)
        async let itunesResult = iTunesService.search(title: titleText, artist: artistText)

        do {
            let raw = try await trackResult
            rawResult = raw
            result = TrackDecode.parse(from: raw)
            let query = "\(titleText) / \(artistText)"
            saveHistory(HistoryItem(type: "track", query: query, resultJSON: raw))
        } catch {
            toastMessage = (error as? AnthropicError)?.errorDescription ?? "接続を確認してください"
        }

        iTunesTrack = await itunesResult
        audioPlayer = nil
        isLoading = false
    }
}

// MARK: - Main View (streaming layout)
struct TrackDecodeView: View {
    @State private var vm = TrackDetailViewModel()
    @Environment(\.modelContext) private var context
    @State private var selectedSlang: SlangDefinition?
    @State private var showSlang = false
    @State private var showSearch = true

    // Called from DiscoverView when a pickup card is tapped
    var preselected: PickupTrack? = nil

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero header
                    TrackHeroHeader(
                        title: vm.titleText,
                        artist: vm.artistText,
                        isLoading: vm.isLoading,
                        artworkUrl: vm.iTunesTrack?.artworkUrl500,
                        hasPreview: vm.iTunesTrack?.previewUrl != nil,
                        isPlayingPreview: vm.isPlayingPreview,
                        onAnalyze: vm.canDecode ? {
                            Task { await vm.decode { context.insert($0) } }
                        } : nil,
                        onTogglePreview: { vm.togglePreview() }
                    )

                    // Input fields (collapsible)
                    if showSearch {
                        inputSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                    }

                    // Toggle search bar
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { showSearch.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: showSearch ? "chevron.up" : "magnifyingglass")
                                .font(.system(size: 11))
                            Text(showSearch ? "入力を隠す" : "曲を変更する")
                                .font(.system(size: 12, design: .monospaced))
                        }
                        .foregroundColor(.gray)
                    }
                    .padding(.bottom, 12)

                    if vm.isLoading {
                        VStack(spacing: 12) {
                            AnalyzingIndicator()
                            LoadingView().padding(.horizontal, 20)
                        }
                        .padding(.top, 8)
                    }

                    if let result = vm.result {
                        resultTabs(result)
                    } else if let raw = vm.rawResult, vm.result == nil && !vm.isLoading {
                        Text(raw)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(20)
                    }

                    // Pickup when no result yet
                    if vm.result == nil && !vm.isLoading {
                        pickupSection
                    }

                    Spacer().frame(height: 40)
                }
            }
            .background(Color.appBackground)
            .navigationTitle("TRACK DECODE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .toast(message: $vm.toastMessage)
        .sheet(isPresented: $showSlang) {
            if let slang = selectedSlang {
                SlangSheet(definition: slang)
            }
        }
        .onAppear {
            if let track = preselected {
                vm.selectPickup(track)
            }
        }
    }

    // MARK: Input section
    private var inputSection: some View {
        VStack(spacing: 10) {
            VStack(spacing: 0) {
                InputField(placeholder: "曲名", text: $vm.titleText, icon: "music.note")
                    .onChange(of: vm.titleText) { _, new in
                        vm.updateSuggestions(for: new)
                    }

                if vm.showSuggestions {
                    SuggestionDropdown(suggestions: vm.suggestions) { track in
                        vm.selectSuggestion(track)
                    }
                    .zIndex(10)
                }
            }
            InputField(placeholder: "アーティスト名", text: $vm.artistText, icon: "person.fill")
        }
    }

    // MARK: Result tabs
    @ViewBuilder
    private func resultTabs(_ r: TrackDecode) -> some View {
        VStack(spacing: 0) {
            let tabs = ["概要", "バース", "サンプル", "スラング"]
            SegmentControl(tabs: tabs, selected: $vm.selectedTab)
                .padding(.bottom, 1)
            Divider().background(Color.divider)

            Group {
                switch vm.selectedTab {
                case 0: overviewTab(r)
                case 1: barsTab(r)
                case 2: samplesTab(r)
                case 3: slangTab(r)
                default: overviewTab(r)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }

    // MARK: Tab 0: Overview
    @ViewBuilder
    private func overviewTab(_ r: TrackDecode) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            InfoCard(title: "Background", body: r.background, icon: "doc.text.fill")
            InfoCard(title: "Era Context", body: r.eraContext, icon: "clock.fill")

            if !r.rhymeTechniques.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Rhyme Techniques")
                    FlowLayout(spacing: 6) {
                        ForEach(r.rhymeTechniques, id: \.self) { GoldTag(text: $0) }
                    }
                }
                .padding(14)
                .cardStyle()
            }

            if !r.influences.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.circle.fill")
                            .font(.system(size: 11)).foregroundColor(Color.gold)
                        SectionHeader(title: "Influences")
                    }
                    ForEach(r.influences, id: \.self) { inf in
                        HStack(spacing: 8) {
                            Rectangle().fill(Color.gold).frame(width: 2, height: 14)
                            Text(inf)
                                .font(.system(.subheadline))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                }
                .padding(14)
                .cardStyle()
            }

            InfoCard(title: "Legacy", body: r.legacy, icon: "star.fill")
        }
    }

    // MARK: Tab 1: Bars (tappable slang)
    @ViewBuilder
    private func barsTab(_ r: TrackDecode) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !vm.allSlangs.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color.gold)
                    Text("金色の単語をタップで解説")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 4)
            }

            ForEach(r.keyBars) { bar in
                TappableBarCard(
                    bar: bar,
                    allSlangs: vm.allSlangs,
                    onSlangTap: { slang in
                        selectedSlang = slang
                        showSlang = true
                    }
                )
            }
        }
    }

    // MARK: Tab 2: Samples
    @ViewBuilder
    private func samplesTab(_ r: TrackDecode) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if r.samples.isEmpty {
                EmptyTabMessage(text: "サンプリング情報なし\n（オリジナル楽曲の可能性）",
                                icon: "waveform.path")
            } else {
                SamplingSection(samples: r.samples)
            }
        }
    }

    // MARK: Tab 3: Slang glossary
    @ViewBuilder
    private func slangTab(_ r: TrackDecode) -> some View {
        if vm.allSlangs.isEmpty {
            EmptyTabMessage(text: "スラング情報なし", icon: "text.bubble")
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(vm.allSlangs) { slang in
                    Button {
                        selectedSlang = slang
                        showSlang = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(slang.word)
                                    .font(.system(.subheadline, design: .monospaced, weight: .bold))
                                    .foregroundColor(Color.gold)
                                Text(slang.meaning)
                                    .font(.system(.caption))
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(1)
                            }
                            Spacer()
                            if let region = slang.region {
                                Text(region)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.gray)
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundColor(.gray.opacity(0.4))
                        }
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)

                    if slang.id != vm.allSlangs.last?.id {
                        Divider().background(Color.divider)
                    }
                }
            }
            .padding(.horizontal, 4)
            .cardStyle()
            .padding(.horizontal, -4)
        }
    }

    // MARK: Pickup section
    private var pickupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11)).foregroundColor(Color.gold)
                Text("Pickup Tracks".uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.gray).tracking(1.2)
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(PickupTrack.list) { track in
                        StreamingTrackCard(track: track) { vm.selectPickup(track) }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Bar card: lyric prominently + explanation always visible
struct TappableBarCard: View {
    let bar: KeyBar
    let allSlangs: [SlangDefinition]
    var onSlangTap: (SlangDefinition) -> Void

    private var barSlangs: [SlangDefinition] {
        var defs = allSlangs
        if let breakdown = bar.slangBreakdown {
            let extra = breakdown.map { $0.asDefinition() }
            var seen = Set(defs.map { $0.word.lowercased() })
            defs += extra.filter { seen.insert($0.word.lowercased()).inserted }
        }
        return defs
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Lyric line — prominent
            TappableLyricsView(
                text: bar.bar,
                slangDefinitions: barSlangs,
                onTap: onSlangTap
            )

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            // Explanation — always visible
            Text(bar.explanation)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)

            // Subtext (hidden meaning)
            if let subtext = bar.subtext, !subtext.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Text("裏")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundColor(Color.gold)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.gold.opacity(0.12))
                        .cornerRadius(3)
                    Text(subtext)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                }
            }

            // Slang chips
            if !barSlangs.filter({ bar.bar.contains($0.word) }).isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(barSlangs.filter { bar.bar.contains($0.word) }) { slang in
                            Button {
                                onSlangTap(slang)
                            } label: {
                                Text(slang.word)
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundColor(Color.gold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gold.opacity(0.1))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gold.opacity(0.3), lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(14)
        .cardStyle()
    }
}

// MARK: - Suggestion Dropdown
struct SuggestionDropdown: View {
    let suggestions: [iTunesTrack]
    let onSelect: (iTunesTrack) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(suggestions) { track in
                Button { onSelect(track) } label: {
                    HStack(spacing: 10) {
                        if let urlStr = track.artworkUrl100, let url = URL(string: urlStr) {
                            AsyncImage(url: url) { phase in
                                if case .success(let img) = phase {
                                    img.resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    Color.gray.opacity(0.2)
                                }
                            }
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        } else {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gold.opacity(0.15))
                                .frame(width: 36, height: 36)
                                .overlay(Image(systemName: "music.note").font(.system(size: 14)).foregroundColor(Color.gold.opacity(0.5)))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.trackName)
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(track.artistName)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(Color.gold)
                                .lineLimit(1)
                        }
                        Spacer()
                        if track.previewUrl != nil {
                            Image(systemName: "waveform")
                                .font(.system(size: 10))
                                .foregroundColor(.gray.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                }
                .buttonStyle(.plain)

                if track.id != suggestions.last?.id {
                    Divider().background(Color.divider).padding(.leading, 58)
                }
            }
        }
        .background(Color(hex: "#1c1c1e"))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 12, y: 4)
        .padding(.top, 2)
    }
}

// MARK: - Empty state for tabs
struct EmptyTabMessage: View {
    let text: String
    let icon: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .ultraLight))
                .foregroundColor(.gray.opacity(0.4))
            Text(text)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

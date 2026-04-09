import SwiftUI
import SwiftData
import AVFoundation

// MARK: - Kana vowel helpers for rhyme detection

/// Maps hiragana/katakana characters to their vowel sound (a/i/u/e/o)
private let kanaVowelTable: [Character: Character] = {
    var m: [Character: Character] = [
        // あ行 a-vowel
        "あ": "a", "ぁ": "a", "か": "a", "が": "a", "さ": "a", "ざ": "a",
        "た": "a", "だ": "a", "な": "a", "は": "a", "ば": "a", "ぱ": "a",
        "ま": "a", "や": "a", "ゃ": "a", "ら": "a", "わ": "a", "ゎ": "a",
        // い行 i-vowel
        "い": "i", "ぃ": "i", "き": "i", "ぎ": "i", "し": "i", "じ": "i",
        "ち": "i", "ぢ": "i", "に": "i", "ひ": "i", "び": "i", "ぴ": "i",
        "み": "i", "り": "i",
        // う行 u-vowel
        "う": "u", "ぅ": "u", "く": "u", "ぐ": "u", "す": "u", "ず": "u",
        "つ": "u", "づ": "u", "ぬ": "u", "ふ": "u", "ぶ": "u", "ぷ": "u",
        "む": "u", "ゆ": "u", "ゅ": "u", "る": "u", "ゔ": "u",
        // え行 e-vowel
        "え": "e", "ぇ": "e", "け": "e", "げ": "e", "せ": "e", "ぜ": "e",
        "て": "e", "で": "e", "ね": "e", "へ": "e", "べ": "e", "ぺ": "e",
        "め": "e", "れ": "e",
        // お行 o-vowel
        "お": "o", "ぉ": "o", "こ": "o", "ご": "o", "そ": "o", "ぞ": "o",
        "と": "o", "ど": "o", "の": "o", "ほ": "o", "ぼ": "o", "ぽ": "o",
        "も": "o", "よ": "o", "ょ": "o", "ろ": "o", "を": "o",
    ]
    // Add katakana by offsetting hiragana codepoints by 0x60
    // Iterate over a snapshot to avoid mutating-during-iteration
    let hiraganaBase: UInt32 = 0x3041
    let katakanaBase: UInt32 = 0x30A1
    for (hc, vowel) in Array(m) {
        if let s = hc.unicodeScalars.first,
           s.value >= hiraganaBase,
           let ks = Unicode.Scalar(katakanaBase + (s.value - hiraganaBase)) {
            m[Character(ks)] = vowel
        }
    }
    return m
}()

/// Extract trailing vowel pattern (last `count` vowel sounds) from a token
private func trailingVowels(_ token: String, count: Int = 2) -> String {
    String(token.compactMap { kanaVowelTable[$0] }.suffix(count))
}

// MARK: - Rhyme Highlighted Text View

/// Displays a lyric bar with rhyming words color-coded by shared trailing-vowel pattern
struct RhymeHighlightedText: View {
    let text: String

    static let palette: [Color] = [
        Color(hex: "#FFD700"), // gold
        Color(hex: "#FF6B6B"), // coral
        Color(hex: "#4ECDC4"), // teal
        Color(hex: "#95E075"), // lime
        Color(hex: "#C792EA"), // purple
        Color(hex: "#F78C6C"), // peach
    ]

    var body: some View {
        buildText()
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(5)
    }

    private func buildText() -> Text {
        let cmap = rhymeColorMap()
        let parts = tokenize(text)
        return parts.reduce(Text("")) { result, token in
            if let color = cmap[token] {
                return result + Text(token)
                    .foregroundColor(color)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
            } else {
                return result + Text(token)
                    .foregroundColor(.white.opacity(0.9))
                    .font(.system(size: 16, weight: .regular, design: .monospaced))
            }
        }
    }

    /// Tokenize text into word/separator parts preserving all characters
    private func tokenize(_ text: String) -> [String] {
        let seps: Set<Character> = [" ", "　", "「", "」", "『", "』",
                                     "。", "、", "・", "…", "／", "\n", "〜",
                                     "!", "?", "！", "？", ",", "."]
        var tokens: [String] = []
        var current = ""
        for c in text {
            if seps.contains(c) {
                if !current.isEmpty { tokens.append(current); current = "" }
                tokens.append(String(c))
            } else {
                current.append(c)
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    /// Build a token→Color map for words that share a 2+ vowel trailing pattern
    private func rhymeColorMap() -> [String: Color] {
        let words = tokenize(text).filter { token in
            // Only actual words (has at least one kana)
            token.contains(where: { kanaVowelTable[$0] != nil })
        }
        var groups: [String: [String]] = [:]
        for word in words {
            let key = trailingVowels(word, count: 2)
            guard key.count >= 2 else { continue }
            groups[key, default: []].append(word)
        }
        var colorMap: [String: Color] = [:]
        var colorIdx = 0
        for key in groups.keys.sorted() {
            let groupWords = groups[key]!
            guard groupWords.count >= 2 else { continue }
            let color = Self.palette[colorIdx % Self.palette.count]
            colorIdx += 1
            for w in groupWords { colorMap[w] = color }
        }
        return colorMap
    }
}

// MARK: - Rhyme Legend (shows which vowel patterns rhyme)
struct RhymeLegend: View {
    let text: String

    var body: some View {
        legendContent()
    }

    @ViewBuilder
    private func legendContent() -> some View {
        let groups = rhymeGroups()
        if !groups.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "waveform.path")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    Text("韻パターン")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                }
                FlowLayout(spacing: 6) {
                    ForEach(Array(groups.enumerated()), id: \.offset) { idx, entry in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(RhymeHighlightedText.palette[idx % RhymeHighlightedText.palette.count])
                                .frame(width: 7, height: 7)
                            Text(entry.words.joined(separator: "・"))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                            Text("(\(entry.pattern))")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)
        }
    }

    private struct RhymeEntry { let pattern: String; let words: [String] }

    private func rhymeGroups() -> [RhymeEntry] {
        let seps: Set<Character> = [" ", "　", "「", "」", "『", "』",
                                     "。", "、", "・", "…", "／", "\n", "〜",
                                     "!", "?", "！", "？", ",", "."]
        let words = text.split { seps.contains($0) }.map(String.init)
            .filter { $0.contains(where: { kanaVowelTable[$0] != nil }) }
        var groups: [String: [String]] = [:]
        for word in words {
            let key = trailingVowels(word, count: 2)
            guard key.count >= 2 else { continue }
            groups[key, default: []].append(word)
        }
        return groups.compactMap { (key, words) -> RhymeEntry? in
            guard words.count >= 2 else { return nil }
            return RhymeEntry(pattern: key, words: Array(Set(words)).sorted())
        }.sorted { $0.pattern < $1.pattern }
    }
}

@Observable
class TrackDetailViewModel {
    var titleText = ""
    var artistText = ""
    var isLoading = false
    var result: TrackDecode?
    var rawResult: String?
    var toastMessage: String?
    var selectedTab = 0
    var selectedLevel = 1  // 0=初心者 1=中級者 2=上級者

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
            let results = await iTunesService.searchByTitle(query: title, artist: self.artistText)
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

    /// Convert Int level (0/1/2) from UI picker to ExpertiseLevel enum
    var expertiseLevel: ExpertiseLevel {
        switch selectedLevel {
        case 0: return .beginner
        case 2: return .expert
        default: return .intermediate
        }
    }

    func decode(saveHistory: (HistoryItem) -> Void) async {
        guard canDecode else { return }
        isLoading = true
        result = nil
        rawResult = nil
        stopPreview()

        let level = expertiseLevel  // capture at decode time

        // Fetch lyrics + iTunes in parallel
        async let lrcResult = LrcLibService.search(title: titleText, artist: artistText)
        async let itunesResult = iTunesService.search(title: titleText, artist: artistText)

        let (lrcTrack, itunesTrack) = await (lrcResult, itunesResult)

        do {
            let raw: String
            if let lrc = lrcTrack, let lyrics = lrc.syncedLyrics ?? lrc.plainLyrics, !lyrics.isEmpty {
                // LrcLib歌詞あり → レベル指定でClaudeが解析
                raw = try await AnthropicService.decodeTrackWithActualLyrics(
                    title: titleText, artist: artistText, lyrics: lyrics, level: level
                )
            } else {
                // フォールバック: Claudeの知識ベース解析 (レベル指定あり)
                raw = try await AnthropicService.decodeTrack(
                    title: titleText, artist: artistText, level: level
                )
            }
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
                .onChange(of: vm.artistText) { _, _ in
                    // Re-run suggestion search when artist context changes
                    vm.updateSuggestions(for: vm.titleText)
                }
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

    // MARK: Tab 1: Bars (tappable slang + level picker)
    @ViewBuilder
    private func barsTab(_ r: TrackDecode) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Level picker
            HStack(spacing: 0) {
                ForEach(Array(["初心者", "中級者", "上級者"].enumerated()), id: \.offset) { idx, label in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { vm.selectedLevel = idx }
                    } label: {
                        Text(label)
                            .font(.system(size: 11, weight: vm.selectedLevel == idx ? .bold : .regular,
                                          design: .monospaced))
                            .foregroundColor(vm.selectedLevel == idx ? Color.appBackground : .white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(vm.selectedLevel == idx ? Color.gold : Color.clear)
                    }
                    .buttonStyle(.plain)
                    if idx < 2 {
                        Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1)
                    }
                }
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
            .padding(.bottom, 2)

            if vm.selectedLevel >= 1 && !vm.allSlangs.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color.gold)
                    Text("金色の単語をタップで解説")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }

            ForEach(r.keyBars) { bar in
                TappableBarCard(
                    bar: bar,
                    allSlangs: vm.allSlangs,
                    level: vm.selectedLevel,
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

// MARK: - Bar card: level-aware display
/// level 0 = 初心者, 1 = 中級者 (default), 2 = 上級者
struct TappableBarCard: View {
    let bar: KeyBar
    let allSlangs: [SlangDefinition]
    var level: Int = 1
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
            // Lyric line — show rhyme highlighting at level ≥ 1
            if level == 0 {
                Text(bar.bar)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            } else {
                RhymeHighlightedText(text: bar.bar)
            }

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            // Explanation
            if level == 0 {
                // Beginner: plain, no jargon label
                Text(beginnerExplanation)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(5)
            } else {
                Text(bar.explanation)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }

            // Subtext (hidden meaning) — level ≥ 1
            if level >= 1, let subtext = bar.subtext, !subtext.isEmpty {
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

            // Slang chips — level ≥ 1
            let chipsInBar = barSlangs.filter { bar.bar.contains($0.word) }
            if level >= 1, !chipsInBar.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(chipsInBar) { slang in
                            Button { onSlangTap(slang) } label: {
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

            // Rhyme legend — level 2 only
            if level == 2 {
                RhymeLegend(text: bar.bar)
            }
        }
        .padding(14)
        .cardStyle()
    }

    /// Simplified beginner explanation: strip markdown bold markers, take first 2 sentences
    private var beginnerExplanation: String {
        let plain = bar.explanation
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "##", with: "")
        // Take up to ~120 chars / first sentence boundary
        let sentences = plain.components(separatedBy: CharacterSet(charactersIn: "。\n"))
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let first = sentences.prefix(2).joined(separator: "。")
        return first.isEmpty ? plain : first + (sentences.count > 2 ? "..." : "")
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

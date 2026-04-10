import SwiftUI
import SwiftData

enum LyricsInputMode { case paste, song }

@Observable
class LyricsAnalyzeViewModel {
    var inputMode: LyricsInputMode = .paste
    var lyricsText = ""
    var songTitle = ""
    var songArtist = ""
    var isLoading = false
    var result: LyricsAnalysis?
    var rawResult: String?
    var toastMessage: String?

    var rhymeResult: RhymeHighlightResult?
    var isRhymeLoading = false

    func analyzeRhymes() async {
        guard !lyricsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isRhymeLoading = true
        do {
            let raw = try await AnthropicService.analyzeRhymes(lyricsText)
            rhymeResult = RhymeHighlightResult.parse(from: raw)
        } catch {
            toastMessage = "ライム解析に失敗しました"
        }
        isRhymeLoading = false
    }

    var charCount: Int { lyricsText.count }
    var maxChars: Int { 1500 }
    var canAnalyze: Bool {
        switch inputMode {
        case .paste: return !lyricsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
        case .song: return !songTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
        }
    }

    var displayLyrics: String {
        switch inputMode {
        case .paste: return lyricsText
        case .song: return result?.lyricsExcerpt ?? ""
        }
    }

    var allSlangs: [SlangDefinition] {
        guard let r = result else { return [] }
        return r.slangGlossary.map { $0.asDefinition() }
    }

    func runAnalysis(saveHistory: (HistoryItem) -> Void) async {
        switch inputMode {
        case .paste: await analyze(saveHistory: saveHistory)
        case .song: await analyzeSong(saveHistory: saveHistory)
        }
    }

    private func analyze(saveHistory: (HistoryItem) -> Void) async {
        guard canAnalyze else { return }
        isLoading = true; result = nil; rawResult = nil
        do {
            let raw = try await AnthropicService.analyzeLyrics(lyricsText)
            rawResult = raw
            result = LyricsAnalysis.parse(from: raw)
            saveHistory(HistoryItem(type: "lyrics", query: String(lyricsText.prefix(80)), resultJSON: raw))
        } catch {
            toastMessage = (error as? AnthropicError)?.errorDescription ?? "接続を確認してください"
        }
        isLoading = false
    }

    private func analyzeSong(saveHistory: (HistoryItem) -> Void) async {
        guard canAnalyze else { return }
        isLoading = true; result = nil; rawResult = nil
        let query = songArtist.isEmpty ? songTitle : "\(songArtist) - \(songTitle)"

        // Fetch lyrics in parallel: Genius (primary) + LrcLib (fallback)
        async let geniusTask = GeniusService.getLyrics(title: songTitle, artist: songArtist)
        async let lrcTask    = LrcLibService.search(title: songTitle, artist: songArtist)
        let (geniusLyrics, lrcTrack) = await (geniusTask, lrcTask)

        let lyrics: String?
        if let gl = geniusLyrics, !gl.isEmpty {
            lyrics = gl
            print("🎵 [LyricsAnalyze] using Genius lyrics")
        } else if let lrc = lrcTrack, let l = lrc.syncedLyrics ?? lrc.plainLyrics, !l.isEmpty {
            lyrics = l
            print("🎵 [LyricsAnalyze] using LrcLib lyrics")
        } else {
            lyrics = nil
            print("🎵 [LyricsAnalyze] no lyrics found — Claude will use training knowledge")
        }

        do {
            let raw: String
            if let l = lyrics {
                // Analyze with actual lyrics for higher accuracy
                raw = try await AnthropicService.analyzeLyrics(l)
            } else {
                // Fallback: Claude uses its training knowledge
                raw = try await AnthropicService.analyzeSong(title: songTitle, artist: songArtist)
            }
            rawResult = raw
            result = LyricsAnalysis.parse(from: raw)
            saveHistory(HistoryItem(type: "lyrics", query: query, resultJSON: raw))
        } catch {
            toastMessage = (error as? AnthropicError)?.errorDescription ?? "接続を確認してください"
        }
        isLoading = false
    }
}

// MARK: - Main View
struct LyricsAnalyzeView: View {
    @State private var vm = LyricsAnalyzeViewModel()
    @Environment(\.modelContext) private var context

    @State private var selectedSlang: SlangDefinition?
    @State private var showSlang = false
    @State private var selectedTab = 0
    @State private var inputCollapsed = false

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Input panel
                    inputPanel
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 12)

                    if vm.isLoading {
                        VStack(spacing: 12) {
                            AnalyzingIndicator()
                            LoadingView().padding(.horizontal, 20)
                        }
                        .padding(.top, 8)
                    }

                    if let result = vm.result {
                        resultSection(result)
                    } else if let raw = vm.rawResult, vm.result == nil && !vm.isLoading {
                        Text(raw)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(20)
                    }

                    Spacer().frame(height: 40)
                }
            }
            .background(Color.appBackground)
            .navigationTitle("LYRICS ANALYZE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .toast(message: $vm.toastMessage)
        .sheet(isPresented: $showSlang) {
            if let slang = selectedSlang { SlangSheet(definition: slang) }
        }
    }

    // MARK: Input panel
    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Mode toggle
            Picker("", selection: $vm.inputMode) {
                Text("歌詞を貼り付け").tag(LyricsInputMode.paste)
                Text("曲名で検索").tag(LyricsInputMode.song)
            }
            .pickerStyle(.segmented)
            .onChange(of: vm.inputMode) { _, _ in
                vm.result = nil; vm.rawResult = nil; inputCollapsed = false
            }

            if vm.inputMode == .paste {
                // Lyrics paste UI
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $vm.lyricsText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(minHeight: inputCollapsed ? 0 : 140,
                               maxHeight: inputCollapsed ? 0 : 220)
                        .onChange(of: vm.lyricsText) { _, new in
                            if new.count > vm.maxChars {
                                vm.lyricsText = String(new.prefix(vm.maxChars))
                            }
                        }
                    if vm.lyricsText.isEmpty && !inputCollapsed {
                        Text("ここに歌詞を貼り付け...")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.4))
                            .padding(.top, 8).padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                }
                .padding(12)
                .cardStyle()
                .animation(.easeInOut(duration: 0.25), value: inputCollapsed)

                HStack {
                    Text("\(vm.charCount) / \(vm.maxChars)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(vm.charCount > vm.maxChars - 100 ? Color.gold : .gray)
                    Spacer()
                    if vm.result != nil {
                        Button(inputCollapsed ? "入力を開く" : "入力を隠す") {
                            withAnimation(.easeInOut(duration: 0.25)) { inputCollapsed.toggle() }
                        }
                        .font(.system(size: 12)).foregroundColor(.gray)
                    }
                    if !vm.lyricsText.isEmpty {
                        Button("クリア") {
                            vm.lyricsText = ""; vm.result = nil; vm.rawResult = nil; inputCollapsed = false
                        }
                        .font(.system(size: 12)).foregroundColor(.gray)
                    }
                }
            } else {
                // Song search UI
                VStack(spacing: 8) {
                    InputField(placeholder: "曲名（例: Guidance、Kawasaki Drift）",
                               text: $vm.songTitle, icon: "music.note")
                    InputField(placeholder: "アーティスト（例: BAD HOP、KOHH）※省略可",
                               text: $vm.songArtist, icon: "person.fill")
                }
                if vm.result != nil {
                    HStack {
                        Spacer()
                        Button("クリア") {
                            vm.songTitle = ""; vm.songArtist = ""
                            vm.result = nil; vm.rawResult = nil; inputCollapsed = false
                        }
                        .font(.system(size: 12)).foregroundColor(.gray)
                    }
                }
            }

            Button("解析する") {
                inputCollapsed = true
                Task { await vm.runAnalysis { context.insert($0) } }
            }
            .buttonStyle(PrimaryButtonStyle(isLoading: vm.isLoading))
            .disabled(!vm.canAnalyze)
        }
    }

    // MARK: Result
    @ViewBuilder
    private func resultSection(_ r: LyricsAnalysis) -> some View {
        VStack(spacing: 0) {
            // Artist background + song context (song mode only)
            if vm.inputMode == .song,
               r.artistBackground != nil || r.songContext != nil {
                artistContextSection(r)
            }

            // Flow score banner
            flowScoreBanner(r)

            let tabs = ["歌詞", "ライム", "スラング", "文化"]
            SegmentControl(tabs: tabs, selected: $selectedTab)
                .padding(.bottom, 1)
            Divider().background(Color.divider)

            Group {
                switch selectedTab {
                case 0: lyricsTab(r)
                case 1: rhymeTab(r)
                case 2: slangTab(r)
                case 3: cultureTab(r)
                default: lyricsTab(r)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
        }
    }

    // MARK: Artist context section (song mode)
    @ViewBuilder
    private func artistContextSection(_ r: LyricsAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let bg = r.artistBackground {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 11)).foregroundColor(Color.gold)
                        Text("ARTIST BACKGROUND")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.gray).tracking(1.2)
                    }
                    Text(bg)
                        .font(.system(.subheadline))
                        .foregroundColor(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(4)
                }
                .padding(14)
                .cardStyle()
            }
            if let ctx = r.songContext {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 11)).foregroundColor(Color.gold)
                        Text("SONG CONTEXT")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.gray).tracking(1.2)
                    }
                    Text(ctx)
                        .font(.system(.subheadline))
                        .foregroundColor(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(4)
                }
                .padding(14)
                .cardStyle()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: Flow score banner
    private func flowScoreBanner(_ r: LyricsAnalysis) -> some View {
        HStack(spacing: 16) {
            ScoreRing(score: r.flowScore)
            VStack(alignment: .leading, spacing: 4) {
                Text("Flow Score")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.gray)
                    .tracking(1)
                Text(r.flowComment)
                    .font(.system(.subheadline))
                    .foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [Color.gold.opacity(0.08), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    // MARK: Tab 0: Lyrics (tappable)
    @ViewBuilder
    private func lyricsTab(_ r: LyricsAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !vm.allSlangs.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 11)).foregroundColor(Color.gold)
                    Text("金色の単語をタップで解説")
                        .font(.system(size: 11, design: .monospaced)).foregroundColor(.gray)
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                TappableLyricsView(
                    text: vm.displayLyrics,
                    slangDefinitions: vm.allSlangs,
                    onTap: { slang in
                        selectedSlang = slang
                        showSlang = true
                    }
                )
                .padding(16)
            }
            .cardStyle()

            // Key bars (song mode)
            if let bars = r.keyBars, !bars.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "text.quote")
                            .font(.system(size: 11)).foregroundColor(Color.gold)
                        SectionHeader(title: "バース解説")
                        Spacer()
                        Text("\(bars.count)ライン")
                            .font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                    }
                    ForEach(bars) { bar in
                        LyricsBarCard(bar: bar)
                    }
                }
                .padding(14).cardStyle()
            }

            // Rhyme highlight section
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 11)).foregroundColor(Color.gold)
                    SectionHeader(title: "韻のビジュアライズ")
                }
                if let rhymeResult = vm.rhymeResult {
                    RhymeHighlightView(result: rhymeResult)
                } else {
                    Button {
                        Task { await vm.analyzeRhymes() }
                    } label: {
                        HStack(spacing: 8) {
                            if vm.isRhymeLoading {
                                ProgressView().tint(Color(hex: "#0d0d0d")).scaleEffect(0.8)
                            }
                            Text(vm.isRhymeLoading ? "解析中..." : "韻をビジュアライズ")
                                .font(.system(.subheadline, weight: .bold))
                                .foregroundColor(Color(hex: "#0d0d0d"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.gold)
                        .cornerRadius(4)
                    }
                    .disabled(vm.isRhymeLoading)
                }
            }
            .padding(14).cardStyle()

            InfoCard(title: "Highlights", body: r.highlights, icon: "sparkles")
            InfoCard(title: "Advice", body: r.tips, icon: "lightbulb.fill")
        }
    }

    // MARK: Tab 1: Rhyme
    @ViewBuilder
    private func rhymeTab(_ r: LyricsAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if !r.rhymeTypes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Techniques")
                    FlowLayout(spacing: 6) {
                        ForEach(r.rhymeTypes, id: \.self) { GoldTag(text: $0) }
                    }
                }
                .padding(14).cardStyle()
            }

            if !r.rhymePairs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Rhyme Pairs")
                    ForEach(r.rhymePairs) { RhymePairRow(pair: $0) }
                }
                .padding(14).cardStyle()
            }

            if !r.doubleEntendres.isEmpty {
                DoubleEntendresSection(items: r.doubleEntendres)
            }
        }
    }

    // MARK: Tab 2: Slang
    @ViewBuilder
    private func slangTab(_ r: LyricsAnalysis) -> some View {
        if r.slangGlossary.isEmpty {
            EmptyTabMessage(text: "スラング情報なし", icon: "text.bubble")
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(r.slangGlossary.map { $0.asDefinition() }) { slang in
                    Button {
                        selectedSlang = slang
                        showSlang = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(slang.word)
                                        .font(.system(.subheadline, design: .monospaced, weight: .bold))
                                        .foregroundColor(Color.gold)
                                    if let r = slang.reading {
                                        Text(r)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.gray)
                                    }
                                }
                                Text(slang.meaning)
                                    .font(.system(.caption))
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundColor(.gray.opacity(0.4))
                        }
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)

                    if slang.id != r.slangGlossary.last?.id {
                        Divider().background(Color.divider)
                    }
                }
            }
            .padding(.horizontal, 14)
            .cardStyle()
        }
    }

    // MARK: Tab 3: Culture
    @ViewBuilder
    private func cultureTab(_ r: LyricsAnalysis) -> some View {
        if r.culturalReferences.isEmpty {
            EmptyTabMessage(text: "文化的参照なし", icon: "building.columns")
        } else {
            CulturalRefsSection(refs: r.culturalReferences)
        }
    }
}

// MARK: - Shared result components (referenced in both views)

struct RhymePairRow: View {
    let pair: RhymePair
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(pair.word1)
                    .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    .foregroundColor(.white)
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 10)).foregroundColor(Color.gold)
                Text(pair.word2)
                    .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                GoldTag(text: pair.type)
            }
            if let exp = pair.explanation {
                Text(exp)
                    .font(.system(.caption))
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

struct InfoCard: View {
    let title: String
    let content: String   // renamed from body to avoid conflict with View.body
    let icon: String

    // Keep external label as `body:` for backward compatibility at call sites
    init(title: String, body: String, icon: String) {
        self.title = title
        self.content = body
        self.icon = icon
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11)).foregroundColor(Color.gold)
                SectionHeader(title: title)
            }
            Text(content)
                .font(.system(.subheadline))
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .padding(14).cardStyle()
    }
}

struct LabeledText: View {
    let label: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.gold.opacity(0.7))
                .frame(width: 32, alignment: .leading)
                .padding(.top, 1)
            Text(text)
                .font(.system(.caption))
                .foregroundColor(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
    }
}

// MARK: - Slang Glossary (full expandable)
struct SlangGlossarySection: View {
    let entries: [SlangEntry]
    var onTap: ((SlangDefinition) -> Void)? = nil
    @State private var expanded: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "text.bubble.fill").font(.system(size: 11)).foregroundColor(Color.gold)
                SectionHeader(title: "Slang / 隠語")
                Spacer()
                Text("\(entries.count)語").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
            }
            .padding(.bottom, 10)

            ForEach(entries) { entry in
                if let tap = onTap {
                    Button { tap(entry.asDefinition()) } label: {
                        SlangRowContent(entry: entry, isExpanded: false) {}
                    }.buttonStyle(.plain)
                } else {
                    SlangRowContent(entry: entry, isExpanded: expanded.contains(entry.id)) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if expanded.contains(entry.id) { expanded.remove(entry.id) }
                            else { expanded.insert(entry.id) }
                        }
                    }
                }
                if entry.id != entries.last?.id {
                    Divider().background(Color.divider).padding(.vertical, 4)
                }
            }
        }
        .padding(14).cardStyle()
    }
}

struct SlangRowContent: View {
    let entry: SlangEntry
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onTap) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(entry.word)
                                .font(.system(.subheadline, design: .monospaced, weight: .bold))
                                .foregroundColor(Color.gold)
                            if let reading = entry.reading {
                                Text(reading).font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                            }
                        }
                        Text(entry.meaning)
                            .font(.system(.caption))
                            .foregroundColor(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10)).foregroundColor(.gray).padding(.top, 2)
                }
            }.buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    if let o = entry.origin { LabeledText(label: "語源", text: o) }
                    if let n = entry.usageNote { LabeledText(label: "用法", text: n) }
                    if let r = entry.region { LabeledText(label: "地域", text: r) }
                }
                .padding(.leading, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Double Entendres Section
struct DoubleEntendresSection: View {
    let items: [DoubleEntendre]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.branch").font(.system(size: 11)).foregroundColor(Color.gold)
                SectionHeader(title: "Double Meaning / 裏の意味")
            }
            ForEach(items) { DoubleEntendreCard(item: $0) }
        }
        .padding(14).cardStyle()
    }
}

struct DoubleEntendreCard: View {
    let item: DoubleEntendre

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\"" + item.line + "\"")
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .foregroundColor(Color.gold.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .italic()

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("表面").font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundColor(.gray).tracking(0.8)
                    Text(item.surface).font(.system(.caption)).foregroundColor(.white.opacity(0.6)).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)

                Rectangle().fill(Color.gold.opacity(0.3)).frame(width: 1).padding(.horizontal, 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text("真意").font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundColor(Color.gold).tracking(0.8)
                    Text(item.real).font(.system(.caption, weight: .medium)).foregroundColor(.white.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }

            if let technique = item.technique { GoldTag(text: technique) }
        }
        .padding(10)
        .background(Color.gold.opacity(0.04)).cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gold.opacity(0.15), lineWidth: 0.5))
    }
}

// MARK: - Cultural References
struct CulturalRefsSection: View {
    let refs: [CulturalReference]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "building.columns.fill").font(.system(size: 11)).foregroundColor(Color.gold)
                SectionHeader(title: "Cultural References")
            }
            ForEach(refs) { ref in
                HStack(alignment: .top, spacing: 10) {
                    Rectangle().fill(Color.gold).frame(width: 2).padding(.top, 2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(ref.reference).font(.system(.caption, weight: .bold)).foregroundColor(.white)
                        Text(ref.explanation).font(.system(.caption)).foregroundColor(.white.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true).lineSpacing(3)
                    }
                }
            }
        }
        .padding(14).cardStyle()
    }
}

// MARK: - Sampling Section
struct SamplingSection: View {
    let samples: [SampleInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "waveform.path").font(.system(size: 11)).foregroundColor(Color.gold)
                SectionHeader(title: "Sampling / 元ネタ")
                Spacer()
                Text("\(samples.count)件").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
            }
            ForEach(samples) { SampleCard(sample: $0) }
        }
        .padding(14).cardStyle()
    }
}

struct SampleCard: View {
    let sample: SampleInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "music.note").font(.system(size: 10)).foregroundColor(.gray)
                        Text(sample.originalTrack).font(.system(.subheadline, weight: .semibold)).foregroundColor(.white)
                    }
                    HStack(spacing: 6) {
                        Text(sample.originalArtist).font(.system(.caption, design: .monospaced)).foregroundColor(Color.gold)
                        if let year = sample.originalYear {
                            Text("(\(year))").font(.system(.caption)).foregroundColor(.gray)
                        }
                    }
                }
                Spacer()
                GoldTag(text: sample.sampledElement)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("使用方法").font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundColor(.gray).tracking(0.8)
                Text(sample.howUsed).font(.system(.caption)).foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true).lineSpacing(3)
            }

            if let note = sample.clearanceNote, !note.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle").font(.system(size: 10)).foregroundColor(.orange)
                    Text(note).font(.system(.caption)).foregroundColor(.orange.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.03)).cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.07), lineWidth: 0.5))
    }
}

// MARK: - Track slang section (for TrackDecodeView tab)
struct TrackSlangSection: View {
    let entries: [TrackSlangEntry]
    var onTap: ((SlangDefinition) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "text.bubble.fill").font(.system(size: 11)).foregroundColor(Color.gold)
                SectionHeader(title: "Slang / 隠語")
                Spacer()
                Text("\(entries.count)語").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
            }
            .padding(.bottom, 10)

            ForEach(entries) { entry in
                Button {
                    onTap?(entry.asDefinition())
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.word)
                                .font(.system(.subheadline, design: .monospaced, weight: .bold))
                                .foregroundColor(Color.gold)
                            Text(entry.meaning).font(.system(.caption)).foregroundColor(.white.opacity(0.7)).lineLimit(1)
                        }
                        Spacer()
                        if let r = entry.region {
                            Text(r).font(.system(size: 9, design: .monospaced)).foregroundColor(.gray)
                        }
                        Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(.gray.opacity(0.4))
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                if entry.id != entries.last?.id {
                    Divider().background(Color.divider)
                }
            }
        }
        .padding(14).cardStyle()
    }
}

// MARK: - Lyrics Bar Card (line-by-line explanation in song mode)
struct LyricsBarCard: View {
    let bar: KeyBar
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    Rectangle().fill(Color.gold).frame(width: 2).padding(.top, 2)
                    Text(bar.bar)
                        .font(.system(.subheadline, design: .monospaced, weight: .medium))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10)).foregroundColor(.gray)
                }
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(bar.explanation)
                        .font(.system(.caption))
                        .foregroundColor(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)

                    if let breakdown = bar.slangBreakdown, !breakdown.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("スラング")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundColor(.gray).tracking(0.8)
                            ForEach(breakdown) { s in
                                HStack(alignment: .top, spacing: 6) {
                                    Text(s.word)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(Color.gold)
                                    Text("→ \(s.meaning)")
                                        .font(.system(.caption))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        }
                    }

                    if let sub = bar.subtext, !sub.isEmpty {
                        HStack(alignment: .top, spacing: 6) {
                            Text("裏")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color.gold.opacity(0.7))
                                .frame(width: 20)
                            Text(sub)
                                .font(.system(.caption))
                                .foregroundColor(.white.opacity(0.6))
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(2)
                        }
                    }
                }
                .padding(.leading, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(10)
        .background(Color.white.opacity(expanded ? 0.04 : 0.02))
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4)
            .stroke(Color.gold.opacity(expanded ? 0.2 : 0.08), lineWidth: 0.5))
    }
}

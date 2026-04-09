import SwiftUI

// MARK: - Model
struct BattleLyricEntry: Codable, Identifiable {
    var id: Int { Int(start * 1000) }
    let start: Double
    let end: Double
    let lyric: String
    let explanation: String   // Claude: 意味・文脈・ディス内容
    var technique: String?    // GPT-4o: 韻構造・フロウ・パンチライン技法

    /// Load pre-analyzed battle.json from Bundle (optional shortcut)
    static func loadBundled(named filename: String = "battle") -> [BattleLyricEntry] {
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

// MARK: - Load state
enum SyncLoadState: Equatable {
    case idle
    case loading(String)
    case loadingProgress(Int, Int)
    case loaded
    case failed(String)
}

// MARK: - Source of lyrics
enum LyricSource: String {
    case server = "Whisper解析"
    case captions = "字幕AI解析"
    case ai = "AI生成"
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
    var showServerSettings = false
    var activeTab: SyncTab = .nowPlaying
    var loadState: SyncLoadState = .idle
    var lyricSource: LyricSource = .ai

    enum SyncTab { case nowPlaying, allLyrics }

    private let videoID: String
    private let title: String
    private let channel: String

    init(videoID: String, title: String, channel: String) {
        self.videoID = videoID
        self.title = title
        self.channel = channel

        // Use pre-bundled battle.json if available (instant)
        let bundled = BattleLyricEntry.loadBundled()
        if !bundled.isEmpty {
            self.entries = bundled
            self.loadState = .loaded
        }
    }

    // MARK: - Auto-load
    func startAutoLoad() {
        guard case .idle = loadState else { return }
        guard entries.isEmpty else { return }  // already loaded from bundle
        Task { await autoLoad() }
    }

    @MainActor
    private func autoLoad() async {
        // 1. Mac server (Whisper = most accurate)
        if TranscriptionService.isConfigured {
            loadState = .loading("Macサーバーに接続中...")
            let alive = await TranscriptionService.checkHealth()
            if alive {
                loadState = .loading("Whisperで文字起こし中...\n(数分かかる場合があります)")
                do {
                    entries = try await TranscriptionService.analyze(videoID: videoID)
                    lyricSource = .server
                    loadState = .loaded
                    return
                } catch {
                    print("Server failed: \(error) — falling back to captions")
                }
            }
        }

        // 2. YouTube auto-captions
        loadState = .loading("字幕を取得中...")
        let segments = await CaptionService.fetch(videoID: videoID)

        if !segments.isEmpty {
            loadState = .loadingProgress(0, segments.count)
            await analyzeWithBothAPIs(segments: segments)
            lyricSource = .captions
        } else {
            // 3. Claude-only fallback
            loadState = .loading("AIがリリックを生成中...")
            do {
                entries = try await AnthropicService.generateLyricAnalysis(
                    videoTitle: title, channel: channel
                )
                lyricSource = .ai
                loadState = entries.isEmpty ? .failed("リリックを取得できませんでした") : .loaded
            } catch {
                loadState = .failed("取得に失敗しました")
            }
        }
    }

    /// Run Claude (意味・文脈) + GPT-4o (韻・技法) in parallel, then merge.
    @MainActor
    private func analyzeWithBothAPIs(segments: [CaptionSegment]) async {
        // Run both in parallel; GPT-4o is optional (if key missing → skip)
        async let claudeTask = AnthropicService.analyzeCaptions(
            segments: segments,
            videoTitle: title,
            channel: channel
        ) { [weak self] done, total in
            Task { @MainActor [weak self] in
                self?.loadState = .loadingProgress(done, total)
            }
        }

        async let gptTask: [Int: String]? = OpenAIService.isAvailable
            ? (try? await OpenAIService.analyzeTechnique(
                segments: segments,
                videoTitle: title,
                channel: channel,
                onProgress: { _, _ in }
              ))
            : nil

        do {
            let (claudeEntries, techMap) = try await (claudeTask, gptTask)

            // Merge GPT-4o technique into Claude entries
            if let techMap {
                entries = claudeEntries.enumerated().map { i, entry in
                    var e = entry
                    e.technique = techMap[i + 1]
                    return e
                }
            } else {
                entries = claudeEntries
            }
            loadState = .loaded
        } catch {
            loadState = .failed("解析に失敗しました")
        }
    }

    func retry() {
        loadState = .idle
        entries = []
        startAutoLoad()
    }

    // MARK: - Time sync
    func updateTime(_ time: Double) {
        let matched = entries.current(at: time)
        if matched?.id != currentEntry?.id {
            currentEntry = matched
        }
    }

    // MARK: - Deep dive
    func startDeepDive(for entry: BattleLyricEntry) {
        selectedEntry = entry
        deepDiveText = ""
        isDeepDiving = true
        showDeepDive = true
        Task { @MainActor in
            do {
                deepDiveText = try await AnthropicService.deepDiveLyric(
                    lyric: entry.lyric,
                    explanation: entry.explanation
                )
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
        ZStack {
            switch vm.loadState {
            case .idle:
                Color.clear.onAppear { vm.startAutoLoad() }

            case .loading(let msg):
                LoadingStateView(message: msg, progress: nil)

            case .loadingProgress(let done, let total):
                LoadingStateView(
                    message: "AIが解析中...",
                    progress: total > 0 ? Double(done) / Double(total) : nil,
                    detail: "\(done) / \(total) ライン"
                )

            case .loaded:
                loadedContent

            case .failed(let msg):
                FailedStateView(message: msg, onRetry: { vm.retry() })
            }
        }
        .onAppear { vm.startAutoLoad() }
        .sheet(isPresented: $vm.showServerSettings) {
            ServerSettingsSheet()
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

    // MARK: - Loaded content
    private var loadedContent: some View {
        VStack(spacing: 0) {
            // Top bar: tab buttons + source badge + settings
            HStack(spacing: 0) {
                SyncTabButton(title: "NOW PLAYING", icon: "waveform", tab: .nowPlaying, selected: $vm.activeTab)
                SyncTabButton(title: "全ライン", icon: "list.bullet", tab: .allLyrics, selected: $vm.activeTab)

                // Source badge
                Text(vm.lyricSource.rawValue)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(vm.lyricSource == .server ? Color(hex: "#0d0d0d") : .gray)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(vm.lyricSource == .server ? Color.gold : Color.white.opacity(0.08))
                    .cornerRadius(4)
                    .padding(.horizontal, 6)

                // Server settings button
                Button { vm.showServerSettings = true } label: {
                    Image(systemName: TranscriptionService.isConfigured ? "server.rack" : "server.rack")
                        .font(.system(size: 14))
                        .foregroundColor(TranscriptionService.isConfigured ? Color.gold : .gray)
                        .padding(.trailing, 12)
                }
                .buttonStyle(.plain)
            }
            .frame(height: 40)
            .background(Color(hex: "#111111"))
            .overlay(Divider().background(Color.divider), alignment: .bottom)

            if vm.activeTab == .nowPlaying {
                nowPlayingTab
            } else {
                allLyricsTab
            }
        }
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
            Text("動画を再生するとリリックが同期されます")
                .font(.system(.caption))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
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

// MARK: - Loading state view
private struct LoadingStateView: View {
    let message: String
    let progress: Double?
    var detail: String? = nil

    var body: some View {
        VStack(spacing: 16) {
            if let p = progress {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: p)
                        .stroke(Color.gold, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: p)
                }
                .frame(width: 44, height: 44)
            } else {
                ProgressView().tint(Color.gold).scaleEffect(1.2)
            }
            VStack(spacing: 4) {
                Text(message)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundColor(.white)
                if let d = detail {
                    Text(d).font(.system(.caption, design: .monospaced)).foregroundColor(.gray)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Failed state view
private struct FailedStateView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .ultraLight))
                .foregroundColor(.gray)
            Text(message)
                .font(.system(.caption))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Button("再試行", action: onRetry)
                .font(.system(.caption, weight: .semibold))
                .foregroundColor(Color.gold)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.gold.opacity(0.4)))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }
}

// MARK: - Active lyric card
private struct ActiveLyricCard: View {
    let entry: BattleLyricEntry
    let onDeepDive: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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

            HStack(alignment: .top, spacing: 10) {
                Rectangle().fill(Color.gold).frame(width: 3).cornerRadius(2)
                Text(entry.lyric)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            // Claude: 意味・文脈
            Text(entry.explanation)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
                .lineSpacing(5)
                .padding(.horizontal, 14)

            // GPT-4o: 韻・技法（あれば）
            if let tech = entry.technique, !tech.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Text("韻")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundColor(Color(hex: "#0d0d0d"))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.gold)
                        .cornerRadius(4)
                    Text(tech)
                        .font(.system(size: 12))
                        .foregroundColor(Color.gold.opacity(0.8))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)
            }

            Spacer().frame(height: 14)
        }
        .background(Color(hex: "#141414"))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gold.opacity(0.25), lineWidth: 1))
        .shadow(color: Color.gold.opacity(0.06), radius: 12)
    }
}

// MARK: - Lyric row
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
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isActive ? Color.gold.opacity(0.2) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isActive)
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
            .overlay(Rectangle().fill(isSelected ? Color.gold : Color.clear).frame(height: 2), alignment: .bottom)
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
                    VStack(alignment: .leading, spacing: 8) {
                        Label("解析ライン", systemImage: "text.quote")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color.gold)
                        HStack(alignment: .top, spacing: 10) {
                            Rectangle().fill(Color.gold).frame(width: 3).cornerRadius(2)
                            Text(entry.lyric)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(14)
                    .cardStyle(padding: 0)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("ディープダイブ解析", systemImage: "sparkles")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.gold)
                            Spacer()
                            if isLoading { ProgressView().tint(Color.gold).scaleEffect(0.7) }
                        }
                        if text.isEmpty && isLoading {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(0..<4, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.white.opacity(0.06))
                                        .frame(maxWidth: .infinity).frame(height: 12)
                                }
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

// MARK: - Server settings sheet
struct ServerSettingsSheet: View {
    @State private var urlText = TranscriptionService.customServerURL
    @State private var anthropicKey = Configuration.anthropicAPIKey
    @State private var youtubeKey = Configuration.youtubeAPIKey
    @State private var openaiKey = Configuration.openAIAPIKey
    @State private var isChecking = false
    @State private var isDiscovering = false
    @State private var serverStatus: String? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    serverSection
                    apiKeysSection
                    startupGuideSection
                }
                .padding(20)
            }
            .background(Color.appBackground)
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }.foregroundColor(.gray)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { saveAll(); dismiss() }
                        .foregroundColor(Color.gold)
                        .fontWeight(.bold)
                }
            }
        }
    }

    // MARK: - Sections

    private var serverSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Macサーバー", systemImage: "server.rack")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundColor(Color.gold)

            // Auto-detect status
            HStack(spacing: 8) {
                let resolved = TranscriptionService.serverURL
                Circle()
                    .fill(resolved.isEmpty ? Color.red : Color.green)
                    .frame(width: 8, height: 8)
                if resolved.isEmpty {
                    Text("未接続 — Macでサーバーを起動してください")
                        .font(.system(.caption))
                        .foregroundColor(.gray)
                } else {
                    Text("自動検出: \(resolved)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.gray)
                }
                Spacer()
                Button {
                    Task {
                        isDiscovering = true
                        await TranscriptionService.autoDiscover()
                        isDiscovering = false
                    }
                } label: {
                    if isDiscovering {
                        ProgressView().tint(Color.gold).scaleEffect(0.7)
                    } else {
                        Text("再検出")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color.gold)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isDiscovering)
            }

            // Manual override URL
            VStack(alignment: .leading, spacing: 6) {
                Text("手動URL（任意）")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
                Text("空欄のままにすると自動検出を使用します")
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.6))
                HStack(spacing: 8) {
                    TextField("http://192.168.x.x:8765", text: $urlText)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .foregroundColor(.white)
                        .tint(Color.gold)
                        .padding(11)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gold.opacity(0.3), lineWidth: 1))
                    if !urlText.isEmpty {
                        Button { urlText = ""; serverStatus = nil } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Test button
                HStack {
                    if let s = serverStatus {
                        Label(s, systemImage: s.contains("✅") ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .font(.system(.caption, weight: .semibold))
                            .foregroundColor(s.contains("✅") ? .green : .red)
                    }
                    Spacer()
                    Button {
                        Task {
                            isChecking = true
                            serverStatus = nil
                            let testURL = urlText.isEmpty ? TranscriptionService.serverURL : urlText
                            guard !testURL.isEmpty else {
                                serverStatus = "❌ URLが未設定です"
                                isChecking = false
                                return
                            }
                            TranscriptionService.customServerURL = urlText
                            let ok = await TranscriptionService.checkHealth()
                            serverStatus = ok ? "✅ 接続成功！" : "❌ 接続できませんでした"
                            isChecking = false
                        }
                    } label: {
                        if isChecking {
                            ProgressView().tint(Color.gold).scaleEffect(0.8)
                        } else {
                            Text("接続テスト")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(Color.gold)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isChecking)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var apiKeysSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("APIキー", systemImage: "key.fill")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundColor(Color.gold)

            Text("キーを入力するとアプリに保存されます。Secrets.xcconfig でも設定可能です。")
                .font(.system(.caption))
                .foregroundColor(.gray)

            apiKeyField(label: "Anthropic (Claude)", placeholder: "sk-ant-...", text: $anthropicKey,
                        isSet: Configuration.isAnthropicConfigured)
            apiKeyField(label: "YouTube Data API v3", placeholder: "AIza...", text: $youtubeKey,
                        isSet: Configuration.isYouTubeConfigured)
            apiKeyField(label: "OpenAI (GPT)", placeholder: "sk-...", text: $openaiKey,
                        isSet: Configuration.isOpenAIConfigured)
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    @ViewBuilder
    private func apiKeyField(label: String, placeholder: String, text: Binding<String>, isSet: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Circle()
                    .fill(isSet ? Color.green : Color.red.opacity(0.7))
                    .frame(width: 7, height: 7)
                Text(isSet ? "設定済み" : "未設定")
                    .font(.system(size: 10))
                    .foregroundColor(isSet ? .green : .red.opacity(0.8))
            }
            SecureField(placeholder, text: text)
                .font(.system(.caption, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .foregroundColor(.white)
                .tint(Color.gold)
                .padding(10)
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(isSet ? Color.green.opacity(0.3) : Color.white.opacity(0.12), lineWidth: 1))
        }
    }

    private var startupGuideSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("サーバー起動方法", systemImage: "terminal.fill")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundColor(Color.gold)

            Text("Macのターミナルで以下を実行:")
                .font(.system(.caption))
                .foregroundColor(.gray)

            Text("cd ~/Rap/scripts\npip install -r requirements.txt\npython server.py")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(Color.gold)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black)
                .cornerRadius(8)

            Text("起動後、アプリが自動的にサーバーを検出します。\n実機使用時はMacと同じWi-Fiに接続してください。")
                .font(.system(.caption))
                .foregroundColor(.gray)
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Save

    private func saveAll() {
        TranscriptionService.customServerURL = urlText
        Configuration.anthropicAPIKey = anthropicKey
        Configuration.youtubeAPIKey = youtubeKey
        Configuration.openAIAPIKey = openaiKey
    }
}

private func formatTime(_ t: Double) -> String {
    String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
}

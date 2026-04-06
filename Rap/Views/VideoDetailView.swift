import SwiftUI

enum ExpertiseLevel: String, CaseIterable, Identifiable {
    case beginner = "初心者"
    case intermediate = "中級者"
    case expert = "上級者"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .beginner: return "person.fill.questionmark"
        case .intermediate: return "person.fill"
        case .expert: return "star.fill"
        }
    }
}

@Observable
class VideoDetailViewModel {
    let video: YouTubeVideo
    var expertiseLevel: ExpertiseLevel = .beginner
    var explanation: String?
    var isExplaining = false
    var toastMessage: String?
    var chatMessages: [ChatMessage] = []
    var chatInput = ""
    var isChatLoading = false
    var videoCurrentTime: Double = 0
    var showAISection = false
    var showChatSection = false
    var battleSyncVM: BattleSyncViewModel

    init(video: YouTubeVideo) {
        self.video = video
        self.battleSyncVM = BattleSyncViewModel(
            videoID: video.id, title: video.title, channel: video.channelTitle
        )
    }

    func explain() async {
        isExplaining = true
        explanation = nil
        do {
            explanation = try await AnthropicService.explainVideo(
                title: video.title, channel: video.channelTitle,
                description: video.description, level: expertiseLevel
            )
        } catch {
            toastMessage = (error as? AnthropicError)?.errorDescription ?? "接続を確認してください"
        }
        isExplaining = false
    }

    func sendChat() async {
        let trimmed = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        chatMessages.append(ChatMessage(role: "user", content: trimmed))
        chatInput = ""
        isChatLoading = true
        chatMessages.append(ChatMessage(role: "assistant", content: "", isLoading: true))
        let history = chatMessages.filter { !$0.isLoading }.map { ["role": $0.role, "content": $0.content] }
        do {
            var h = history
            if let exp = explanation, h.count == 1 {
                h.insert(["role": "assistant", "content": "【動画】\(video.title)\n\n【解説】\(exp)"], at: 0)
            }
            let resp = try await AnthropicService.videoChat(
                conversationHistory: h, videoTitle: video.title, level: expertiseLevel
            )
            if !chatMessages.isEmpty { chatMessages.removeLast() }
            chatMessages.append(ChatMessage(role: "assistant", content: resp))
        } catch {
            if !chatMessages.isEmpty { chatMessages.removeLast() }
            toastMessage = (error as? AnthropicError)?.errorDescription ?? "接続を確認してください"
        }
        isChatLoading = false
    }
}

// MARK: - Main View
struct VideoDetailView: View {
    @State private var vm: VideoDetailViewModel
    @State private var scrollProxy: ScrollViewProxy? = nil
    @FocusState private var chatFocused: Bool

    init(video: YouTubeVideo) {
        _vm = State(initialValue: VideoDetailViewModel(video: video))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0, pinnedViews: []) {
                        // ① Video player
                        videoSection

                        // ② Transcription status + lyric list
                        lyricSection
                            .padding(.top, 4)

                        // ③ AI解説 (expandable)
                        aiSection
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        // ④ Q&A (expandable)
                        qaSection
                            .padding(.horizontal, 16)
                            .padding(.top, 4)

                        Spacer().frame(height: 120) // space for mini player
                    }
                }
                .onAppear {
                    scrollProxy = proxy
                    vm.battleSyncVM.startAutoLoad()
                }
                .onChange(of: vm.battleSyncVM.currentEntry?.id) { _, id in
                    guard let id else { return }
                    withAnimation(.easeInOut(duration: 0.4)) {
                        proxy.scrollTo("lyric_\(id)", anchor: .center)
                    }
                }
            }

            // ⑤ Mini current lyric bar (always visible at bottom)
            if case .loaded = vm.battleSyncVM.loadState {
                MiniLyricBar(vm: vm.battleSyncVM)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color.appBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { vm.battleSyncVM.showServerSettings = true } label: {
                    Image(systemName: "server.rack")
                        .foregroundColor(TranscriptionService.isConfigured ? Color.gold : .gray)
                }
            }
        }
        .toast(message: $vm.toastMessage)
        .sheet(isPresented: $vm.battleSyncVM.showServerSettings) { ServerSettingsSheet() }
        .sheet(isPresented: $vm.battleSyncVM.showDeepDive) {
            if let entry = vm.battleSyncVM.selectedEntry {
                LyricDeepDiveSheet(
                    entry: entry, text: vm.battleSyncVM.deepDiveText,
                    isLoading: vm.battleSyncVM.isDeepDiving,
                    onClose: { vm.battleSyncVM.closeDeepDive() }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - ① Video section
    private var videoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            YouTubePlayerView(videoID: vm.video.id, onTimeUpdate: { t in
                vm.videoCurrentTime = t
                vm.battleSyncVM.updateTime(t)
            })
            .frame(height: UIScreen.main.bounds.width * 9 / 16)
            .background(Color.black)

            VStack(alignment: .leading, spacing: 3) {
                Text(vm.video.title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                HStack(spacing: 6) {
                    Text(vm.video.channelTitle)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(Color.gold)
                    if !vm.video.formattedDate.isEmpty {
                        Text("· \(vm.video.formattedDate)")
                            .font(.system(.caption))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    // Source badge
                    if case .loaded = vm.battleSyncVM.loadState {
                        Text(vm.battleSyncVM.lyricSource.rawValue)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(vm.battleSyncVM.lyricSource == .server ? .black : .gray)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(vm.battleSyncVM.lyricSource == .server ? Color.gold : Color.white.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 8)
        }
    }

    // MARK: - ② Lyric section
    @ViewBuilder
    private var lyricSection: some View {
        switch vm.battleSyncVM.loadState {
        case .idle:
            Color.clear.frame(height: 1).onAppear { vm.battleSyncVM.startAutoLoad() }

        case .loading(let msg):
            LyricLoadingView(message: msg, progress: nil)
                .padding(.horizontal, 16).padding(.vertical, 24)

        case .loadingProgress(let done, let total):
            LyricLoadingView(
                message: "AIが解析中...",
                progress: total > 0 ? Double(done) / Double(total) : nil,
                detail: "\(done) / \(total) ライン"
            )
            .padding(.horizontal, 16).padding(.vertical, 24)

        case .loaded:
            LazyVStack(spacing: 0) {
                ForEach(vm.battleSyncVM.entries) { entry in
                    LyricEntryRow(
                        entry: entry,
                        isActive: entry.id == vm.battleSyncVM.currentEntry?.id,
                        onDeepDive: { vm.battleSyncVM.startDeepDive(for: entry) }
                    )
                    .id("lyric_\(entry.id)")
                }
            }

        case .failed(let msg):
            VStack(spacing: 12) {
                Text(msg).font(.system(.caption)).foregroundColor(.gray)
                Button("再試行") { vm.battleSyncVM.retry() }
                    .font(.system(.caption, weight: .semibold)).foregroundColor(Color.gold)
            }
            .frame(maxWidth: .infinity).padding(32)
        }
    }

    // MARK: - ③ AI解説 section
    private var aiSection: some View {
        VStack(spacing: 0) {
            // Header toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { vm.showAISection.toggle() }
                if vm.showAISection && vm.explanation == nil && !vm.isExplaining {
                    Task { await vm.explain() }
                }
            } label: {
                HStack {
                    Label("AI解説", systemImage: "wand.and.stars")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: vm.showAISection ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .padding(14)
                .background(Color(hex: "#141414"))
                .cornerRadius(vm.showAISection ? 0 : 12)
                .overlay(RoundedRectangle(cornerRadius: vm.showAISection ? 0 : 12).stroke(Color.divider, lineWidth: 1))
            }
            .buttonStyle(.plain)

            if vm.showAISection {
                VStack(alignment: .leading, spacing: 12) {
                    // Level picker
                    HStack(spacing: 6) {
                        ForEach(ExpertiseLevel.allCases) { level in
                            Button {
                                vm.expertiseLevel = level
                                vm.explanation = nil
                                Task { await vm.explain() }
                            } label: {
                                Text(level.rawValue)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(vm.expertiseLevel == level ? .black : .gray)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(vm.expertiseLevel == level ? Color.gold : Color.white.opacity(0.06))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if vm.isExplaining {
                        HStack(spacing: 8) {
                            ProgressView().tint(Color.gold).scaleEffect(0.8)
                            Text("解説を生成中...").font(.system(.caption)).foregroundColor(.gray)
                        }
                    }
                    if let exp = vm.explanation {
                        Text(exp)
                            .font(.system(.body))
                            .foregroundColor(.white.opacity(0.85))
                            .lineSpacing(6)
                            .textSelection(.enabled)
                    }
                }
                .padding(14)
                .background(Color(hex: "#141414"))
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color.divider, lineWidth: 1)
                        .padding(.top, -1)
                )
                .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - ④ Q&A section
    private var qaSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { vm.showChatSection.toggle() }
            } label: {
                HStack {
                    Label("Q&A", systemImage: "bubble.left.and.bubble.right")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: vm.showChatSection ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12)).foregroundColor(.gray)
                }
                .padding(14)
                .background(Color(hex: "#141414"))
                .cornerRadius(vm.showChatSection ? 0 : 12)
                .overlay(RoundedRectangle(cornerRadius: vm.showChatSection ? 0 : 12).stroke(Color.divider, lineWidth: 1))
            }
            .buttonStyle(.plain)

            if vm.showChatSection {
                VStack(spacing: 10) {
                    if vm.chatMessages.isEmpty {
                        let suggestions = ["このバトルのベストバースは？", "韻の技法を教えて", "どっちが勝ったと思う？", "一番のパンチラインは？"]
                        FlowLayout(spacing: 8) {
                            ForEach(suggestions, id: \.self) { s in
                                Button(s) { vm.chatInput = s; chatFocused = true }
                                    .font(.system(size: 12)).foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 10).padding(.vertical, 7).cardStyle()
                            }
                        }
                    }
                    ForEach(vm.chatMessages) { msg in MessageBubble(message: msg) }
                    HStack(spacing: 10) {
                        TextField("質問する...", text: $vm.chatInput, axis: .vertical)
                            .font(.system(.body)).foregroundColor(.white)
                            .tint(Color.gold).lineLimit(1...4).focused($chatFocused)
                        Button { Task { await vm.sendChat() } } label: {
                            if vm.isChatLoading {
                                ProgressView().tint(Color.gold).scaleEffect(0.85).frame(width: 30, height: 30)
                            } else {
                                Image(systemName: "arrow.up.circle.fill").font(.system(size: 28))
                                    .foregroundColor(vm.chatInput.isEmpty ? .gray.opacity(0.3) : Color.gold)
                            }
                        }
                        .disabled(vm.chatInput.isEmpty || vm.isChatLoading)
                    }
                    .padding(12).cardStyle()
                }
                .padding(14)
                .background(Color(hex: "#141414"))
                .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Lyric entry row (full detail)
struct LyricEntryRow: View {
    let entry: BattleLyricEntry
    let isActive: Bool
    let onDeepDive: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Time + active indicator
                VStack(spacing: 4) {
                    Circle()
                        .fill(isActive ? Color.gold : Color.white.opacity(0.08))
                        .frame(width: 8, height: 8)
                        .scaleEffect(isActive ? 1.3 : 1)
                        .animation(.easeInOut(duration: 0.2), value: isActive)
                    Text(formatTime(entry.start))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(isActive ? Color.gold : .gray)
                }
                .frame(width: 38, alignment: .center)
                .padding(.top, 4)

                VStack(alignment: .leading, spacing: 6) {
                    // Lyric text
                    Text(entry.lyric)
                        .font(.system(size: isActive ? 16 : 14, weight: isActive ? .bold : .regular))
                        .foregroundColor(isActive ? .white : .white.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)

                    // Explanation (always visible when active)
                    if isActive {
                        Text(entry.explanation)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)

                        // Technique badge (GPT-4o)
                        if let tech = entry.technique, !tech.isEmpty {
                            HStack(alignment: .top, spacing: 6) {
                                Text("韻")
                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(Color.gold).cornerRadius(3)
                                Text(tech)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.gold.opacity(0.8))
                                    .lineSpacing(3)
                            }
                        }

                        // Deep dive button
                        Button(action: onDeepDive) {
                            Label("詳しく解析", systemImage: "sparkles")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color.gold).cornerRadius(20)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(isActive ? Color.gold.opacity(0.04) : Color.clear)
            .overlay(
                Rectangle()
                    .fill(isActive ? Color.gold : Color.clear)
                    .frame(width: 3),
                alignment: .leading
            )

            Divider().background(Color.white.opacity(0.04))
        }
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

// MARK: - Mini lyric bar (bottom overlay)
struct MiniLyricBar: View {
    @Bindable var vm: BattleSyncViewModel

    var body: some View {
        Group {
            if let entry = vm.currentEntry {
                HStack(spacing: 12) {
                    Rectangle().fill(Color.gold).frame(width: 3, height: 36).cornerRadius(2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.lyric)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(entry.explanation)
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button { vm.startDeepDive(for: entry) } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16))
                            .foregroundColor(Color.gold)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial.opacity(0.97))
                .background(Color(hex: "#0A0A0A").opacity(0.85))
                .overlay(Divider().background(Color.gold.opacity(0.2)), alignment: .top)
                .id(entry.id)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
            } else {
                EmptyView()
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: vm.currentEntry?.id)
    }
}

// MARK: - Loading view
struct LyricLoadingView: View {
    let message: String
    let progress: Double?
    var detail: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            if let p = progress {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.07), lineWidth: 2.5)
                    Circle().trim(from: 0, to: p)
                        .stroke(Color.gold, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: p)
                }
                .frame(width: 32, height: 32)
            } else {
                ProgressView().tint(Color.gold).scaleEffect(0.9)
                    .frame(width: 32, height: 32)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(message).font(.system(.subheadline, weight: .semibold)).foregroundColor(.white)
                if let d = detail {
                    Text(d).font(.system(.caption, design: .monospaced)).foregroundColor(.gray)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(Color(hex: "#141414"))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.divider))
    }
}

// MARK: - Corner radius helper
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = 8
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
                                cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - ExplanationCard (kept for compatibility)
struct ExplanationCard: View {
    let text: String
    let level: ExpertiseLevel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text)
                .font(.system(.body)).foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true).lineSpacing(6).textSelection(.enabled)
        }
        .padding(16).cardStyle()
    }
}

struct ExpertiseLevelButton: View {
    let level: ExpertiseLevel; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(level.rawValue).font(.system(size: 11, weight: .semibold))
                .foregroundColor(isSelected ? Color(hex: "#0d0d0d") : .gray)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(isSelected ? Color.gold : Color(hex: "#1a1a1a"))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

private func formatTime(_ t: Double) -> String {
    String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
}

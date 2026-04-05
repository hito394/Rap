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

    var description: String {
        switch self {
        case .beginner: return "ヒップホップは初めて"
        case .intermediate: return "基本は知ってる"
        case .expert: return "深く掘り下げて"
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
    var selectedTab = 0

    init(video: YouTubeVideo) {
        self.video = video
    }

    func explain() async {
        isExplaining = true
        explanation = nil

        do {
            explanation = try await AnthropicService.explainVideo(
                title: video.title,
                channel: video.channelTitle,
                description: video.description,
                level: expertiseLevel
            )
        } catch {
            toastMessage = (error as? AnthropicError)?.errorDescription ?? "接続を確認してください"
        }

        isExplaining = false
    }

    func sendChat() async {
        let trimmed = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let userMsg = ChatMessage(role: "user", content: trimmed)
        chatMessages.append(userMsg)
        chatInput = ""
        isChatLoading = true

        let loadingMsg = ChatMessage(role: "assistant", content: "", isLoading: true)
        chatMessages.append(loadingMsg)

        // Build history including explanation context as system message is in service
        let history = chatMessages.filter { !$0.isLoading }.map { ["role": $0.role, "content": $0.content] }

        do {
            // Context-aware chat: includes video info in first message context
            let contextualHistory = buildContextualHistory(rawHistory: history)
            let response = try await AnthropicService.videoChat(
                conversationHistory: contextualHistory,
                videoTitle: video.title,
                level: expertiseLevel
            )
            if !chatMessages.isEmpty { chatMessages.removeLast() }
            chatMessages.append(ChatMessage(role: "assistant", content: response))
        } catch {
            if !chatMessages.isEmpty { chatMessages.removeLast() }
            toastMessage = (error as? AnthropicError)?.errorDescription ?? "接続を確認してください"
        }

        isChatLoading = false
    }

    private func buildContextualHistory(rawHistory: [[String: Any]]) -> [[String: Any]] {
        // Prepend video context + explanation as assistant's first message if available
        var history = rawHistory
        if let exp = explanation, history.count == 1 {
            // Insert context as the first assistant message
            let context: [String: Any] = [
                "role": "assistant",
                "content": "【動画情報】\nタイトル: \(video.title)\nチャンネル: \(video.channelTitle)\n\n【解説】\n\(exp)"
            ]
            history.insert(context, at: 0)
        }
        return history
    }
}

// MARK: - Main View
struct VideoDetailView: View {
    @State private var vm: VideoDetailViewModel
    @FocusState private var chatFocused: Bool
    private let scrollID = "chatBottom"

    init(video: YouTubeVideo) {
        _vm = State(initialValue: VideoDetailViewModel(video: video))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // YouTube player
                playerSection

                // Expertise picker
                expertisePicker
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                // Tabs
                let tabs = ["解説", "Q&A"]
                SegmentControl(tabs: tabs, selected: $vm.selectedTab)
                Divider().background(Color.divider)

                Group {
                    switch vm.selectedTab {
                    case 0: explanationTab
                    case 1: chatTab
                    default: explanationTab
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)

                Spacer().frame(height: 40)
            }
        }
        .background(Color.appBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toast(message: $vm.toastMessage)
    }

    // MARK: Player
    private var playerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            YouTubePlayerView(videoID: vm.video.id)
                .frame(height: UIScreen.main.bounds.width * 9 / 16)
                .background(Color.black)

            VStack(alignment: .leading, spacing: 4) {
                Text(vm.video.title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Text(vm.video.channelTitle)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(Color.gold)
                    if !vm.video.formattedDate.isEmpty {
                        Text("· \(vm.video.formattedDate)")
                            .font(.system(.caption))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)
        }
    }

    // MARK: Expertise picker
    private var expertisePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "解説レベル")
            HStack(spacing: 8) {
                ForEach(ExpertiseLevel.allCases) { level in
                    ExpertiseLevelButton(
                        level: level,
                        isSelected: vm.expertiseLevel == level
                    ) {
                        vm.expertiseLevel = level
                        if vm.explanation != nil {
                            vm.explanation = nil
                        }
                    }
                }
            }
        }
    }

    // MARK: Explanation tab
    @ViewBuilder
    private var explanationTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            if vm.explanation == nil && !vm.isExplaining {
                // CTA
                VStack(spacing: 16) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundColor(Color.gold.opacity(0.6))
                    Text("AIがこの動画を解説します")
                        .font(.system(.subheadline))
                        .foregroundColor(.gray)
                    Button("解説を生成する") {
                        Task { await vm.explain() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: 240)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }

            if vm.isExplaining {
                VStack(spacing: 12) {
                    AnalyzingIndicator()
                    LoadingView()
                }
            }

            if let exp = vm.explanation {
                ExplanationCard(text: exp, level: vm.expertiseLevel)

                // Suggest going to Q&A
                Button {
                    vm.selectedTab = 1
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 13))
                        Text("さらに詳しく質問する")
                            .font(.system(.subheadline, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "#0d0d0d"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.gold)
                    .cornerRadius(4)
                }
            }
        }
    }

    // MARK: Chat tab
    @ViewBuilder
    private var chatTab: some View {
        VStack(spacing: 12) {
            if vm.explanation == nil {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(Color.gold)
                        .font(.system(size: 13))
                    Text("先に「解説」タブでAI解説を生成すると、より精度の高いQ&Aができます")
                        .font(.system(.caption))
                        .foregroundColor(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color.gold.opacity(0.06))
                .cornerRadius(6)
            }

            // Suggestion chips
            if vm.chatMessages.isEmpty {
                chatSuggestions
            }

            // Messages
            ScrollViewReader { proxy in
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(vm.chatMessages) { msg in
                        MessageBubble(message: msg)
                    }
                    Color.clear.frame(height: 1).id(scrollID)
                }
                .onChange(of: vm.chatMessages.count) { _, _ in
                    withAnimation { proxy.scrollTo(scrollID, anchor: .bottom) }
                }
            }

            // Input
            HStack(spacing: 10) {
                TextField("質問する...", text: $vm.chatInput, axis: .vertical)
                    .font(.system(.body))
                    .foregroundColor(.white)
                    .tint(Color.gold)
                    .lineLimit(1...4)
                    .focused($chatFocused)

                Button {
                    Task { await vm.sendChat() }
                } label: {
                    if vm.isChatLoading {
                        ProgressView().tint(Color.gold).scaleEffect(0.85)
                            .frame(width: 30, height: 30)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(vm.chatInput.isEmpty ? .gray.opacity(0.3) : Color.gold)
                    }
                }
                .disabled(vm.chatInput.isEmpty || vm.isChatLoading)
            }
            .padding(12)
            .cardStyle()
        }
    }

    // MARK: Chat suggestions
    private var chatSuggestions: some View {
        let suggestions = buildSuggestions()
        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "こんな質問はどう？")
            FlowLayout(spacing: 8) {
                ForEach(suggestions, id: \.self) { s in
                    Button(s) {
                        vm.chatInput = s
                        chatFocused = true
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .cardStyle()
                }
            }
        }
    }

    private func buildSuggestions() -> [String] {
        switch vm.expertiseLevel {
        case .beginner:
            return [
                "MCバトルって何ですか？",
                "この動画は何が凄いんですか？",
                "フリースタイルとは何ですか？",
                "どうやって勝ち負けが決まりますか？",
                "なぜ人は感動するんですか？",
            ]
        case .intermediate:
            return [
                "このバトルのベストバースはどこ？",
                "使われているライム技法は？",
                "この選手の強みは何？",
                "歴史的にどんな意味がある？",
            ]
        case .expert:
            return [
                "最も高度なリリシズムの箇所は？",
                "他の伝説的バトルとの比較は？",
                "このバトルが後世に与えた影響は？",
                "フロウの構造を詳しく分析して",
            ]
        }
    }
}

// MARK: - Explanation card
struct ExplanationCard: View {
    let text: String
    let level: ExpertiseLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: level.icon)
                    .font(.system(size: 11)).foregroundColor(Color.gold)
                SectionHeader(title: "\(level.rawValue)向け解説")
            }
            Text(text)
                .font(.system(.body))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(6)
                .textSelection(.enabled)
        }
        .padding(16)
        .cardStyle()
    }
}

// MARK: - Expertise level button
struct ExpertiseLevelButton: View {
    let level: ExpertiseLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: level.icon)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? Color(hex: "#0d0d0d") : .gray)
                Text(level.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isSelected ? Color(hex: "#0d0d0d") : .gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.gold : Color(hex: "#1a1a1a"))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.clear : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

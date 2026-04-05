import SwiftUI
import SwiftData

// MARK: - ViewModel
@Observable
class BattlePracticeViewModel {
    var inputText = ""
    var messages: [ChatMessage] = []
    var isLoading = false
    var toastMessage: String?
    var style: BattleStyle = .jpHipHop
    var difficulty: BattleDifficulty = .easy
    var roundCount = 0

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    var conversationHistory: [[String: Any]] {
        messages.filter { !$0.isLoading }.map { ["role": $0.role, "content": $0.content] }
    }

    func send() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if messages.count >= 20 { messages.removeFirst(2) }

        messages.append(ChatMessage(role: "user", content: trimmed))
        inputText = ""
        isLoading = true
        roundCount += 1

        let loading = ChatMessage(role: "assistant", content: "", isLoading: true)
        messages.append(loading)

        do {
            let history = messages.filter { !$0.isLoading }
                .map { ["role": $0.role, "content": $0.content] }
            let response = try await AnthropicService.battlePractice(
                conversationHistory: history,
                style: style,
                difficulty: difficulty
            )
            if !messages.isEmpty { messages.removeLast() }
            messages.append(ChatMessage(role: "assistant", content: response))
        } catch {
            if !messages.isEmpty { messages.removeLast() }
            toastMessage = (error as? AnthropicError)?.errorDescription ?? "接続を確認してください"
        }
        isLoading = false
    }

    func reset() {
        messages = []
        inputText = ""
        roundCount = 0
    }
}

// MARK: - Main View
struct BattlePracticeView: View {
    @State private var vm = BattlePracticeViewModel()
    @FocusState private var inputFocused: Bool
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Settings bar
                settingsBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.cardBackground)

                Divider().background(Color.divider)

                if vm.messages.isEmpty {
                    emptyState
                } else {
                    // Battle messages
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 12) {
                                ForEach(vm.messages) { msg in
                                    BattleMessageBubble(message: msg)
                                        .id(msg.id)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .onChange(of: vm.messages.count) { _, _ in
                            withAnimation {
                                proxy.scrollTo(vm.messages.last?.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Spacer(minLength: 0)

                // Input bar
                inputBar
            }
            .background(Color.appBackground)
            .navigationTitle("バトル練習")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !vm.messages.isEmpty {
                        Button("リセット") { vm.reset() }
                            .font(.system(size: 13)).foregroundColor(.gray)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if vm.roundCount > 0 {
                        Text("Round \(vm.roundCount)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color.gold)
                    }
                }
            }
        }
        .toast(message: $vm.toastMessage)
    }

    // MARK: Settings bar
    private var settingsBar: some View {
        HStack(spacing: 10) {
            // Style picker
            Menu {
                ForEach(BattleStyle.allCases) { s in
                    Button {
                        vm.style = s
                        vm.reset()
                    } label: {
                        Label("\(s.icon) \(s.rawValue)", systemImage: "")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(vm.style.icon)
                    Text(vm.style.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9)).foregroundColor(.gray)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.white.opacity(0.08)).cornerRadius(6)
            }

            // Difficulty picker
            Menu {
                ForEach(BattleDifficulty.allCases) { d in
                    Button {
                        vm.difficulty = d
                        vm.reset()
                    } label: {
                        Label("\(d.icon) \(d.rawValue)", systemImage: "")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(vm.difficulty.icon)
                    Text(vm.difficulty.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9)).foregroundColor(.gray)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.white.opacity(0.08)).cornerRadius(6)
            }

            Spacer()

            Text("AIバトル相手")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.gray)
        }
    }

    // MARK: Empty state
    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("🎤")
                .font(.system(size: 60))

            VStack(spacing: 8) {
                Text("AIとバトル練習")
                    .font(.system(.title2, weight: .bold))
                    .foregroundColor(.white)
                Text("あなたのバース（ライン）を入力すると\nAIが応戦します。韻・フロウ・パンチラインを\n磨いて腕を上げよう。")
                    .font(.system(.subheadline))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // Starter prompts
            VStack(spacing: 8) {
                Text("こんな感じで始めよう")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
                ForEach(starterLines, id: \.self) { line in
                    Button {
                        vm.inputText = line
                        inputFocused = true
                    } label: {
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(Color.gold.opacity(0.9))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Color.gold.opacity(0.08)).cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gold.opacity(0.2), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private let starterLines = [
        "俺のライムは切れ味バツグン / お前の韻はただのダジャレ水準",
        "川崎の夜風が俺を鍛えた / お前みたいな軟派には負けた覚えない",
        "言葉の弾丸装填完了 / 撃ち込む先はお前のプライドの城",
    ]

    // MARK: Input bar
    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color.divider)
            HStack(alignment: .bottom, spacing: 10) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $vm.inputText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(minHeight: 40, maxHeight: 120)
                        .focused($inputFocused)
                    if vm.inputText.isEmpty {
                        Text("バースを入力...")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.4))
                            .padding(.top, 8).padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                }
                .padding(10)
                .background(Color.cardBackground)
                .cornerRadius(8)

                Button {
                    inputFocused = false
                    Task { await vm.send() }
                } label: {
                    if vm.isLoading {
                        ProgressView().tint(Color(hex: "#0d0d0d")).scaleEffect(0.8)
                            .frame(width: 40, height: 40)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 34))
                            .foregroundColor(vm.canSend ? Color.gold : .gray.opacity(0.3))
                    }
                }
                .disabled(!vm.canSend)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.appBackground)
        }
    }
}

// MARK: - Battle message bubble
struct BattleMessageBubble: View {
    let message: ChatMessage
    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                // Role label
                HStack(spacing: 4) {
                    if !isUser {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 9)).foregroundColor(Color.gold)
                        Text("AI").font(.system(size: 9, design: .monospaced)).foregroundColor(Color.gold)
                    } else {
                        Text("YOU").font(.system(size: 9, design: .monospaced)).foregroundColor(.gray)
                        Image(systemName: "person.fill")
                            .font(.system(size: 9)).foregroundColor(.gray)
                    }
                }

                if message.isLoading {
                    // Loading dots
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(Color.gold)
                                .frame(width: 6, height: 6)
                                .opacity(0.6)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Color.cardBackground).cornerRadius(12)
                } else {
                    // Parse user bars vs AI bars+feedback
                    if isUser {
                        Text(message.content)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(Color(hex: "#1a2a1a")).cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                    } else {
                        AIBattleCard(content: message.content)
                    }
                }
            }

            if !isUser { Spacer(minLength: 40) }
        }
    }
}

// MARK: - AI battle card (parses bars + feedback)
struct AIBattleCard: View {
    let content: String

    private var parts: (bars: String, feedback: String) {
        // Split on "---"
        let components = content.components(separatedBy: "---")
        let bars = components.first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? content
        let feedback = components.dropFirst().joined(separator: "---")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (bars, feedback)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Bars section
            Text(parts.bars)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
                .padding(.horizontal, 14).padding(.top, 12)
                .padding(.bottom, parts.feedback.isEmpty ? 12 : 10)

            // Feedback section
            if !parts.feedback.isEmpty {
                Divider().background(Color.gold.opacity(0.2)).padding(.horizontal, 10)
                Text(parts.feedback)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
                    .padding(.horizontal, 14).padding(.vertical, 10)
            }
        }
        .background(Color(hex: "#1a1400"))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(Color.gold.opacity(0.2), lineWidth: 0.5))
    }
}

import SwiftUI
import SwiftData

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String   // "user" | "assistant"
    let content: String
    var isLoading: Bool = false
}

@Observable
class FreeSearchViewModel {
    var inputText = ""
    var messages: [ChatMessage] = []
    var isLoading = false
    var toastMessage: String?

    private let maxTurns = 10

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    var conversationHistory: [[String: Any]] {
        messages.filter { !$0.isLoading }.map { ["role": $0.role, "content": $0.content] }
    }

    func send(saveHistory: (HistoryItem) -> Void) async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Trim old messages if over maxTurns (each turn = user + assistant = 2 messages)
        if messages.count >= maxTurns * 2 {
            messages.removeFirst(2)
        }

        let userMsg = ChatMessage(role: "user", content: trimmed)
        messages.append(userMsg)
        inputText = ""
        isLoading = true

        // Add placeholder loading bubble
        let loadingMsg = ChatMessage(role: "assistant", content: "", isLoading: true)
        messages.append(loadingMsg)

        do {
            let history = messages.filter { !$0.isLoading }.map { ["role": $0.role, "content": $0.content] }
            let response = try await AnthropicService.freeSearch(conversationHistory: history)

            // Replace loading bubble
            if !messages.isEmpty { messages.removeLast() }
            let assistantMsg = ChatMessage(role: "assistant", content: response)
            messages.append(assistantMsg)

            let item = HistoryItem(type: "search", query: trimmed, resultJSON: response)
            saveHistory(item)
        } catch {
            if !messages.isEmpty { messages.removeLast() }
            toastMessage = (error as? AnthropicError)?.errorDescription ?? "接続を確認してください"
        }

        isLoading = false
    }

    func clearHistory() {
        messages.removeAll()
    }
}

// MARK: - Suggestion chips
private let suggestions = [
    "ドレイクとケンドリックのビーフ",
    "フリースタイルとは何か",
    "ブーンバップとは",
    "イーストコースト vs ウェストコースト",
    "サンプリングの仕組み",
    "ラップのライム技法まとめ",
]

// MARK: - Main View
struct FreeSearchView: View {
    @State private var vm = FreeSearchViewModel()
    @Environment(\.modelContext) private var context
    @FocusState private var inputFocused: Bool

    // Pre-seeded question from DiscoverView beginner guide
    var preseededQuestion: String? = nil
    private let scrollID = "bottom"

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            if vm.messages.isEmpty {
                                emptyState
                            } else {
                                LazyVStack(alignment: .leading, spacing: 12) {
                                    ForEach(vm.messages) { msg in
                                        MessageBubble(message: msg)
                                    }
                                    Color.clear.frame(height: 1).id(scrollID)
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                            }
                        }
                    }
                    .onChange(of: vm.messages.count) { _, _ in
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(scrollID, anchor: .bottom)
                        }
                    }
                }

                inputBar
            }
            .background(Color.appBackground)
            .navigationTitle("FREE SEARCH")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if !vm.messages.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("クリア") { vm.clearHistory() }
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .toast(message: $vm.toastMessage)
        .onAppear {
            if let q = preseededQuestion, vm.messages.isEmpty {
                vm.inputText = q
                Task { await vm.send { context.insert($0) } }
            }
        }
    }

    // MARK: Empty state with suggestions
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)
            VStack(spacing: 6) {
                Text("🎤")
                    .font(.system(size: 48))
                Text("何でも聞いてくれ")
                    .font(.system(.title3, weight: .bold))
                    .foregroundColor(.white)
                Text("ヒップホップのことなら何でも")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.gray)
            }
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "例えばこんな質問")
                    .padding(.horizontal, 16)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { s in
                            Button(s) {
                                vm.inputText = s
                                inputFocused = true
                            }
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .cardStyle()
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            Spacer()
        }
    }

    // MARK: Input bar
    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color.divider)
            HStack(spacing: 10) {
                TextField("質問する...", text: $vm.inputText, axis: .vertical)
                    .font(.system(.body))
                    .foregroundColor(.white)
                    .tint(Color.gold)
                    .lineLimit(1...5)
                    .focused($inputFocused)
                    .onSubmit {
                        if vm.canSend {
                            Task { await vm.send { context.insert($0) } }
                        }
                    }

                Button {
                    Task { await vm.send { context.insert($0) } }
                } label: {
                    if vm.isLoading {
                        ProgressView()
                            .tint(Color.gold)
                            .scaleEffect(0.85)
                            .frame(width: 34, height: 34)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(vm.canSend ? Color.gold : .gray.opacity(0.4))
                    }
                }
                .disabled(!vm.canSend)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.cardBackground)
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: ChatMessage

    var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 40) }

            if message.isLoading {
                TypingIndicator()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.cardBackground)
                    .cornerRadius(12)
                    .cornerRadius(4, corners: .bottomLeft)
            } else {
                Text(message.content)
                    .font(isUser ? .system(.body) : .system(.body))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isUser ? Color.gold.opacity(0.2) : Color.cardBackground)
                    .cornerRadius(12)
                    .cornerRadius(isUser ? 4 : 4, corners: isUser ? .bottomRight : .bottomLeft)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isUser ? Color.gold.opacity(0.3) : Color.white.opacity(0.05), lineWidth: 0.5)
                    )
                    .textSelection(.enabled)
            }

            if !isUser { Spacer(minLength: 40) }
        }
    }
}

struct TypingIndicator: View {
    @State private var phase = 0

    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.gold.opacity(phase == i ? 1 : 0.3))
                    .frame(width: 6, height: 6)
                    .animation(.easeInOut(duration: 0.3), value: phase)
            }
        }
        .onReceive(timer) { _ in
            phase = (phase + 1) % 3
        }
    }
}

// RoundedCorner / cornerRadius(_:corners:) is defined in DesignSystem.swift

import SwiftUI
import SwiftData

@Observable
class LyricsAnalyzeViewModel {
    var lyricsText = ""
    var isLoading = false
    var result: LyricsAnalysis?
    var rawResult: String?
    var toastMessage: String?

    var charCount: Int { lyricsText.count }
    var maxChars: Int { 500 }
    var canAnalyze: Bool { !lyricsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading }

    func analyze(saveHistory: (HistoryItem) -> Void) async {
        guard canAnalyze else { return }
        isLoading = true
        result = nil
        rawResult = nil

        do {
            let raw = try await AnthropicService.analyzeLyrics(lyricsText)
            rawResult = raw
            result = LyricsAnalysis.parse(from: raw)
            let item = HistoryItem(type: "lyrics", query: lyricsText, resultJSON: raw)
            saveHistory(item)
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

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    inputSection
                    if vm.isLoading { loadingSection }
                    if let result = vm.result { resultSection(result) }
                    else if let raw = vm.rawResult, vm.result == nil && !vm.isLoading {
                        rawTextSection(raw)
                    }
                }
                .padding(16)
            }
            .background(Color.appBackground)
            .navigationTitle("LYRICS ANALYZE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .toast(message: $vm.toastMessage)
    }

    // MARK: Input Section
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "歌詞を入力")
            ZStack(alignment: .topLeading) {
                TextEditor(text: $vm.lyricsText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 140, maxHeight: 200)
                    .onChange(of: vm.lyricsText) { _, new in
                        if new.count > vm.maxChars {
                            vm.lyricsText = String(new.prefix(vm.maxChars))
                        }
                    }
                if vm.lyricsText.isEmpty {
                    Text("ここに歌詞を貼り付け...")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.4))
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
            }
            .padding(12)
            .cardStyle()

            HStack {
                Text("\(vm.charCount) / \(vm.maxChars)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(vm.charCount > vm.maxChars - 50 ? Color.gold : .gray)
                Spacer()
                if !vm.lyricsText.isEmpty {
                    Button("クリア") { vm.lyricsText = ""; vm.result = nil; vm.rawResult = nil }
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }

            Button("解析する") {
                Task { await vm.analyze { context.insert($0) } }
            }
            .buttonStyle(PrimaryButtonStyle(isLoading: vm.isLoading))
            .disabled(!vm.canAnalyze)
        }
    }

    // MARK: Loading
    private var loadingSection: some View {
        VStack(spacing: 12) {
            HStack { AnalyzingIndicator(); Spacer() }
            LoadingView()
        }
    }

    // MARK: Result
    @ViewBuilder
    private func resultSection(_ r: LyricsAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider().background(Color.divider)

            // Flow Score
            HStack(alignment: .top, spacing: 14) {
                ScoreRing(score: r.flowScore)
                VStack(alignment: .leading, spacing: 4) {
                    SectionHeader(title: "Flow Score")
                    Text(r.flowComment)
                        .font(.system(.subheadline))
                        .foregroundColor(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .cardStyle()

            // Rhyme Types
            if !r.rhymeTypes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Rhyme Techniques")
                    FlowLayout(spacing: 6) {
                        ForEach(r.rhymeTypes, id: \.self) { tag in
                            GoldTag(text: tag)
                        }
                    }
                }
                .padding(14)
                .cardStyle()
            }

            // Rhyme Pairs
            if !r.rhymePairs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Rhyme Pairs")
                    ForEach(r.rhymePairs) { pair in
                        RhymePairRow(pair: pair)
                    }
                }
                .padding(14)
                .cardStyle()
            }

            // Highlights
            InfoCard(title: "Highlights", body: r.highlights, icon: "sparkles")

            // Tips
            InfoCard(title: "Advice", body: r.tips, icon: "lightbulb.fill")
        }
    }

    // MARK: Raw text fallback
    private func rawTextSection(_ raw: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Result")
            Text(raw)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
                .padding(14)
                .cardStyle()
        }
    }
}

// MARK: - Sub-components

struct RhymePairRow: View {
    let pair: RhymePair
    var body: some View {
        HStack(spacing: 6) {
            Text(pair.word1)
                .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                .foregroundColor(.white)
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 10))
                .foregroundColor(Color.gold)
            Text(pair.word2)
                .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            GoldTag(text: pair.type)
        }
        .padding(.vertical, 4)
    }
}

struct InfoCard: View {
    let title: String
    let body: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(Color.gold)
                SectionHeader(title: title)
            }
            Text(body)
                .font(.system(.subheadline))
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .padding(14)
        .cardStyle()
    }
}

// MARK: - FlowLayout (wrapping HStack)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map { $0.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0 }
            .reduce(0) { $0 + $1 + spacing } - spacing
        return CGSize(width: proposal.width ?? 0, height: max(0, height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            var x = bounds.minX
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        let width = proposal.width ?? .infinity
        var rows: [[LayoutSubview]] = [[]]
        var currentX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width && !rows.last!.isEmpty {
                rows.append([subview])
                currentX = size.width + spacing
            } else {
                rows[rows.count - 1].append(subview)
                currentX += size.width + spacing
            }
        }
        return rows
    }
}

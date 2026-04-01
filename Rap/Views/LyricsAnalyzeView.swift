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
                    if let result = vm.result {
                        resultSection(result)
                    } else if let raw = vm.rawResult, vm.result == nil && !vm.isLoading {
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
                    Button("クリア") {
                        vm.lyricsText = ""; vm.result = nil; vm.rawResult = nil
                    }
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

            // Slang Glossary
            if !r.slangGlossary.isEmpty {
                SlangGlossarySection(entries: r.slangGlossary)
            }

            // Double Entendres
            if !r.doubleEntendres.isEmpty {
                DoubleEntendresSection(items: r.doubleEntendres)
            }

            // Cultural References
            if !r.culturalReferences.isEmpty {
                CulturalRefsSection(refs: r.culturalReferences)
            }

            // Highlights
            InfoCard(title: "Highlights", body: r.highlights, icon: "sparkles")

            // Tips
            InfoCard(title: "Advice", body: r.tips, icon: "lightbulb.fill")
        }
    }

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

// MARK: - Slang Glossary Section
struct SlangGlossarySection: View {
    let entries: [SlangEntry]
    @State private var expanded: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color.gold)
                SectionHeader(title: "Slang / 隠語")
                Spacer()
                Text("\(entries.count)語")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray)
            }
            .padding(.bottom, 10)

            ForEach(entries) { entry in
                SlangRow(entry: entry, isExpanded: expanded.contains(entry.id)) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if expanded.contains(entry.id) {
                            expanded.remove(entry.id)
                        } else {
                            expanded.insert(entry.id)
                        }
                    }
                }
                if entry.id != entries.last?.id {
                    Divider().background(Color.divider).padding(.vertical, 4)
                }
            }
        }
        .padding(14)
        .cardStyle()
    }
}

struct SlangRow: View {
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
                                Text(reading)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.gray)
                            }
                        }
                        Text(entry.meaning)
                            .font(.system(.caption))
                            .foregroundColor(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .padding(.top, 2)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    if let origin = entry.origin {
                        LabeledText(label: "語源", text: origin)
                    }
                    if let note = entry.usageNote {
                        LabeledText(label: "用法", text: note)
                    }
                    if let region = entry.region {
                        LabeledText(label: "地域", text: region)
                    }
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
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 11))
                    .foregroundColor(Color.gold)
                SectionHeader(title: "Double Meaning / 裏の意味")
            }
            ForEach(items) { item in
                DoubleEntendreCard(item: item)
            }
        }
        .padding(14)
        .cardStyle()
    }
}

struct DoubleEntendreCard: View {
    let item: DoubleEntendre

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // The line
            Text("\"" + item.line + "\"")
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .foregroundColor(Color.gold.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .italic()

            HStack(alignment: .top, spacing: 0) {
                // Surface meaning
                VStack(alignment: .leading, spacing: 2) {
                    Text("表面")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(.gray)
                        .tracking(0.8)
                    Text(item.surface)
                        .font(.system(.caption))
                        .foregroundColor(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(Color.gold.opacity(0.3))
                    .frame(width: 1)
                    .padding(.horizontal, 10)

                // Real meaning
                VStack(alignment: .leading, spacing: 2) {
                    Text("真意")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.gold)
                        .tracking(0.8)
                    Text(item.real)
                        .font(.system(.caption, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let technique = item.technique {
                GoldTag(text: technique)
            }
        }
        .padding(10)
        .background(Color.gold.opacity(0.04))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.gold.opacity(0.15), lineWidth: 0.5)
        )
    }
}

// MARK: - Cultural References Section
struct CulturalRefsSection: View {
    let refs: [CulturalReference]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color.gold)
                SectionHeader(title: "Cultural References")
            }
            ForEach(refs) { ref in
                HStack(alignment: .top, spacing: 10) {
                    Rectangle()
                        .fill(Color.gold)
                        .frame(width: 2)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(ref.reference)
                            .font(.system(.caption, weight: .bold))
                            .foregroundColor(.white)
                        Text(ref.explanation)
                            .font(.system(.caption))
                            .foregroundColor(.white.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(3)
                    }
                }
            }
        }
        .padding(14)
        .cardStyle()
    }
}

// MARK: - Shared sub-components

struct RhymePairRow: View {
    let pair: RhymePair
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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

// MARK: - FlowLayout
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

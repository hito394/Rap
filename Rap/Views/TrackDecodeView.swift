import SwiftUI
import SwiftData

@Observable
class TrackDecodeViewModel {
    var titleText = ""
    var artistText = ""
    var isLoading = false
    var result: TrackDecode?
    var rawResult: String?
    var toastMessage: String?

    var canDecode: Bool {
        !titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !artistText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isLoading
    }

    func selectPickup(_ track: PickupTrack) {
        titleText = track.title
        artistText = track.artist
    }

    func decode(saveHistory: (HistoryItem) -> Void) async {
        guard canDecode else { return }
        isLoading = true
        result = nil
        rawResult = nil

        do {
            let raw = try await AnthropicService.decodeTrack(title: titleText, artist: artistText)
            rawResult = raw
            result = TrackDecode.parse(from: raw)
            let query = "\(titleText) / \(artistText)"
            let item = HistoryItem(type: "track", query: query, resultJSON: raw)
            saveHistory(item)
        } catch {
            toastMessage = (error as? AnthropicError)?.errorDescription ?? "接続を確認してください"
        }

        isLoading = false
    }
}

// MARK: - Main View
struct TrackDecodeView: View {
    @State private var vm = TrackDecodeViewModel()
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    inputSection
                    pickupSection
                    if vm.isLoading { loadingSection }
                    if let result = vm.result {
                        resultSection(result)
                    } else if let raw = vm.rawResult, vm.result == nil && !vm.isLoading {
                        rawTextFallback(raw)
                    }
                }
                .padding(16)
            }
            .background(Color.appBackground)
            .navigationTitle("TRACK DECODE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .toast(message: $vm.toastMessage)
    }

    // MARK: Input
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "楽曲情報")
            InputField(placeholder: "曲名", text: $vm.titleText, icon: "music.note")
            InputField(placeholder: "アーティスト名", text: $vm.artistText, icon: "person.fill")
            Button("解説する") {
                Task { await vm.decode { context.insert($0) } }
            }
            .buttonStyle(PrimaryButtonStyle(isLoading: vm.isLoading))
            .disabled(!vm.canDecode)
        }
    }

    // MARK: Pickup
    private var pickupSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Pickup Tracks")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PickupTrack.list) { track in
                        PickupCard(track: track) { vm.selectPickup(track) }
                    }
                }
                .padding(.horizontal, 1)
            }
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
    private func resultSection(_ r: TrackDecode) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider().background(Color.divider)

            // Header
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.titleText)
                    .font(.system(.title3, weight: .bold))
                    .foregroundColor(.white)
                Text(vm.artistText)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(Color.gold)
            }
            .padding(14)
            .cardStyle()

            InfoCard(title: "Background", body: r.background, icon: "doc.text.fill")
            InfoCard(title: "Era Context", body: r.eraContext, icon: "clock.fill")

            // Rhyme Techniques
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

            // Key Bars
            if !r.keyBars.isEmpty {
                KeyBarsSection(bars: r.keyBars)
            }

            // Sampling
            if !r.samples.isEmpty {
                SamplingSection(samples: r.samples)
            }

            // Slang Glossary
            if !r.slangGlossary.isEmpty {
                TrackSlangSection(entries: r.slangGlossary)
            }

            // Influences
            if !r.influences.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Influences")
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

    private func rawTextFallback(_ raw: String) -> some View {
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

// MARK: - Key Bars Section
struct KeyBarsSection: View {
    let bars: [KeyBar]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color.gold)
                SectionHeader(title: "Key Bars")
            }
            ForEach(bars) { bar in
                KeyBarDetailCard(bar: bar)
            }
        }
        .padding(14)
        .cardStyle()
    }
}

struct KeyBarDetailCard: View {
    let bar: KeyBar
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(bar.bar)
                        .font(.system(.subheadline, design: .monospaced, weight: .medium))
                        .foregroundColor(Color.gold)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(bar.explanation)
                        .font(.system(.caption))
                        .foregroundColor(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                }
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    // Slang breakdown
                    if let slangs = bar.slangBreakdown, !slangs.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("スラング内訳")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundColor(.gray)
                                .tracking(0.8)
                            ForEach(slangs) { s in
                                HStack(alignment: .top, spacing: 6) {
                                    Text(s.word)
                                        .font(.system(size: 11, design: .monospaced, weight: .bold))
                                        .foregroundColor(Color.gold.opacity(0.8))
                                        .frame(minWidth: 60, alignment: .leading)
                                    Text(s.meaning)
                                        .font(.system(.caption))
                                        .foregroundColor(.white.opacity(0.65))
                                    if let o = s.origin {
                                        Text("(\(o))")
                                            .font(.system(.caption))
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(4)
                    }
                    // Subtext
                    if let subtext = bar.subtext {
                        HStack(alignment: .top, spacing: 6) {
                            Text("裏読み")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color.gold.opacity(0.7))
                                .padding(.top, 1)
                            Text(subtext)
                                .font(.system(.caption))
                                .foregroundColor(.white.opacity(0.75))
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(3)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if bar.slangBreakdown?.isEmpty == false || bar.subtext != nil {
                HStack {
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(10)
        .background(Color.gold.opacity(0.04))
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gold.opacity(0.15), lineWidth: 0.5))
    }
}

// MARK: - Sampling Section
struct SamplingSection: View {
    let samples: [SampleInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "waveform.path")
                    .font(.system(size: 11))
                    .foregroundColor(Color.gold)
                SectionHeader(title: "Sampling / 元ネタ")
                Spacer()
                Text("\(samples.count)件")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray)
            }
            ForEach(samples) { sample in
                SampleCard(sample: sample)
            }
        }
        .padding(14)
        .cardStyle()
    }
}

struct SampleCard: View {
    let sample: SampleInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Original track info
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "music.note")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Text(sample.originalTrack)
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    HStack(spacing: 6) {
                        Text(sample.originalArtist)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(Color.gold)
                        if let year = sample.originalYear {
                            Text("(\(year))")
                                .font(.system(.caption))
                                .foregroundColor(.gray)
                        }
                    }
                }
                Spacer()
                GoldTag(text: sample.sampledElement)
            }

            // How it was used
            VStack(alignment: .leading, spacing: 2) {
                Text("使用方法")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(.gray)
                    .tracking(0.8)
                Text(sample.howUsed)
                    .font(.system(.caption))
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }

            // Clearance note
            if let note = sample.clearanceNote, !note.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text(note)
                        .font(.system(.caption))
                        .foregroundColor(.orange.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.03))
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.07), lineWidth: 0.5))
    }
}

// MARK: - Track Slang Section
struct TrackSlangSection: View {
    let entries: [TrackSlangEntry]
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
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if expanded.contains(entry.id) { expanded.remove(entry.id) }
                        else { expanded.insert(entry.id) }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.word)
                                    .font(.system(.subheadline, design: .monospaced, weight: .bold))
                                    .foregroundColor(Color.gold)
                                Text(entry.meaning)
                                    .font(.system(.caption))
                                    .foregroundColor(.white.opacity(0.8))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            if let region = entry.region {
                                Text(region)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.gray)
                                    .padding(.top, 2)
                            }
                        }
                        if expanded.contains(entry.id), let origin = entry.origin {
                            LabeledText(label: "語源", text: origin)
                                .transition(.opacity)
                        }
                    }
                }
                .buttonStyle(.plain)

                if entry.id != entries.last?.id {
                    Divider().background(Color.divider).padding(.vertical, 6)
                }
            }
        }
        .padding(14)
        .cardStyle()
    }
}

// MARK: - Sub-components (shared with LyricsAnalyzeView via module scope)

struct InputField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(Color.gold)
                .frame(width: 18)
            TextField(placeholder, text: $text)
                .font(.system(.body))
                .foregroundColor(.white)
                .tint(Color.gold)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .cardStyle()
    }
}

struct PickupCard: View {
    let track: PickupTrack
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(track.emoji).font(.title2)
                Text(track.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color.gold)
                    .lineLimit(1)
            }
            .frame(width: 110)
            .padding(10)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

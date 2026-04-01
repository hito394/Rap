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
                    if let result = vm.result { resultSection(result) }
                    else if let raw = vm.rawResult, vm.result == nil && !vm.isLoading {
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
                        PickupCard(track: track) {
                            vm.selectPickup(track)
                        }
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

            // Background & Era
            InfoCard(title: "Background", body: r.background, icon: "doc.text.fill")
            InfoCard(title: "Era Context", body: r.eraContext, icon: "clock.fill")

            // Rhyme Techniques
            if !r.rhymeTechniques.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Rhyme Techniques")
                    FlowLayout(spacing: 6) {
                        ForEach(r.rhymeTechniques, id: \.self) { tag in
                            GoldTag(text: tag)
                        }
                    }
                }
                .padding(14)
                .cardStyle()
            }

            // Key Bars
            if !r.keyBars.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Key Bars")
                    ForEach(r.keyBars) { bar in
                        KeyBarCard(bar: bar)
                    }
                }
                .padding(14)
                .cardStyle()
            }

            // Influences
            if !r.influences.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Influences")
                    ForEach(r.influences, id: \.self) { inf in
                        HStack(spacing: 8) {
                            Rectangle()
                                .fill(Color.gold)
                                .frame(width: 2, height: 14)
                            Text(inf)
                                .font(.system(.subheadline))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                }
                .padding(14)
                .cardStyle()
            }

            // Legacy
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

// MARK: - Sub-components

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
                .font(.system(.body, design: .default))
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
                Text(track.emoji)
                    .font(.title2)
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

struct KeyBarCard: View {
    let bar: KeyBar

    var body: some View {
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
        .padding(10)
        .background(Color.gold.opacity(0.05))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.gold.opacity(0.2), lineWidth: 0.5)
        )
    }
}

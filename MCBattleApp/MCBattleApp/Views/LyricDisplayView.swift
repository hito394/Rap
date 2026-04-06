import SwiftUI

/// Shows the currently playing lyric + explanation card with real-time sync.
struct LyricDisplayView: View {
    let entry: LyricEntry?
    let onDeepDive: (LyricEntry) -> Void

    var body: some View {
        ZStack {
            if let entry {
                ActiveLyricCard(entry: entry, onDeepDive: onDeepDive)
                    .id(entry.id) // Force re-render on entry change
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            } else {
                WaitingCard()
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: entry?.id)
    }
}

// MARK: - Active lyric card
private struct ActiveLyricCard: View {
    let entry: LyricEntry
    let onDeepDive: (LyricEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Timestamp badge + deep dive button
            HStack {
                Label(formatTime(entry.start), systemImage: "clock")
                    .font(.monoSmall)
                    .foregroundColor(.gold)
                Spacer()
                Button {
                    onDeepDive(entry)
                } label: {
                    Label("詳しく", systemImage: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.gold)
                        .cornerRadius(20)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            // Gold bar + lyric text
            HStack(alignment: .top, spacing: 10) {
                GoldBar()
                    .frame(height: nil)
                Text(entry.lyric)
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .foregroundColor(.white)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Explanation
            Text(entry.explanation)
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
                .lineSpacing(5)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
        }
        .background(Color.cardBg)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gold.opacity(0.3), lineWidth: 1))
        .shadow(color: Color.gold.opacity(0.08), radius: 12)
    }

    private func formatTime(_ t: Double) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Waiting card (before video plays)
private struct WaitingCard: View {
    var body: some View {
        VStack(spacing: 12) {
            PulsingDot()
            Text("再生するとリリックが表示されます")
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.cardBg)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cardBorder, lineWidth: 1))
    }
}

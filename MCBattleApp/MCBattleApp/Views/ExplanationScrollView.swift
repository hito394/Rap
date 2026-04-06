import SwiftUI

/// Scrollable list of all lyrics — tap any row to seek to that timestamp.
struct ExplanationScrollView: View {
    let entries: [LyricEntry]
    let currentEntry: LyricEntry?
    let onTap: (LyricEntry) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(entries) { entry in
                        EntryRow(
                            entry: entry,
                            isActive: entry.id == currentEntry?.id,
                            onTap: { onTap(entry) }
                        )
                        .id(entry.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: currentEntry?.id) { _, newID in
                guard let id = newID else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }
}

// MARK: - Entry row
private struct EntryRow: View {
    let entry: LyricEntry
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 10) {
                // Active indicator / timestamp
                VStack(spacing: 4) {
                    if isActive {
                        PulsingDot()
                    } else {
                        Circle()
                            .fill(Color.cardBorder)
                            .frame(width: 8, height: 8)
                    }
                    Text(formatTime(entry.start))
                        .font(.monoSmall)
                        .foregroundColor(isActive ? .gold : .textSecondary)
                }
                .frame(width: 40, alignment: .center)

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.lyric)
                        .font(.system(size: 14, weight: isActive ? .bold : .regular))
                        .foregroundColor(isActive ? .white : .textSecondary)
                        .lineLimit(2)
                    if isActive {
                        Text(entry.explanation)
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                            .lineLimit(3)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .background(isActive ? Color.gold.opacity(0.06) : Color.clear)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isActive ? Color.gold.opacity(0.25) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }

    private func formatTime(_ t: Double) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}

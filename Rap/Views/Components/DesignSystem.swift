import SwiftUI

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension Color {
    static let appBackground = Color(hex: "#0d0d0d")
    static let cardBackground = Color(hex: "#1a1a1a")
    static let gold = Color(hex: "#E8C84A")
    static let divider = Color.white.opacity(0.08)
}

// MARK: - Card style
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.cardBackground)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

// MARK: - Corner radius helper (shared)
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Section header
struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundColor(.gray)
            .tracking(1.5)
    }
}

// MARK: - Gold tag
struct GoldTag: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundColor(Color.gold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.gold.opacity(0.12))
            .cornerRadius(3)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.gold.opacity(0.3), lineWidth: 0.5)
            )
    }
}

// MARK: - Primary button style
struct PrimaryButtonStyle: ButtonStyle {
    var isLoading: Bool = false

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(.system(.subheadline, weight: .bold))
            .foregroundColor(isLoading ? .gray : Color(hex: "#0d0d0d"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isLoading ? Color.gray.opacity(0.3) : Color.gold)
            .cornerRadius(4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - FlowLayout (wrapping HStack, shared across all views)
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

// MARK: - SectionGroup (titled section wrapper)
struct SectionGroup<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(Color.gold)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.gray)
                    .tracking(1.2)
            }
            .padding(.horizontal, 20)
            content
        }
    }
}

// MARK: - InputField
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

// MARK: - StreamingTrackCard (album art style pickup card)
struct StreamingTrackCard: View {
    let track: PickupTrack
    let action: () -> Void

    private var gradientColors: [Color] {
        let hash = abs(track.title.hashValue)
        let palettes: [[Color]] = [
            [Color(hex: "#2a1a00"), Color(hex: "#1a0d00")],
            [Color(hex: "#001a2a"), Color(hex: "#000d1a")],
            [Color(hex: "#1a002a"), Color(hex: "#0d001a")],
            [Color(hex: "#002a1a"), Color(hex: "#001a0d")],
            [Color(hex: "#2a0000"), Color(hex: "#1a0000")],
        ]
        return palettes[hash % palettes.count]
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: gradientColors,
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing))
                        .frame(width: 130, height: 130)
                    Text(track.emoji).font(.system(size: 44))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white).lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray).lineLimit(1)
                }
                .frame(width: 130, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Score Ring
struct ScoreRing: View {
    let score: Int
    let maxScore: Int = 10

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 3)
            Circle()
                .trim(from: 0, to: CGFloat(score) / CGFloat(maxScore))
                .stroke(
                    Color.gold,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.8), value: score)
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text("/\(maxScore)")
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
        .frame(width: 60, height: 60)
    }
}

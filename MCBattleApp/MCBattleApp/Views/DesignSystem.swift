import SwiftUI

// MARK: - Color palette (Black & Gold)
extension Color {
    static let gold        = Color(hex: "#E8C84A")
    static let goldDim     = Color(hex: "#B89A30")
    static let appBg       = Color(hex: "#0A0A0A")
    static let cardBg      = Color(hex: "#141414")
    static let cardBorder  = Color(hex: "#2A2A2A")
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "#A0A0A0")

    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.hasPrefix("#") ? String(s.dropFirst()) : s
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Typography
extension Font {
    static let monoSmall  = Font.system(size: 11, design: .monospaced)
    static let monoMedium = Font.system(size: 13, design: .monospaced)
    static let monoLarge  = Font.system(size: 16, design: .monospaced)
}

// MARK: - Card modifier
struct CardStyle: ViewModifier {
    var padding: CGFloat = 14
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.cardBg)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cardBorder, lineWidth: 1))
    }
}

extension View {
    func cardStyle(padding: CGFloat = 14) -> some View {
        modifier(CardStyle(padding: padding))
    }
}

// MARK: - Gold accent bar
struct GoldBar: View {
    var body: some View {
        Rectangle()
            .fill(Color.gold)
            .frame(width: 3)
            .cornerRadius(2)
    }
}

// MARK: - Pulsing dot indicator
struct PulsingDot: View {
    @State private var scale: CGFloat = 1
    var body: some View {
        Circle()
            .fill(Color.gold)
            .frame(width: 8, height: 8)
            .scaleEffect(scale)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: scale)
            .onAppear { scale = 1.5 }
    }
}

// MARK: - Shimmer modifier for loading
struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .white.opacity(0.08), .clear]),
                    startPoint: .init(x: phase - 0.3, y: 0),
                    endPoint: .init(x: phase + 0.3, y: 0)
                )
            )
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1.3
                }
            }
    }
}

extension View {
    func shimmer() -> some View { modifier(Shimmer()) }
}

import SwiftUI

struct SkeletonBlock: View {
    let height: CGFloat
    @State private var animating = false

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(
                LinearGradient(
                    colors: [Color(hex: "#1a1a1a"), Color(hex: "#2a2a2a"), Color(hex: "#1a1a1a")],
                    startPoint: animating ? .leading : .trailing,
                    endPoint: animating ? .trailing : .leading
                )
            )
            .frame(height: height)
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    animating = true
                }
            }
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonBlock(height: 20)
            SkeletonBlock(height: 20).frame(maxWidth: .infinity * 0.7)
            Spacer().frame(height: 4)
            SkeletonBlock(height: 16)
            SkeletonBlock(height: 16)
            SkeletonBlock(height: 16).frame(maxWidth: 200)
            Spacer().frame(height: 4)
            SkeletonBlock(height: 60)
            Spacer().frame(height: 4)
            SkeletonBlock(height: 16)
            SkeletonBlock(height: 16).frame(maxWidth: 240)
        }
        .padding()
        .background(Color(hex: "#1a1a1a"))
        .cornerRadius(8)
    }
}

struct AnalyzingIndicator: View {
    @State private var dots = ""
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(Color(hex: "#E8C84A"))
                .scaleEffect(0.9)
            Text("解析中\(dots)")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(Color(hex: "#E8C84A"))
        }
        .onReceive(timer) { _ in
            dots = dots.count < 3 ? dots + "." : ""
        }
    }
}

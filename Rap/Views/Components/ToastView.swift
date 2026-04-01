import SwiftUI

struct ToastView: View {
    let message: String
    let isError: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundColor(isError ? .red : Color(hex: "#E8C84A"))
            Text(message)
                .font(.system(.subheadline, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: "#1a1a1a").opacity(0.95))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isError ? Color.red.opacity(0.4) : Color(hex: "#E8C84A").opacity(0.4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
    }
}

struct ToastModifier: ViewModifier {
    @Binding var message: String?
    var isError: Bool = true

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
            if let msg = message {
                ToastView(message: msg, isError: isError)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation { message = nil }
                        }
                    }
            }
        }
        .animation(.spring(response: 0.4), value: message)
    }
}

extension View {
    func toast(message: Binding<String?>, isError: Bool = true) -> some View {
        modifier(ToastModifier(message: message, isError: isError))
    }
}

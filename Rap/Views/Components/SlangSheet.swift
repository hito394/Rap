import SwiftUI

struct SlangSheet: View {
    let definition: SlangDefinition
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Handle bar
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 36, height: 4)
                Spacer()
            }
            .padding(.top, 12)
            .padding(.bottom, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Word + reading
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .bottom, spacing: 10) {
                            Text(definition.word)
                                .font(.system(size: 28, weight: .black, design: .monospaced))
                                .foregroundColor(Color.gold)
                            if let reading = definition.reading {
                                Text(reading)
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(.gray)
                                    .padding(.bottom, 4)
                            }
                        }
                        Rectangle()
                            .fill(Color.gold.opacity(0.3))
                            .frame(height: 1)
                    }

                    // Meaning
                    VStack(alignment: .leading, spacing: 6) {
                        SheetLabel("意味")
                        Text(definition.meaning)
                            .font(.system(.body))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(5)
                    }

                    // Origin
                    if let origin = definition.origin, !origin.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            SheetLabel("語源 / 由来")
                            Text(origin)
                                .font(.system(.subheadline))
                                .foregroundColor(.white.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(5)
                        }
                    }

                    // Usage note
                    if let note = definition.usageNote, !note.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            SheetLabel("用法 / ニュアンス")
                            Text(note)
                                .font(.system(.subheadline))
                                .foregroundColor(.white.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(5)
                        }
                    }

                    // Region
                    if let region = definition.region, !region.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(Color.gold)
                                .font(.system(size: 14))
                            Text(region)
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .background(Color(hex: "#111111"))
        .presentationDetents([.fraction(0.45), .large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color(hex: "#111111"))
        .presentationCornerRadius(20)
    }
}

private struct SheetLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundColor(Color.gold.opacity(0.7))
            .tracking(1.5)
    }
}

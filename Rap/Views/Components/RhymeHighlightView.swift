import SwiftUI

// Color palette for rhyme groups (up to 8 groups)
extension Color {
    static let rhymeColors: [Color] = [
        Color(hex: "#E8C84A"), // gold
        Color(hex: "#4AE8C8"), // teal
        Color(hex: "#E84A8C"), // pink
        Color(hex: "#8C4AE8"), // purple
        Color(hex: "#4A8CE8"), // blue
        Color(hex: "#E88C4A"), // orange
        Color(hex: "#4AE84A"), // green
        Color(hex: "#E84A4A"), // red
    ]

    static func rhymeColor(for groupId: Int) -> Color {
        rhymeColors[groupId % rhymeColors.count]
    }
}

struct RhymeHighlightView: View {
    let result: RhymeHighlightResult
    @State private var selectedGroup: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Legend
            if !result.rhymeGroups.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(result.rhymeGroups) { group in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedGroup = selectedGroup == group.groupId ? nil : group.groupId
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.rhymeColor(for: group.groupId))
                                        .frame(width: 8, height: 8)
                                    Text(group.phonetic)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundColor(selectedGroup == group.groupId ? Color.rhymeColor(for: group.groupId) : .white)
                                    Text("(\(group.type))")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.rhymeColor(for: group.groupId).opacity(
                                    selectedGroup == group.groupId ? 0.2 : 0.08
                                ))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            // Annotated lyrics
            VStack(alignment: .leading, spacing: 8) {
                ForEach(result.annotatedLines) { annotatedLine in
                    RhymeLineView(
                        annotatedLine: annotatedLine,
                        rhymeGroups: result.rhymeGroups,
                        selectedGroup: selectedGroup
                    )
                }
            }
            .padding(16)
            .cardStyle()
        }
    }
}

struct RhymeLineView: View {
    let annotatedLine: AnnotatedLine
    let rhymeGroups: [RhymeGroup]
    let selectedGroup: Int?

    var body: some View {
        let tokens = tokenize(line: annotatedLine.line, annotations: annotatedLine.annotations)
        FlowLayout(spacing: 2) {
            ForEach(tokens.indices, id: \.self) { i in
                let token = tokens[i]
                if let groupId = token.groupId {
                    let isSelected = selectedGroup == nil || selectedGroup == groupId
                    Text(token.text)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(Color.rhymeColor(for: groupId))
                        .opacity(isSelected ? 1.0 : 0.3)
                        .background(
                            Color.rhymeColor(for: groupId).opacity(isSelected ? 0.15 : 0.0)
                        )
                        .cornerRadius(2)
                        .underline(true, color: Color.rhymeColor(for: groupId).opacity(isSelected ? 0.6 : 0.0))
                } else {
                    Text(token.text)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }

    struct Token {
        let text: String
        let groupId: Int?
    }

    private func tokenize(line: String, annotations: [WordAnnotation]) -> [Token] {
        // Build a map of word -> groupId
        var wordMap: [String: Int] = [:]
        for ann in annotations {
            wordMap[ann.word] = ann.groupId
        }

        // Split line preserving spaces
        let words = line.components(separatedBy: " ")
        var tokens: [Token] = []
        for (i, word) in words.enumerated() {
            let suffix = i < words.count - 1 ? " " : ""
            // Try to match (strip punctuation for lookup)
            let clean = word.trimmingCharacters(in: .punctuationCharacters)
            if let groupId = wordMap[word] ?? wordMap[clean] {
                tokens.append(Token(text: word + suffix, groupId: groupId))
            } else {
                tokens.append(Token(text: word + suffix, groupId: nil))
            }
        }
        return tokens
    }
}

import SwiftUI

// MARK: - Tappable Lyrics View
// Renders text word-by-word; words matching the slang dictionary are highlighted gold and tappable.

struct TappableLyricsView: View {
    let text: String
    let slangDefinitions: [SlangDefinition]
    var onTap: (SlangDefinition) -> Void

    private var slangMap: [String: SlangDefinition] {
        Dictionary(uniqueKeysWithValues: slangDefinitions.map {
            (Self.normalize($0.word), $0)
        })
    }

    var body: some View {
        let lines = text.components(separatedBy: "\n")
        VStack(alignment: .leading, spacing: 6) {
            ForEach(lines.indices, id: \.self) { i in
                if lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
                    Spacer().frame(height: 4)
                } else {
                    LyricsLineView(line: lines[i], slangMap: slangMap, onTap: onTap)
                }
            }
        }
    }

    static func normalize(_ word: String) -> String {
        word.lowercased()
            .trimmingCharacters(in: .punctuationCharacters)
            .trimmingCharacters(in: .whitespaces)
    }
}

struct LyricsLineView: View {
    let line: String
    let slangMap: [String: SlangDefinition]
    var onTap: (SlangDefinition) -> Void

    var body: some View {
        let words = line.components(separatedBy: " ")
        // Use a wrapping layout
        WrappingWordsView(words: words, slangMap: slangMap, onTap: onTap)
    }
}

struct WrappingWordsView: View {
    let words: [String]
    let slangMap: [String: SlangDefinition]
    var onTap: (SlangDefinition) -> Void

    var body: some View {
        FlowLayout(spacing: 2) {
            ForEach(words.indices, id: \.self) { i in
                let word = words[i]
                let key = TappableLyricsView.normalize(word)
                if let def = slangMap[key] {
                    Button {
                        onTap(def)
                    } label: {
                        Text(word + (i < words.count - 1 ? " " : ""))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(Color.gold)
                            .underline(true, color: Color.gold.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(word + (i < words.count - 1 ? " " : ""))
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
        }
    }
}

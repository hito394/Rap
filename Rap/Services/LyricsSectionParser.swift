import Foundation

// MARK: - Model

/// One named section of lyrics (e.g. Verse 1, Hook, サビ).
struct LyricsSection: Identifiable {
    let id = UUID()
    /// Raw section label, e.g. "Verse 1", "Hook", "サビ", "Aメロ"
    let label: String
    /// The lyric lines inside this section.
    let lines: [String]

    var text: String { lines.joined(separator: "\n") }

    /// Human-readable: "【Hook】" style
    var displayLabel: String { "【\(label)】" }
}

// MARK: - Parser

struct LyricsSectionParser {

    // MARK: - Public API

    /// Split raw lyrics text into named sections.
    /// Handles both Genius-style `[Verse 1: T-Pablow]` and
    /// Japanese `【サビ】` / `（Aメロ）` markers.
    /// Falls back to splitting on blank lines if no markers found.
    static func parse(_ raw: String) -> [LyricsSection] {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return [] }

        // 1. Try bracket markers first
        if let sections = tryBracketParse(cleaned), !sections.isEmpty {
            return sections
        }
        // 2. Try Japanese full-width bracket markers 【…】 or （…）
        if let sections = tryJapaneseParse(cleaned), !sections.isEmpty {
            return sections
        }
        // 3. Heuristic: split on blank lines → call each block a section
        return splitOnBlankLines(cleaned)
    }

    /// Reconstruct a single string with section headers preserved.
    static func reconstruct(_ sections: [LyricsSection]) -> String {
        sections.map { "[\($0.label)]\n\($0.text)" }.joined(separator: "\n\n")
    }

    // MARK: - Strategy 1: ASCII bracket [Label] or [Label: Artist]

    private static func tryBracketParse(_ text: String) -> [LyricsSection]? {
        // Match lines that are purely "[Some Label]" (optional colon + more text)
        let headerRegex = try! NSRegularExpression(
            pattern: #"^\[([^\[\]\n]+)\]\s*$"#,
            options: .anchorsMatchLines
        )
        let lines = text.components(separatedBy: "\n")
        var sections: [LyricsSection] = []
        var currentLabel: String?
        var buffer: [String] = []

        func flush() {
            guard let label = currentLabel else { return }
            let nonEmpty = buffer.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            if !nonEmpty.isEmpty {
                sections.append(LyricsSection(label: label, lines: nonEmpty))
            }
        }

        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            if let match = headerRegex.firstMatch(in: line, range: range),
               let labelRange = Range(match.range(at: 1), in: line) {
                flush()
                currentLabel = String(line[labelRange])
                    .trimmingCharacters(in: .whitespaces)
                buffer = []
            } else {
                buffer.append(line)
            }
        }
        flush()

        // Need at least 2 sections to be meaningful
        return sections.count >= 2 ? sections : nil
    }

    // MARK: - Strategy 2: Japanese full-width 【label】 / （label）

    private static func tryJapaneseParse(_ text: String) -> [LyricsSection]? {
        let patterns = [
            #"^【([^】]+)】\s*$"#,   // 【サビ】
            #"^（([^）]+)）\s*$"#,   // （Aメロ）
            #"^〔([^〕]+)〕\s*$"#,   // 〔Hook〕
        ]
        let regexes = patterns.compactMap { try? NSRegularExpression(pattern: $0, options: .anchorsMatchLines) }
        guard !regexes.isEmpty else { return nil }

        let lines = text.components(separatedBy: "\n")
        var sections: [LyricsSection] = []
        var currentLabel: String?
        var buffer: [String] = []

        func flush() {
            guard let label = currentLabel else { return }
            let nonEmpty = buffer.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            if !nonEmpty.isEmpty {
                sections.append(LyricsSection(label: label, lines: nonEmpty))
            }
        }

        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            var matched = false
            for regex in regexes {
                if let match = regex.firstMatch(in: line, range: range),
                   let labelRange = Range(match.range(at: 1), in: line) {
                    flush()
                    currentLabel = String(line[labelRange]).trimmingCharacters(in: .whitespaces)
                    buffer = []
                    matched = true
                    break
                }
            }
            if !matched { buffer.append(line) }
        }
        flush()

        return sections.count >= 2 ? sections : nil
    }

    // MARK: - Strategy 3: Blank-line splitting

    private static func splitOnBlankLines(_ text: String) -> [LyricsSection] {
        // Split on 1+ blank lines
        let blocks = text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !blocks.isEmpty else { return [] }

        // Auto-label: Verse 1, Verse 2, … with "Hook" guess for short repeated blocks
        var labelCounts: [String: Int] = [:]
        var sections: [LyricsSection] = []

        // Detect repeated blocks (likely hooks)
        var blockFreq: [String: Int] = [:]
        for b in blocks { blockFreq[b, default: 0] += 1 }

        var verseIdx = 1
        var hookIdx  = 1

        for block in blocks {
            let lines = block.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            guard !lines.isEmpty else { continue }

            let isRepeated = (blockFreq[block] ?? 0) > 1
            let isShort    = lines.count <= 4

            let label: String
            if isRepeated {
                label = hookIdx == 1 ? "Hook" : "Hook \(hookIdx)"
                hookIdx += 1
                if labelCounts[label] == nil { labelCounts[label] = 1 }
            } else {
                label = "Verse \(verseIdx)"
                verseIdx += 1
            }
            sections.append(LyricsSection(label: label, lines: lines))
        }
        return sections
    }
}

// MARK: - Convenience on String

extension String {
    /// Parse this lyrics string into structured sections.
    var lyricsSections: [LyricsSection] { LyricsSectionParser.parse(self) }
}

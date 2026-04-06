import Foundation

struct LyricEntry: Codable, Identifiable {
    var id: Int { Int(start * 1000) }
    let start: Double
    let end: Double
    let lyric: String
    let explanation: String
}

extension [LyricEntry] {
    /// Returns the entry active at the given playback time.
    func current(at time: Double) -> LyricEntry? {
        // Find last entry whose start <= time
        last(where: { $0.start <= time && time < $0.end + 1.5 })
    }

    static func load(from filename: String = "battle") -> [LyricEntry] {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([LyricEntry].self, from: data)
        else {
            return []
        }
        return entries.sorted { $0.start < $1.start }
    }
}

import Foundation

struct LrcLibTrack {
    let trackName: String
    let artistName: String
    let albumName: String
    let plainLyrics: String?
    let syncedLyrics: String?  // LRC format: [mm:ss.xx] lyric line
}

struct TimedLyricLine {
    let time: Double   // seconds
    let text: String
}

struct LrcLibService {
    static let base = "https://lrclib.net/api"

    // MARK: - Search
    static func search(title: String, artist: String) async -> LrcLibTrack? {
        // Try direct match first (most accurate)
        if let direct = await getDirect(title: title, artist: artist) {
            return direct
        }
        // Fall back to keyword search with title validation
        return await searchQuery(q: "\(artist) \(title)", title: title, artist: artist)
    }

    // MARK: - Get exact match
    private static func getDirect(title: String, artist: String) async -> LrcLibTrack? {
        var comps = URLComponents(string: "\(base)/get")!
        comps.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
        ]
        return await fetch(comps.url)
    }

    // MARK: - Keyword search with validation
    /// Only returns a track if the title words match — prevents returning wrong songs.
    private static func searchQuery(q: String, title: String, artist: String) async -> LrcLibTrack? {
        var comps = URLComponents(string: "\(base)/search")!
        comps.queryItems = [URLQueryItem(name: "q", value: q)]
        guard let url = comps.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return nil }

        let titleWords = title.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count >= 2 }
        let artistLower = artist.lowercased()

        // Pick the first result whose track name contains all title words
        for item in arr {
            guard let track = parse(item) else { continue }
            let tl = track.trackName.lowercased()
            let al = track.artistName.lowercased()
            let titleMatch = titleWords.isEmpty || titleWords.allSatisfy { tl.contains($0) }
            let artistMatch = artistLower.isEmpty || al.contains(artistLower)
                || artistLower.components(separatedBy: .whitespaces).contains(where: { al.contains($0) })
            if titleMatch && artistMatch { return track }
        }
        // If no artist+title match, try title-only match
        for item in arr {
            guard let track = parse(item) else { continue }
            let tl = track.trackName.lowercased()
            let titleMatch = titleWords.isEmpty || titleWords.allSatisfy { tl.contains($0) }
            if titleMatch { return track }
        }
        return nil  // No valid match — don't return wrong lyrics
    }

    private static func fetch(_ url: URL?) async -> LrcLibTrack? {
        guard let url,
              let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return parse(json)
    }

    private static func parse(_ json: [String: Any]) -> LrcLibTrack? {
        guard let name = json["trackName"] as? String,
              let artist = json["artistName"] as? String
        else { return nil }
        return LrcLibTrack(
            trackName: name,
            artistName: artist,
            albumName: json["albumName"] as? String ?? "",
            plainLyrics: json["plainLyrics"] as? String,
            syncedLyrics: json["syncedLyrics"] as? String
        )
    }

    // MARK: - Parse LRC format → timed lines
    /// Parses "[mm:ss.xx] lyric" format into (time, text) pairs.
    static func parseLRC(_ lrc: String) -> [TimedLyricLine] {
        let pattern = #"^\[(\d{1,2}):(\d{2})\.(\d{1,3})\] ?(.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        var lines: [TimedLyricLine] = []
        for raw in lrc.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            let range = NSRange(line.startIndex..., in: line)
            guard let match = regex.firstMatch(in: line, range: range) else { continue }

            func group(_ i: Int) -> String {
                let r = Range(match.range(at: i), in: line)!
                return String(line[r])
            }

            let mins = Double(group(1)) ?? 0
            let secs = Double(group(2)) ?? 0
            let frac = Double("0." + group(3)) ?? 0
            let time = mins * 60 + secs + frac
            let text = group(4)
            guard !text.isEmpty else { continue }
            lines.append(TimedLyricLine(time: time, text: text))
        }
        return lines.sorted { $0.time < $1.time }
    }
}

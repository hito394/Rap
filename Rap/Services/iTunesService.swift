import Foundation

struct iTunesTrack: Codable, Identifiable {
    var id: String { trackName + artistName }
    let trackName: String
    let artistName: String
    let artworkUrl100: String?
    let previewUrl: String?
    let collectionName: String?

    var artworkUrl500: String? {
        artworkUrl100?.replacingOccurrences(of: "100x100bb", with: "500x500bb")
    }
}

private struct iTunesResponse: Codable {
    let results: [iTunesTrack]
}

struct iTunesService {
    /// カラオケ・カバー・歌ってみた系を除外するキーワード
    private static let noiseKeywords = [
        "カラオケ", "karaoke", "原曲歌手", "cover", "歌っちゃ王",
        "歌ってみた", "うたってみた", "acoustic", "tribute",
        "instrumental", "off vocal", "minus one"
    ]

    private static func isNoise(_ track: iTunesTrack) -> Bool {
        let combined = "\(track.trackName) \(track.artistName) \(track.collectionName ?? "")".lowercased()
        return noiseKeywords.contains { combined.contains($0.lowercased()) }
    }

    private static func fetch(_ urlString: String) async -> [iTunesTrack] {
        guard let url = URL(string: urlString),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let response = try? JSONDecoder().decode(iTunesResponse.self, from: data) else {
            return []
        }
        return response.results
    }

    // Predictive suggestions while user types title
    // Requires ALL words from the query to appear in trackName (or trackName+artistName)
    // to prevent "Drift (aespa)" appearing for "Kawasaki Drift" query.
    // When artist is provided, further filters to tracks matching that artist.
    static func searchByTitle(query: String, artist: String = "", limit: Int = 10) async -> [iTunesTrack] {
        guard query.count >= 2,
              let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return []
        }
        let results = await fetch(
            "https://itunes.apple.com/search?term=\(encoded)&country=jp&media=music&entity=song&limit=\(limit)"
        )
        let clean = results.filter { !isNoise($0) }
        let pool = clean.isEmpty ? results : clean

        // Split query into meaningful words (≥2 chars)
        let queryWords = query.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count >= 2 }

        // Strict: ALL query words must appear somewhere in trackName+artistName
        let strict = pool.filter { track in
            let combined = "\(track.trackName) \(track.artistName)".lowercased()
            return queryWords.allSatisfy { combined.contains($0) }
        }

        // If strict filter yields nothing (e.g. Japanese title search), fall back to partial
        let candidates = strict.isEmpty ? pool : strict

        // If artist is provided, further restrict to matching artist
        let artistTrimmed = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        if !artistTrimmed.isEmpty {
            let artistLower = artistTrimmed.lowercased()
            let artistWords = artistLower
                .components(separatedBy: .alphanumerics.inverted)
                .filter { $0.count >= 2 }
            let artistMatch = candidates.filter { track in
                let a = track.artistName.lowercased()
                return a.contains(artistLower) || artistWords.contains(where: { a.contains($0) })
            }
            if !artistMatch.isEmpty { return Array(artistMatch.prefix(6)) }
        }

        return Array(candidates.prefix(6))
    }

    // Best match for known title + artist (used after decode)
    static func search(title: String, artist: String) async -> iTunesTrack? {
        let query = "\(title) \(artist)"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        let results = await fetch(
            "https://itunes.apple.com/search?term=\(encoded)&country=jp&media=music&limit=10"
        )
        // ノイズ除外
        let clean = results.filter { !isNoise($0) }
        let pool = clean.isEmpty ? results : clean

        let titleNorm = title.lowercased()
        let artistNorm = artist.lowercased()

        // 1. 曲名 + アーティスト両方一致
        if let best = pool.first(where: {
            $0.trackName.lowercased().contains(titleNorm) &&
            $0.artistName.lowercased().contains(artistNorm)
        }) { return best }

        // 2. 曲名のみ一致
        if let byTitle = pool.first(where: { $0.trackName.lowercased().contains(titleNorm) }) {
            return byTitle
        }
        return pool.first
    }
}

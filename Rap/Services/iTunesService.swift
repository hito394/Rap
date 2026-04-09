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

    /// Predictive suggestions while the user is typing.
    ///
    /// Strategy:
    /// 1. When artist is known, include it in the iTunes search term so the API itself
    ///    returns more relevant results (e.g. "Kawasaki Drift BAD HOP").
    /// 2. ALL title words must appear in the track's own **trackName** (not artistName).
    ///    This prevents "KAWASAKI (Big Sean)" matching "Kawasaki Drift" just because
    ///    both contain one of the two words.
    /// 3. For multi-word titles, never fall back to a pool of unrelated tracks when the
    ///    strict filter yields nothing. Return empty instead of showing wrong songs.
    /// 4. When artist is provided, restrict to tracks whose artistName contains a match;
    ///    if none found in strict, return empty (don't show wrong artist tracks).
    static func searchByTitle(query: String, artist: String = "", limit: Int = 10) async -> [iTunesTrack] {
        guard query.count >= 2 else { return [] }

        let artistTrimmed = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasArtist = !artistTrimmed.isEmpty

        // Include artist in the search term when available — better iTunes recall
        let searchTerm = hasArtist ? "\(query) \(artistTrimmed)" : query
        guard let encoded = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return []
        }

        let results = await fetch(
            "https://itunes.apple.com/search?term=\(encoded)&country=jp&media=music&entity=song&limit=\(limit)"
        )
        let clean = results.filter { !isNoise($0) }
        let pool = clean.isEmpty ? results : clean

        // Title words (≥2 chars) that MUST appear in trackName
        let queryWords = query.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count >= 2 }

        // Strict: all title words must appear in trackName ONLY (not artistName).
        // Checking only trackName ensures "KAWASAKI" (Big Sean) never matches "Kawasaki Drift"
        // since "drift" is absent from its trackName.
        let strict = pool.filter { track in
            let titleLower = track.trackName.lowercased()
            return queryWords.allSatisfy { titleLower.contains($0) }
        }

        // Multi-word: if no exact title match, return nothing — never show wrong songs.
        // Single-word: fall back to pool (acceptable for short/Japanese queries).
        let isMultiWord = queryWords.count >= 2
        let candidates: [iTunesTrack]
        if strict.isEmpty {
            if isMultiWord { return [] }
            candidates = pool
        } else {
            candidates = strict
        }

        // When artist is provided, keep only tracks whose artistName matches.
        if hasArtist {
            let artistLower = artistTrimmed.lowercased()
            let artistWords = artistLower
                .components(separatedBy: .alphanumerics.inverted)
                .filter { $0.count >= 2 }
            let artistMatch = candidates.filter { track in
                let a = track.artistName.lowercased()
                return a.contains(artistLower) || artistWords.contains(where: { a.contains($0) })
            }
            // If artist filter yields nothing (track not on iTunes or listed differently),
            // return empty rather than showing tracks from the wrong artist.
            return Array(artistMatch.prefix(6))
        }

        return Array(candidates.prefix(6))
    }

    // Best match for known title + artist (used after decode to fetch artwork/preview)
    static func search(title: String, artist: String) async -> iTunesTrack? {
        let query = "\(title) \(artist)"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        let results = await fetch(
            "https://itunes.apple.com/search?term=\(encoded)&country=jp&media=music&limit=10"
        )
        let clean = results.filter { !isNoise($0) }
        let pool = clean.isEmpty ? results : clean

        let titleNorm = title.lowercased()
        let artistNorm = artist.lowercased()

        // 1. trackName + artistName 両方一致
        if let best = pool.first(where: {
            $0.trackName.lowercased().contains(titleNorm) &&
            $0.artistName.lowercased().contains(artistNorm)
        }) { return best }

        // 2. trackName のみ一致
        if let byTitle = pool.first(where: { $0.trackName.lowercased().contains(titleNorm) }) {
            return byTitle
        }
        return pool.first
    }
}

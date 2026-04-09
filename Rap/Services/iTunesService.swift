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
    /// Order of precedence:
    /// 1. iTunes Japan — real results with artwork and preview
    /// 2. Local offline database — fallback when iTunes doesn't have the track
    ///    (common for Japanese rap albums not indexed in iTunes JP store)
    static func searchByTitle(query: String, artist: String = "", limit: Int = 10) async -> [iTunesTrack] {
        guard query.count >= 2 else { return [] }

        let artistTrimmed = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasArtist = !artistTrimmed.isEmpty

        // Build search term: include artist for more precise iTunes results
        let searchTerm = hasArtist ? "\(query) \(artistTrimmed)" : query
        guard let encoded = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return []
        }

        let results = await fetch(
            "https://itunes.apple.com/search?term=\(encoded)&country=jp&media=music&entity=song&limit=\(limit)"
        )
        let clean = results.filter { !isNoise($0) }
        let pool = clean.isEmpty ? results : clean

        // Title words that must appear in trackName
        let queryWords = query.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count >= 2 }

        // Strict: all title words must appear in trackName
        let strict = pool.filter { track in
            let titleLower = track.trackName.lowercased()
            return queryWords.allSatisfy { titleLower.contains($0) }
        }

        // For multi-word queries with no strict matches: try local DB before giving up
        let isMultiWord = queryWords.count >= 2
        let iTunesCandidates: [iTunesTrack]
        if strict.isEmpty && isMultiWord {
            iTunesCandidates = []  // will fall through to local DB
        } else if strict.isEmpty {
            iTunesCandidates = pool
        } else {
            iTunesCandidates = strict
        }

        // Artist filter on iTunes results
        var itunesFiltered: [iTunesTrack] = []
        if !iTunesCandidates.isEmpty {
            if hasArtist {
                let artistLower = artistTrimmed.lowercased()
                let artistWords = artistLower
                    .components(separatedBy: .alphanumerics.inverted)
                    .filter { $0.count >= 2 }
                let artistMatch = iTunesCandidates.filter { track in
                    let a = track.artistName.lowercased()
                    return a.contains(artistLower) || artistWords.contains(where: { a.contains($0) })
                }
                itunesFiltered = Array((artistMatch.isEmpty ? iTunesCandidates : artistMatch).prefix(limit))
            } else {
                itunesFiltered = Array(iTunesCandidates.prefix(limit))
            }
        }

        // If iTunes gave good results, return them (they have artwork/preview)
        if !itunesFiltered.isEmpty { return itunesFiltered }

        // Fallback: local offline database
        let localResults = LocalTrackDatabase.search(title: query, artist: artistTrimmed, limit: limit)
        return localResults
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

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
        let s = "\(track.trackName) \(track.artistName) \(track.collectionName ?? "")".lowercased()
        return noiseKeywords.contains { s.contains($0.lowercased()) }
    }

    private static func fetch(_ urlString: String) async -> [iTunesTrack] {
        guard let url = URL(string: urlString),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let resp = try? JSONDecoder().decode(iTunesResponse.self, from: data) else { return [] }
        return resp.results
    }

    // MARK: - Predictive suggestion search (3-tier)

    /// Tier 1 → iTunes Japan  (has artwork + preview)
    /// Tier 2 → Local offline DB (instant, 150+ J-rap tracks)
    /// Tier 3 → MusicBrainz  (free, no key, 30M+ tracks worldwide)
    static func searchByTitle(query: String, artist: String = "", limit: Int = 10) async -> [iTunesTrack] {
        guard query.count >= 2 else { return [] }

        let artistTrimmed = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasArtist = !artistTrimmed.isEmpty

        // ── Tier 1: iTunes Japan ──────────────────────────────────────────────
        let searchTerm = hasArtist ? "\(query) \(artistTrimmed)" : query
        if let encoded = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            let raw  = await fetch("https://itunes.apple.com/search?term=\(encoded)&country=jp&media=music&entity=song&limit=\(limit)")
            let pool = raw.filter { !isNoise($0) }.isEmpty ? raw : raw.filter { !isNoise($0) }
            let qWords = query.lowercased().components(separatedBy: .alphanumerics.inverted).filter { $0.count >= 2 }
            let strict = pool.filter { t in
                let tl = t.trackName.lowercased()
                return qWords.allSatisfy { tl.contains($0) }
            }
            let candidates = strict.isEmpty ? (qWords.count >= 2 ? [] : pool) : strict
            if !candidates.isEmpty {
                let filtered = applyArtistFilter(candidates, artist: artistTrimmed)
                if !filtered.isEmpty { return Array(filtered.prefix(limit)) }
            }
        }

        // ── Tier 2: Local offline DB ──────────────────────────────────────────
        let local = LocalTrackDatabase.search(title: query, artist: artistTrimmed, limit: limit)
        if !local.isEmpty { return local }

        // ── Tier 3: MusicBrainz ───────────────────────────────────────────────
        let mb = await MusicBrainzService.searchSuggestions(title: query, artist: artistTrimmed, limit: limit)
        let mbFiltered = hasArtist ? applyArtistFilter(mb, artist: artistTrimmed) : mb
        return Array((mbFiltered.isEmpty ? mb : mbFiltered).prefix(limit))
    }

    // MARK: - Artist filter helper

    private static func applyArtistFilter(_ tracks: [iTunesTrack], artist: String) -> [iTunesTrack] {
        guard !artist.isEmpty else { return tracks }
        let aLower = artist.lowercased()
        let aWords = aLower.components(separatedBy: .alphanumerics.inverted).filter { $0.count >= 2 }
        return tracks.filter { t in
            let a = t.artistName.lowercased()
            return a.contains(aLower) || aWords.contains(where: { a.contains($0) })
        }
        // returns [] when no artist match — caller falls through to LocalDB
    }

    // MARK: - Best match for artwork / preview (called after decode)

    static func search(title: String, artist: String) async -> iTunesTrack? {
        let query = "\(title) \(artist)"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        let results = await fetch("https://itunes.apple.com/search?term=\(encoded)&country=jp&media=music&limit=10")
        let pool = results.filter { !isNoise($0) }.isEmpty ? results : results.filter { !isNoise($0) }
        let tNorm = title.lowercased()
        let aNorm = artist.lowercased()
        let aWords = aNorm.components(separatedBy: .alphanumerics.inverted).filter { $0.count >= 2 }

        // 1. Title + exact artist match
        if let best = pool.first(where: {
            $0.trackName.lowercased().contains(tNorm) && $0.artistName.lowercased().contains(aNorm)
        }) { return best }

        // 2. Title + any artist-word match (e.g. "BAD HOP" matches "BAD HOP & ...")
        if let wordMatch = pool.first(where: {
            let a = $0.artistName.lowercased()
            return $0.trackName.lowercased().contains(tNorm) && aWords.contains(where: { a.contains($0) })
        }) { return wordMatch }

        // 3. Title only — only when no artist was given
        if artist.isEmpty, let byTitle = pool.first(where: { $0.trackName.lowercased().contains(tNorm) }) {
            return byTitle
        }

        // 4. Second-pass: search title only, apply artist-word filter on wider result set
        //    Handles cases where iTunes lists track under individual member instead of group
        if !artist.isEmpty,
           let encoded2 = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            let results2 = await fetch("https://itunes.apple.com/search?term=\(encoded2)&country=jp&media=music&limit=20")
            let pool2 = results2.filter { !isNoise($0) }.isEmpty ? results2 : results2.filter { !isNoise($0) }
            if let best2 = pool2.first(where: {
                let a = $0.artistName.lowercased()
                return $0.trackName.lowercased().contains(tNorm) && aWords.contains(where: { a.contains($0) })
            }) { return best2 }
            // Last resort: exact title match only (avoids totally unrelated tracks)
            if let byTitleOnly = pool2.first(where: { $0.trackName.lowercased() == tNorm }) {
                return byTitleOnly
            }
        }

        return nil
    }
}

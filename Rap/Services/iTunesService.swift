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

// MARK: - MusicBrainz response models (private)

private struct MBResponse: Codable {
    let recordings: [MBRecording]
}
private struct MBRecording: Codable {
    let title: String
    let score: Int
    let artistCredit: [MBArtistCredit]?
    let releases: [MBRelease]?
    enum CodingKeys: String, CodingKey {
        case title, score
        case artistCredit = "artist-credit"
        case releases
    }
}
private struct MBArtistCredit: Codable {
    let artist: MBArtist
}
private struct MBArtist: Codable {
    let name: String
}
private struct MBRelease: Codable {
    let title: String
}

// MARK: - Service

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

    // MARK: - MusicBrainz search (comprehensive fallback — millions of tracks, no API key)

    private static func searchMusicBrainz(title: String, artist: String) async -> [iTunesTrack] {
        // Build Lucene query
        var parts = ["recording:\"\(title)\""]
        if !artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("artist:\"\(artist)\"")
        }
        let query = parts.joined(separator: " AND ")
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://musicbrainz.org/ws/2/recording/?query=\(encoded)&fmt=json&limit=6") else {
            return []
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 5
        // MusicBrainz requires a descriptive User-Agent
        req.setValue("JapaneseHipHopDecoder/1.0 (iOS educational app)", forHTTPHeaderField: "User-Agent")

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let mb = try? JSONDecoder().decode(MBResponse.self, from: data) else {
            return []
        }

        return mb.recordings.compactMap { rec -> iTunesTrack? in
            guard rec.score >= 55 else { return nil }
            let artistName = rec.artistCredit?.first?.artist.name ?? artist
            let albumName  = rec.releases?.first?.title
            return iTunesTrack(
                trackName: rec.title,
                artistName: artistName,
                artworkUrl100: nil,
                previewUrl: nil,
                collectionName: albumName
            )
        }
    }

    // MARK: - Predictive suggestion search

    /// Search order:
    ///  1. iTunes Japan  — artwork + preview, limited catalog
    ///  2. Local offline DB — instant, covers 150+ Japanese rap tracks
    ///  3. MusicBrainz  — free, no key, millions of tracks worldwide
    static func searchByTitle(query: String, artist: String = "", limit: Int = 10) async -> [iTunesTrack] {
        guard query.count >= 2 else { return [] }

        let artistTrimmed = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasArtist = !artistTrimmed.isEmpty

        // ── Tier 1: iTunes Japan ──────────────────────────────────────────────
        let searchTerm = hasArtist ? "\(query) \(artistTrimmed)" : query
        if let encoded = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            let raw = await fetch(
                "https://itunes.apple.com/search?term=\(encoded)&country=jp&media=music&entity=song&limit=\(limit)"
            )
            let pool = raw.filter { !isNoise($0) }.isEmpty ? raw : raw.filter { !isNoise($0) }
            let qWords = query.lowercased()
                .components(separatedBy: .alphanumerics.inverted).filter { $0.count >= 2 }
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

        // ── Tier 3: MusicBrainz (comprehensive worldwide catalog) ─────────────
        let mb = await searchMusicBrainz(title: query, artist: artistTrimmed)
        let mbFiltered = hasArtist ? applyArtistFilter(mb, artist: artistTrimmed) : mb
        return Array((mbFiltered.isEmpty ? mb : mbFiltered).prefix(limit))
    }

    // MARK: - Helpers

    private static func applyArtistFilter(_ tracks: [iTunesTrack], artist: String) -> [iTunesTrack] {
        guard !artist.isEmpty else { return tracks }
        let aLower = artist.lowercased()
        let aWords = aLower.components(separatedBy: .alphanumerics.inverted).filter { $0.count >= 2 }
        let matched = tracks.filter { t in
            let a = t.artistName.lowercased()
            return a.contains(aLower) || aWords.contains(where: { a.contains($0) })
        }
        return matched.isEmpty ? tracks : matched
    }

    // MARK: - Best match (artwork fetch after decode)

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
        let tNorm = title.lowercased()
        let aNorm = artist.lowercased()
        if let best = pool.first(where: {
            $0.trackName.lowercased().contains(tNorm) && $0.artistName.lowercased().contains(aNorm)
        }) { return best }
        if let byTitle = pool.first(where: { $0.trackName.lowercased().contains(tNorm) }) {
            return byTitle
        }
        return pool.first
    }
}

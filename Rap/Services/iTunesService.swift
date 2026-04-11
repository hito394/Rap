import Foundation

struct iTunesTrack: Codable, Identifiable {
    var id: String { trackName + artistName }
    let trackName: String
    let artistName: String
    let artworkUrl100: String?
    let previewUrl: String?
    let collectionName: String?

    var artworkUrl500: String? {
        guard let url = artworkUrl100 else { return nil }
        // iTunes CDN: swap 100x100bb → 500x500bb
        if url.contains("100x100bb") {
            return url.replacingOccurrences(of: "100x100bb", with: "500x500bb")
        }
        // Deezer / other CDN: already full-res, return as-is
        return url
    }
}

private struct iTunesResponse: Codable {
    let results: [iTunesTrack]
}

// MARK: - Deezer (no-auth artwork fallback)

private struct DeezerResponse: Codable {
    let data: [DeezerItem]
}
private struct DeezerItem: Codable {
    let title: String
    let artist: DeezerArtist
    let album: DeezerAlbum
}
private struct DeezerArtist: Codable { let name: String }
private struct DeezerAlbum: Codable {
    let coverXl: String?
    let coverBig: String?
    enum CodingKeys: String, CodingKey {
        case coverXl = "cover_xl"
        case coverBig = "cover_big"
    }
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

    // MARK: - Deezer artwork search

    private static func deezerArtwork(title: String, artist: String) async -> String? {
        let tNorm = title.lowercased()
        let aNorm = artist.lowercased()
        let aWords = aNorm.components(separatedBy: .alphanumerics.inverted).filter { $0.count >= 2 }

        // Try quoted title+artist query first, then plain query
        let queries = [
            "track:\"\(title)\" artist:\"\(artist)\"",
            "\(title) \(artist)"
        ]
        for q in queries {
            guard let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "https://api.deezer.com/search?q=\(encoded)&limit=10"),
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let resp = try? JSONDecoder().decode(DeezerResponse.self, from: data) else { continue }

            for item in resp.data {
                let iTitle = item.title.lowercased()
                let iArtist = item.artist.name.lowercased()
                let titleOK = iTitle.contains(tNorm) || tNorm.contains(iTitle)
                let artistOK = iArtist.contains(aNorm)
                    || aNorm.contains(iArtist)
                    || aWords.contains(where: { iArtist.contains($0) })
                if titleOK && artistOK {
                    return item.album.coverXl ?? item.album.coverBig
                }
            }
        }
        return nil
    }

    // MARK: - Predictive suggestion search (3-tier)

    /// Tier 1 → iTunes Japan  (has artwork + preview)
    /// Tier 2 → Local offline DB (always merged with iTunes — guarantees known tracks appear)
    /// Tier 3 → MusicBrainz  (free, no key, 30M+ tracks worldwide)
    static func searchByTitle(query: String, artist: String = "", limit: Int = 10) async -> [iTunesTrack] {
        guard query.count >= 2 else { return [] }

        let artistTrimmed = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasArtist = !artistTrimmed.isEmpty
        let qLower = query.lowercased()
        let qWords = qLower.components(separatedBy: .alphanumerics.inverted).filter { $0.count >= 2 }

        // ── Tier 1: iTunes Japan ──────────────────────────────────────────────
        var itunesMatches: [iTunesTrack] = []
        let searchTerm = hasArtist ? "\(query) \(artistTrimmed)" : query
        if let encoded = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            let raw  = await fetch("https://itunes.apple.com/search?term=\(encoded)&country=jp&media=music&entity=song&limit=\(limit * 2)")
            let pool = raw.filter { !isNoise($0) }.isEmpty ? raw : raw.filter { !isNoise($0) }
            // Only keep tracks whose title actually matches the query words
            let strict = pool.filter { t in
                let tl = t.trackName.lowercased()
                return qWords.isEmpty ? tl.contains(qLower) : qWords.allSatisfy { tl.contains($0) }
            }
            let candidates = strict.isEmpty ? [] : strict
            if !candidates.isEmpty {
                let filtered = applyArtistFilter(candidates, artist: artistTrimmed)
                itunesMatches = Array((filtered.isEmpty ? candidates : filtered).prefix(limit))
            }
        }

        // ── Tier 2: Local offline DB (always run — merge with iTunes) ─────────
        // This ensures tracks not on iTunes JP always appear (e.g. Kawasaki Drift)
        let local = LocalTrackDatabase.search(title: query, artist: artistTrimmed, limit: limit)

        // Merge: iTunes first (has artwork), then LocalDB entries not already covered
        var merged = itunesMatches
        for track in local {
            let alreadyPresent = merged.contains(where: {
                $0.trackName.lowercased() == track.trackName.lowercased()
                && $0.artistName.lowercased() == track.artistName.lowercased()
            })
            if !alreadyPresent { merged.append(track) }
        }

        if !merged.isEmpty { return Array(merged.prefix(limit)) }

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
    //
    // Search order:
    //   1. iTunes JP  — title + exact artist
    //   2. iTunes JP  — title + artist-word match
    //   3. iTunes JP  — title-only pass (no artist given)
    //   4. iTunes JP  — title-only, wider result set, artist-word filter
    //   5. iTunes US  — same strategy (some J-rap only on US store)
    //   6. Deezer     — free API, no auth, excellent J-hiphop coverage

    static func search(title: String, artist: String) async -> iTunesTrack? {
        let tNorm  = title.lowercased()
        let aNorm  = artist.lowercased()
        let aWords = aNorm.components(separatedBy: .alphanumerics.inverted).filter { $0.count >= 2 }

        func firstMatch(from pool: [iTunesTrack]) -> iTunesTrack? {
            // Exact artist
            if let t = pool.first(where: {
                $0.trackName.lowercased().contains(tNorm) && $0.artistName.lowercased().contains(aNorm)
            }) { return t }
            // Artist-word match
            if let t = pool.first(where: {
                let a = $0.artistName.lowercased()
                return $0.trackName.lowercased().contains(tNorm) && aWords.contains(where: { a.contains($0) })
            }) { return t }
            return nil
        }

        // 1–2. iTunes JP with combined query
        if let enc = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            let pool = await itunesPool(encoded: enc, country: "jp", limit: 15)
            if let m = firstMatch(from: pool) { return m }
        }

        // 3. iTunes JP title-only (no artist given)
        if artist.isEmpty,
           let enc = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            let pool = await itunesPool(encoded: enc, country: "jp", limit: 10)
            if let t = pool.first(where: { $0.trackName.lowercased().contains(tNorm) }) { return t }
        }

        // 4. iTunes JP title-only, wider, with artist-word filter
        if !artist.isEmpty,
           let enc = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            let pool = await itunesPool(encoded: enc, country: "jp", limit: 25)
            if let m = firstMatch(from: pool) { return m }
            if let t = pool.first(where: { $0.trackName.lowercased() == tNorm }) { return t }
        }

        // 5. iTunes US (some J-rap distributed globally on US store)
        if let enc = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            let pool = await itunesPool(encoded: enc, country: "us", limit: 15)
            if let m = firstMatch(from: pool) { return m }
        }

        // 6. Deezer fallback — returns a synthetic iTunesTrack with Deezer artwork URL
        if let coverUrl = await deezerArtwork(title: title, artist: artist) {
            print("🎨 [iTunes] Deezer artwork fallback for \(title) / \(artist)")
            return iTunesTrack(
                trackName: title,
                artistName: artist,
                artworkUrl100: coverUrl,
                previewUrl: nil,
                collectionName: nil
            )
        }

        return nil
    }

    private static func itunesPool(encoded: String, country: String, limit: Int) async -> [iTunesTrack] {
        let raw = await fetch("https://itunes.apple.com/search?term=\(encoded)&country=\(country)&media=music&entity=song&limit=\(limit)")
        return raw.filter { !isNoise($0) }.isEmpty ? raw : raw.filter { !isNoise($0) }
    }
}

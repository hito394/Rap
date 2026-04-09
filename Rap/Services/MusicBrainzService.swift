import Foundation

/// Metadata returned by MusicBrainz for a recording.
struct MBTrackInfo {
    let title: String
    let artist: String
    let album: String?
    let year: String?
    let genres: [String]   // MusicBrainz tags sorted by vote count

    /// One-line summary injected into Claude prompts as verified ground truth.
    var promptSummary: String {
        var parts: [String] = ["曲名: \(title)", "アーティスト: \(artist)"]
        if let a = album  { parts.append("アルバム: \(a)") }
        if let y = year   { parts.append("リリース: \(y)年") }
        if !genres.isEmpty { parts.append("ジャンル/タグ: \(genres.prefix(5).joined(separator: ", "))") }
        return parts.joined(separator: " / ")
    }
}

struct MusicBrainzService {

    // MARK: - Config

    private static let baseURL   = "https://musicbrainz.org/ws/2"
    private static let userAgent = "HiphopDecoderApp/1.0.0 (shi03to04shi@icloud.com )"

    // MARK: - HTTP helper

    private static func get(_ urlString: String) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        var req = URLRequest(url: url)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 6
        return try? await URLSession.shared.data(for: req).0
    }

    // MARK: - Track lookup (used during decode to confirm metadata)

    /// Find the best MusicBrainz recording match for a given title + artist.
    /// Returns nil when confidence is below threshold or network fails.
    static func lookupTrack(title: String, artist: String) async -> MBTrackInfo? {
        var parts = ["recording:\"\(title)\""]
        let trimArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimArtist.isEmpty { parts.append("artist:\"\(trimArtist)\"") }

        let query = parts.joined(separator: " AND ")
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let data = await get("\(baseURL)/recording/?query=\(encoded)&fmt=json&limit=1") else {
            return nil
        }

        guard let resp = try? JSONDecoder().decode(MBRecordingResponse.self, from: data),
              let rec  = resp.recordings.first,
              rec.score >= 60 else { return nil }

        let confirmedArtist = rec.artistCredit?.first?.artist.name ?? trimArtist
        let album  = rec.releases?.first?.title
        let year   = rec.firstReleaseDate.flatMap { d in
            d.count >= 4 ? String(d.prefix(4)) : nil
        }
        let genres = (rec.tags ?? [])
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map { $0.name }

        return MBTrackInfo(
            title:  rec.title,
            artist: confirmedArtist,
            album:  album,
            year:   year,
            genres: Array(genres)
        )
    }

    // MARK: - Suggestion search (used by iTunesService as third-tier fallback)

    static func searchSuggestions(title: String, artist: String, limit: Int = 6) async -> [iTunesTrack] {
        var parts = ["recording:\"\(title)\""]
        let trimArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimArtist.isEmpty { parts.append("artist:\"\(trimArtist)\"") }

        let query = parts.joined(separator: " AND ")
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let data = await get("\(baseURL)/recording/?query=\(encoded)&fmt=json&limit=\(limit)") else {
            return []
        }

        guard let resp = try? JSONDecoder().decode(MBRecordingResponse.self, from: data) else {
            return []
        }

        return resp.recordings.compactMap { rec -> iTunesTrack? in
            guard rec.score >= 55 else { return nil }
            let artistName = rec.artistCredit?.first?.artist.name ?? trimArtist
            return iTunesTrack(
                trackName:    rec.title,
                artistName:   artistName,
                artworkUrl100: nil,
                previewUrl:   nil,
                collectionName: rec.releases?.first?.title
            )
        }
    }
}

// MARK: - Private Codable models

private struct MBRecordingResponse: Codable {
    let recordings: [MBRecording]
}

private struct MBRecording: Codable {
    let title: String
    let score: Int
    let firstReleaseDate: String?
    let artistCredit: [MBArtistCredit]?
    let releases: [MBRelease]?
    let tags: [MBTag]?

    enum CodingKeys: String, CodingKey {
        case title, score, tags
        case firstReleaseDate = "first-release-date"
        case artistCredit     = "artist-credit"
        case releases
    }
}

private struct MBArtistCredit: Codable {
    let artist: MBArtist
}
private struct MBArtist: Codable { let name: String }
private struct MBRelease: Codable { let title: String }
private struct MBTag: Codable { let name: String; let count: Int }

import Foundation

enum YouTubeError: LocalizedError {
    case invalidAPIKey
    case networkError(Error)
    case httpError(Int)
    case noResults
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey: return "YouTube APIキーが設定されていません"
        case .networkError: return "接続を確認してください"
        case .httpError(let code):
            switch code {
            case 400: return "YouTube API: 不正なリクエストです (400)"
            case 403: return "YouTube API認証エラー (403)\nGoogle Cloud Console → APIとサービス → ライブラリ で「YouTube Data API v3」を有効化してください"
            case 429: return "YouTube API: 本日のクォータ上限に達しました (429)"
            default: return "YouTube APIエラー (HTTP \(code))"
            }
        case .noResults: return "動画が見つかりませんでした"
        case .decodingError: return "データの解析に失敗しました"
        }
    }
}

struct YouTubeService {
    static let searchEndpoint = "https://www.googleapis.com/youtube/v3/search"

    static var apiKey: String { AppConfiguration.youtubeAPIKey }

    // MARK: - Known artist list

    private static let knownArtists: [String] = [
        "bad hop", "badhop", "kohh", "loota", "awich", "creepy nuts",
        "r-指定", "dj松永", "舐達麻", "漢 a.k.a. gami", "般若", "zorn", "punpee",
        "仙人掌", "唾奇", "daichi yamamoto", "anarchy", "ak-69", "ak69",
        "seeda", "呂布カルマ", "dotama", "晋平太", "t-pablow", "yzerr",
        "benjazzy", "yellow pato", "tiji jojo", "g-k.i.d", "keny",
        "buddha brand", "rip slyme", "ozrosaurus", "nitro microphone",
        "msc", "kgdr", "キングギドラ", "ライムスター", "rhymester",
        "stillichimiya", "issugi", "jjj", "omsb",
        "showgo", "bim", "bes", "badsaikush", "g-plants",
    ]

    /// Song title → canonical artist reverse-lookup.
    /// Enables artist detection even when only the song title is typed (no artist in query).
    private static let titleToArtist: [String: String] = [
        "kawasaki drift": "BAD HOP",
        "guidance": "BAD HOP",
        "gutta": "BAD HOP",
        "bump": "BAD HOP",
        "stay": "BAD HOP",
        "4 eva": "BAD HOP",
        "city of music": "BAD HOP",
        "never stop": "BAD HOP",
        "monochrome": "KOHH",
        "だいじょうぶ": "KOHH",
        "nobody": "KOHH",
        "bad bitch 美学": "Awich",
        "naked": "Awich",
        "gila": "Awich",
        "equality": "Awich",
        "助演男優賞": "Creepy Nuts",
        "のびしろ": "Creepy Nuts",
        "bling-bang-bang-born": "Creepy Nuts",
        "春の温度": "唾奇",
        "checkmate": "Daichi Yamamoto",
        "夜間飛行": "PUNPEE",
        "voice": "仙人掌",
        "life": "ZORN",
        "hero": "ZORN",
        "稼業": "ZORN",
    ]

    /// Detect artist from a free-form query.
    /// 1. Checks for known artist names directly.
    /// 2. Falls back to song-title → artist reverse-lookup.
    static func extractArtistFromQuery(_ query: String) -> String? {
        let q = query.lowercased()
        if let direct = knownArtists.first(where: { q.contains($0) }) { return direct }
        for (title, artist) in titleToArtist {
            if q.contains(title.lowercased()) { return artist }
        }
        return nil
    }

    // MARK: - Query builder

    /// Build a YouTube search query that always pins the artist name.
    ///
    /// With artist:    "[Artist] [Title] official audio"
    /// Without artist: "[Title] lyric official" (unchanged if already specific)
    /// Battle/event queries are returned as-is.
    static func buildQuery(_ raw: String, artist: String? = nil) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowerRaw = trimmed.lowercased()

        // Battle / event-specific keywords — leave untouched
        let eventKeywords = ["battle", "バトル", "cypher", "サイファー",
                             "freestyle", "フリースタイル", "documentary", "umb", "kok"]
        if eventKeywords.contains(where: { lowerRaw.contains($0) }) { return trimmed }

        if let artist = artist?.trimmingCharacters(in: .whitespacesAndNewlines), !artist.isEmpty {
            let artistLower = artist.lowercased()
            // Always use "[Artist] [Title] official audio" format.
            // If artist is already in the query, don't duplicate it.
            let base = lowerRaw.contains(artistLower) ? trimmed : "\(artist) \(trimmed)"
            return "\(base) official audio"
        }

        // No artist — soft hints only
        let hasHint = ["official", "lyric", "mv"].contains(where: { lowerRaw.contains($0) })
        return hasHint ? trimmed : "\(trimmed) lyric official"
    }

    // MARK: - Jaccard similarity

    static func similarity(_ a: String, _ b: String) -> Double {
        let tokenize: (String) -> Set<String> = { str in
            Set(str.lowercased()
                .components(separatedBy: .alphanumerics.inverted)
                .filter { $0.count >= 2 })
        }
        let ta = tokenize(a)
        let tb = tokenize(b)
        guard !ta.isEmpty || !tb.isEmpty else { return 1.0 }
        return Double(ta.intersection(tb).count) / Double(ta.union(tb).count)
    }

    // MARK: - Search

    static func search(query: String, artist: String? = nil, maxResults: Int = 15) async throws -> [YouTubeVideo] {
        guard !apiKey.isEmpty else { throw YouTubeError.invalidAPIKey }

        let optimizedQuery = buildQuery(query, artist: artist)

        var components = URLComponents(string: searchEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "q", value: optimizedQuery),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "maxResults", value: "\(maxResults)"),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "relevanceLanguage", value: "ja"),
            URLQueryItem(name: "safeSearch", value: "none"),
        ]

        guard let url = components.url else { throw YouTubeError.decodingError }

        var request = URLRequest(url: url)
        if let bundleID = Bundle.main.bundleIdentifier {
            request.setValue(bundleID, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw YouTubeError.networkError(error)
        }

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            let code = httpResponse.statusCode
            if code == 403 {
                var retryRequest = URLRequest(url: request.url!)
                retryRequest.cachePolicy = .reloadIgnoringLocalCacheData
                if let (retryData, retryResponse) = try? await URLSession.shared.data(for: retryRequest),
                   let retryHTTP = retryResponse as? HTTPURLResponse,
                   (200...299).contains(retryHTTP.statusCode) {
                    guard let result = try? JSONDecoder().decode(YouTubeSearchResponse.self, from: retryData) else {
                        throw YouTubeError.decodingError
                    }
                    let videos = result.items.compactMap { $0.toVideo() }
                    guard !videos.isEmpty else { throw YouTubeError.noResults }
                    return filterByRelevance(videos, query: query, artist: artist)
                }
            }
            throw YouTubeError.httpError(code)
        }

        guard let result = try? JSONDecoder().decode(YouTubeSearchResponse.self, from: data) else {
            throw YouTubeError.decodingError
        }

        let videos = result.items.compactMap { $0.toVideo() }
        guard !videos.isEmpty else { throw YouTubeError.noResults }
        return filterByRelevance(videos, query: query, artist: artist)
    }

    // MARK: - Relevance filter

    /// Score videos by how well the video title matches the search query (song title).
    /// The YouTube search query already includes the artist name, so YouTube's own
    /// algorithm handles artist relevance. Here we only care about title matching.
    ///
    /// Rules:
    ///   - Jaccard similarity between video title and query (song title words)
    ///   - Bonus if all query words appear in the video title
    ///   - Karaoke / cover penalty
    ///   - Results sorted by score; at least top results always returned
    private static func filterByRelevance(
        _ videos: [YouTubeVideo],
        query: String,
        artist: String? = nil
    ) -> [YouTubeVideo] {

        // Words from the song title only (not artist) — these must appear in video title
        let queryWords = query.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count >= 2 }

        let noiseTerms = ["カラオケ", "karaoke", "cover", "covers", "tribute",
                          "instrumental", "歌ってみた", "うたってみた", "off vocal"]

        let scored = videos.map { video -> (YouTubeVideo, Double) in
            var score = similarity(video.title, query)
            let titleLower = video.title.lowercased()

            // Bonus when all query words appear in the video title
            if !queryWords.isEmpty {
                let matched = queryWords.filter { titleLower.contains($0) }
                let coverage = Double(matched.count) / Double(queryWords.count)
                if coverage >= 1.0 {
                    score += 0.3   // all words matched
                } else if coverage < 0.4 {
                    score -= 0.2   // too few words matched
                }
            }

            // Karaoke / cover penalty
            if noiseTerms.contains(where: { titleLower.contains($0) }) { score -= 0.5 }

            return (video, score)
        }

        let sorted = scored.sorted { $0.1 > $1.1 }
        let aboveThreshold = sorted.filter { $0.1 >= 0.1 }
        return (aboveThreshold.isEmpty ? Array(sorted.prefix(5)) : aboveThreshold).map { $0.0 }
    }
}

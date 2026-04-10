import Foundation

enum YouTubeError: LocalizedError {
    case invalidAPIKey
    case networkError(Error)
    case httpError(Int)
    case noResults
    case noMatch   // Videos found but none contain both artist + title
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey: return "YouTube APIキーが設定されていません"
        case .networkError: return "接続を確認してください"
        case .httpError(let code):
            switch code {
            case 400: return "YouTube API: 不正なリクエストです (400)"
            case 403: return "YouTube API認証エラー (403)\nGoogle Cloud Console → YouTube Data API v3 を有効化してください"
            case 429: return "YouTube API: 本日のクォータ上限に達しました (429)"
            default:  return "YouTube APIエラー (HTTP \(code))"
            }
        case .noResults: return "動画が見つかりませんでした"
        case .noMatch:   return "一致する公式音源が見つかりませんでした"
        case .decodingError: return "データの解析に失敗しました"
        }
    }
}

struct YouTubeService {
    static let searchEndpoint = "https://www.googleapis.com/youtube/v3/search"
    static var apiKey: String { AppConfiguration.youtubeAPIKey }

    // MARK: - Known artists for query-time detection

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

    /// Song title → canonical artist (reverse lookup).
    private static let titleToArtist: [String: String] = [
        "kawasaki drift": "BAD HOP", "guidance": "BAD HOP", "gutta": "BAD HOP",
        "bump": "BAD HOP", "stay": "BAD HOP", "4 eva": "BAD HOP",
        "city of music": "BAD HOP", "never stop": "BAD HOP", "hollow": "BAD HOP",
        "monochrome": "KOHH", "だいじょうぶ": "KOHH", "nobody": "KOHH",
        "bad bitch 美学": "Awich", "naked": "Awich", "gila": "Awich", "equality": "Awich",
        "助演男優賞": "Creepy Nuts", "のびしろ": "Creepy Nuts", "bling-bang-bang-born": "Creepy Nuts",
        "春の温度": "唾奇", "checkmate": "Daichi Yamamoto",
        "夜間飛行": "PUNPEE", "voice": "仙人掌", "life": "ZORN", "hero": "ZORN", "稼業": "ZORN",
    ]

    static func extractArtistFromQuery(_ query: String) -> String? {
        let q = query.lowercased()
        if let direct = knownArtists.first(where: { q.contains($0) }) { return direct }
        for (title, artist) in titleToArtist { if q.contains(title.lowercased()) { return artist } }
        return nil
    }

    // MARK: - Query builder

    static func buildQuery(_ raw: String, artist: String? = nil) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower   = trimmed.lowercased()

        let eventKeywords = ["battle", "バトル", "cypher", "サイファー",
                             "freestyle", "フリースタイル", "documentary", "umb", "kok"]
        if eventKeywords.contains(where: { lower.contains($0) }) { return trimmed }

        if let artist = artist?.trimmingCharacters(in: .whitespacesAndNewlines), !artist.isEmpty {
            let base = lower.contains(artist.lowercased()) ? trimmed : "\(artist) \(trimmed)"
            return "\(base) Official Audio"
        }

        let hasHint = ["official", "lyric", "mv", "topic"].contains(where: { lower.contains($0) })
        return hasHint ? trimmed : "\(trimmed) Official Audio"
    }

    // MARK: - Jaccard similarity

    static func similarity(_ a: String, _ b: String) -> Double {
        let tok: (String) -> Set<String> = {
            Set($0.lowercased().components(separatedBy: .alphanumerics.inverted).filter { $0.count >= 2 })
        }
        let ta = tok(a); let tb = tok(b)
        guard !ta.isEmpty || !tb.isEmpty else { return 1.0 }
        return Double(ta.intersection(tb).count) / Double(ta.union(tb).count)
    }

    // MARK: - Search

    static func search(query: String, artist: String? = nil, maxResults: Int = 15) async throws -> [YouTubeVideo] {
        guard !apiKey.isEmpty else { throw YouTubeError.invalidAPIKey }

        let optimizedQuery = buildQuery(query, artist: artist)
        var components = URLComponents(string: searchEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "part",             value: "snippet"),
            URLQueryItem(name: "q",                value: optimizedQuery),
            URLQueryItem(name: "type",             value: "video"),
            URLQueryItem(name: "maxResults",       value: "\(maxResults)"),
            URLQueryItem(name: "key",              value: apiKey),
            URLQueryItem(name: "relevanceLanguage", value: "ja"),
            URLQueryItem(name: "safeSearch",       value: "none"),
        ]
        guard let url = components.url else { throw YouTubeError.decodingError }

        var request = URLRequest(url: url)
        if let bundleID = Bundle.main.bundleIdentifier {
            request.setValue(bundleID, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        }

        let data: Data
        let response: URLResponse
        do { (data, response) = try await URLSession.shared.data(for: request) }
        catch { throw YouTubeError.networkError(error) }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let code = http.statusCode
            if code == 403 {
                var retry = URLRequest(url: request.url!)
                retry.cachePolicy = .reloadIgnoringLocalCacheData
                if let (rd, rr) = try? await URLSession.shared.data(for: retry),
                   let rh = rr as? HTTPURLResponse, (200...299).contains(rh.statusCode),
                   let result = try? JSONDecoder().decode(YouTubeSearchResponse.self, from: rd) {
                    let videos = result.items.compactMap { $0.toVideo() }
                    guard !videos.isEmpty else { throw YouTubeError.noResults }
                    return try strictFilter(videos, query: query, artist: artist)
                }
            }
            throw YouTubeError.httpError(code)
        }

        guard let result = try? JSONDecoder().decode(YouTubeSearchResponse.self, from: data) else {
            throw YouTubeError.decodingError
        }
        let videos = result.items.compactMap { $0.toVideo() }
        guard !videos.isEmpty else { throw YouTubeError.noResults }
        return try strictFilter(videos, query: query, artist: artist)
    }

    // MARK: - Strict filter: both artist AND title must appear in video title

    /// Requires the video title to contain both artist words and title words.
    /// If artist is unknown (nil/empty), falls back to title-only check.
    /// Throws `.noMatch` when no video passes — never returns wrong-artist results.
    private static func strictFilter(
        _ videos: [YouTubeVideo],
        query: String,
        artist: String?
    ) throws -> [YouTubeVideo] {

        let artistLower = artist?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let artistWords = artistLower
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count >= 2 }

        let titleWords = query.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count >= 2 }

        let noiseTerms = ["カラオケ", "karaoke", "cover", "covers", "tribute",
                          "instrumental", "歌ってみた", "うたってみた", "off vocal"]

        // ── Pass 1: artist (title OR channel) + all title words in video title ──
        let strict = videos.filter { video in
            let vTitle   = video.title.lowercased()
            let vChannel = video.channelTitle.lowercased()

            // Noise check
            if noiseTerms.contains(where: { vTitle.contains($0) }) { return false }

            // Title words check
            let titleOK = titleWords.isEmpty || titleWords.allSatisfy { vTitle.contains($0) }
            guard titleOK else { return false }

            // Artist check (title OR channel OR Topic auto-gen)
            if !artistLower.isEmpty {
                let artistInTitle   = vTitle.contains(artistLower)
                    || artistWords.contains(where: { vTitle.contains($0) })
                let artistInChannel = vChannel.contains(artistLower)
                    || artistWords.contains(where: { vChannel.contains($0) })
                    || vChannel.hasSuffix("- topic")
                return artistInTitle || artistInChannel
            }
            return true
        }

        if !strict.isEmpty {
            return strict.sorted { similarity($0.title, query) > similarity($1.title, query) }
        }

        // ── Pass 2: title words only (artist may be missing from title — e.g. Topic channel) ──
        let titleOnly = videos.filter { video in
            let vTitle   = video.title.lowercased()
            let vChannel = video.channelTitle.lowercased()
            if noiseTerms.contains(where: { vTitle.contains($0) }) { return false }
            let titleOK = titleWords.isEmpty || titleWords.allSatisfy { vTitle.contains($0) }
            // At minimum the channel must contain an artist word
            let channelOK = artistWords.isEmpty
                || artistWords.contains(where: { vChannel.contains($0) })
                || vChannel.hasSuffix("- topic")
            return titleOK && channelOK
        }

        if !titleOnly.isEmpty {
            return titleOnly.sorted { similarity($0.title, query) > similarity($1.title, query) }
        }

        // ── No match: refuse to serve wrong-artist video ──
        throw YouTubeError.noMatch
    }
}

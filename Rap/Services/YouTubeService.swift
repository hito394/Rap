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

    static var apiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "YOUTUBE_API_KEY") as? String ?? ""
    }

    /// Build an optimized search query.
    /// For music queries, appends "Official Music Video OR Lyric Video OR MV" to surface official content first.
    static func buildQuery(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Avoid double-appending if user already specified video type keywords
        let lowerRaw = trimmed.lowercased()
        let alreadySpecific = ["official", "lyric", "mv", "battle", "バトル", "cypher", "サイファー",
                               "freestyle", "フリースタイル", "documentary"].contains(where: lowerRaw.contains)
        if alreadySpecific { return trimmed }
        return "\(trimmed) Official Music Video OR Lyric Video"
    }

    /// Similarity score between two strings (Jaccard on word tokens, 0.0–1.0).
    static func similarity(_ a: String, _ b: String) -> Double {
        let tokenize: (String) -> Set<String> = { str in
            Set(str.lowercased()
                .components(separatedBy: .alphanumerics.inverted)
                .filter { $0.count >= 2 })
        }
        let ta = tokenize(a)
        let tb = tokenize(b)
        guard !ta.isEmpty || !tb.isEmpty else { return 1.0 }
        let intersection = ta.intersection(tb).count
        let union = ta.union(tb).count
        return Double(intersection) / Double(union)
    }

    static func search(query: String, maxResults: Int = 15) async throws -> [YouTubeVideo] {
        guard !apiKey.isEmpty else { throw YouTubeError.invalidAPIKey }

        let optimizedQuery = buildQuery(query)

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
            if code == 403 && request.value(forHTTPHeaderField: "X-Ios-Bundle-Identifier") != nil {
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
                    return filterByRelevance(videos, query: query)
                }
            }
            throw YouTubeError.httpError(code)
        }

        guard let result = try? JSONDecoder().decode(YouTubeSearchResponse.self, from: data) else {
            throw YouTubeError.decodingError
        }

        let videos = result.items.compactMap { $0.toVideo() }
        guard !videos.isEmpty else { throw YouTubeError.noResults }
        return filterByRelevance(videos, query: query)
    }

    /// Filter out clearly irrelevant results using title similarity.
    /// Keeps results with similarity ≥ 0.1 (very permissive), sorted by relevance.
    private static func filterByRelevance(_ videos: [YouTubeVideo], query: String) -> [YouTubeVideo] {
        let threshold = 0.08
        let scored = videos.map { video -> (YouTubeVideo, Double) in
            let score = similarity(video.title, query)
            return (video, score)
        }
        let filtered = scored.filter { $0.1 >= threshold }
        if filtered.isEmpty { return videos } // fallback: return all if nothing passes
        return filtered.sorted { $0.1 > $1.1 }.map { $0.0 }
    }
}

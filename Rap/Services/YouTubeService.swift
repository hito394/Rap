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

    static func search(query: String, maxResults: Int = 15) async throws -> [YouTubeVideo] {
        guard !apiKey.isEmpty else { throw YouTubeError.invalidAPIKey }

        var components = URLComponents(string: searchEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "maxResults", value: "\(maxResults)"),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "relevanceLanguage", value: "ja"),
            URLQueryItem(name: "safeSearch", value: "none"),
        ]

        guard let url = components.url else { throw YouTubeError.decodingError }

        var request = URLRequest(url: url)
        // Required when API key has iOS app restriction
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
            // If 403 with iOS bundle header, retry without header (in case no restriction is set)
            if code == 403 && request.value(forHTTPHeaderField: "X-Ios-Bundle-Identifier") != nil {
                var retryRequest = URLRequest(url: request.url!)
                retryRequest.cachePolicy = .reloadIgnoringLocalCacheData
                if let (retryData, retryResponse) = try? await URLSession.shared.data(for: retryRequest),
                   let retryHTTP = retryResponse as? HTTPURLResponse,
                   (200...299).contains(retryHTTP.statusCode) {
                    // retry succeeded without header
                    guard let result = try? JSONDecoder().decode(YouTubeSearchResponse.self, from: retryData) else {
                        throw YouTubeError.decodingError
                    }
                    let videos = result.items.compactMap { $0.toVideo() }
                    guard !videos.isEmpty else { throw YouTubeError.noResults }
                    return videos
                }
            }
            throw YouTubeError.httpError(code)
        }

        guard let result = try? JSONDecoder().decode(YouTubeSearchResponse.self, from: data) else {
            throw YouTubeError.decodingError
        }

        let videos = result.items.compactMap { $0.toVideo() }
        guard !videos.isEmpty else { throw YouTubeError.noResults }
        return videos
    }
}

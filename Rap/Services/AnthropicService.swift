import Foundation

enum AnthropicError: LocalizedError {
    case invalidAPIKey
    case networkError(Error)
    case httpError(Int)
    case invalidResponse
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey: return "APIキーが設定されていません"
        case .networkError: return "接続を確認してください"
        case .httpError(let code): return "サーバーエラー (HTTP \(code))"
        case .invalidResponse: return "レスポンスが不正です"
        case .decodingError: return "データの解析に失敗しました"
        }
    }
}

struct AnthropicService {
    static let model = "claude-sonnet-4-20250514"
    static let endpoint = "https://api.anthropic.com/v1/messages"

    static var apiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "ANTHROPIC_API_KEY") as? String ?? ""
    }

    // MARK: - System Prompts

    static let lyricsSystemPrompt = """
あなたはヒップホップのライム技法の専門家です。
入力された歌詞を分析し、以下のJSON形式のみで返してください（コードブロック・前置き不要）:
{
  "rhyme_types": ["技法名"],
  "rhyme_pairs": [{"word1":"","word2":"","type":""}],
  "flow_score": 1〜10,
  "flow_comment": "フロウの評価",
  "highlights": "注目すべき技法の解説",
  "tips": "改善アドバイス"
}
"""

    static let trackSystemPrompt = """
あなたはヒップホップの歴史・文化・リリックに精通した専門家です。
入力された曲名・アーティストについて以下のJSON形式のみで返してください（コードブロック不要）:
{
  "background": "楽曲の背景・制作秘話",
  "era_context": "リリース当時の時代背景・シーン",
  "rhyme_techniques": ["使われているライム技法"],
  "key_bars": [{"bar":"注目バース（原文）","explanation":"解説"}],
  "influences": ["影響を受けたアーティスト・作品"],
  "legacy": "後世への影響・レガシー"
}
"""

    static let freeSystemPrompt = """
あなたはヒップホップ・ラップカルチャーの専門家です。
歴史、ビーフ、アーティスト、スラング、レーベル、サンプリング、リリックの意味など
何でも詳しく、でもカジュアルに解説してください。
日本語で答えてください。マークダウンは使わず、読みやすい自然な文体で。
"""

    // MARK: - API Call

    static func call(system: String, messages: [[String: Any]]) async throws -> String {
        guard !apiKey.isEmpty else { throw AnthropicError.invalidAPIKey }

        guard let url = URL(string: endpoint) else { throw AnthropicError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "system": system,
            "messages": messages
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AnthropicError.networkError(error)
        }

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw AnthropicError.httpError(httpResponse.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let first = content.first,
              let text = first["text"] as? String else {
            throw AnthropicError.invalidResponse
        }

        return text
    }

    // MARK: - Convenience wrappers

    static func analyzeLyrics(_ lyrics: String) async throws -> String {
        let messages: [[String: Any]] = [
            ["role": "user", "content": lyrics]
        ]
        return try await call(system: lyricsSystemPrompt, messages: messages)
    }

    static func decodeTrack(title: String, artist: String) async throws -> String {
        let messages: [[String: Any]] = [
            ["role": "user", "content": "曲名: \(title)\nアーティスト: \(artist)"]
        ]
        return try await call(system: trackSystemPrompt, messages: messages)
    }

    static func freeSearch(conversationHistory: [[String: Any]]) async throws -> String {
        return try await call(system: freeSystemPrompt, messages: conversationHistory)
    }
}

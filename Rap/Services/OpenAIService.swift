import Foundation

struct OpenAIService {
    static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    static var apiKey: String { AppConfiguration.openAIAPIKey }

    static var isAvailable: Bool { !apiKey.isEmpty && apiKey != "your_openai_api_key_here" }

    // MARK: - Core call
    static func call(system: String, messages: [[String: Any]], maxTokens: Int = 4000) async throws -> String {
        guard isAvailable else { throw OpenAIError.missingAPIKey }

        let body: [String: Any] = [
            "model": "gpt-4o",
            "max_tokens": maxTokens,
            "temperature": 0.3,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": system]
            ] + messages
        ]

        let data = try JSONSerialization.data(withJSONObject: body)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (respData, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw OpenAIError.httpError(http.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let content = choices.first?["message"] as? [String: Any],
              let text = content["content"] as? String
        else { throw OpenAIError.invalidResponse }

        return text
    }

    // MARK: - Batch caption technical analysis
    /// GPT-4o: focuses on rhyme structure, flow, punchline technique (technical side).
    /// Returns technique strings per segment index.
    static func analyzeTechnique(
        segments: [CaptionSegment],
        videoTitle: String,
        channel: String,
        onProgress: @escaping (Int, Int) -> Void
    ) async throws -> [Int: String] {
        let batchSize = 40
        var results: [Int: String] = [:]
        var globalIdx = 0

        let batches = stride(from: 0, to: segments.count, by: batchSize).map {
            Array(segments[$0..<min($0 + batchSize, segments.count)])
        }

        let system = """
あなたは日本語MCバトル・ヒップホップの韻律・フロウ分析の専門家です。
動画: 「\(videoTitle)」/ チャンネル: \(channel)

以下のJSONのみで返してください:
{
  "entries": [
    {
      "index": 1,
      "technique": "韻の種類（母音韻/子音韻/マルチシラブル/内部韻等）・踏んでいる具体的な語・フロウの特徴・パンチライン技法を1〜2文で。スラング・隠語があれば（意味）を括弧補足。"
    }
  ]
}
"""

        for (batchNum, batch) in batches.enumerated() {
            let numbered = batch.enumerated().map { i, seg in
                "[\(globalIdx + i + 1)] (\(String(format: "%.1f", seg.start))s) \(seg.text)"
            }.joined(separator: "\n")

            let startIdx = globalIdx + 1
            let resp = try await call(system: system, messages: [
                ["role": "user", "content": "以下\(batch.count)件を分析（index \(startIdx)〜\(startIdx + batch.count - 1)）:\n\(numbered)"]
            ])

            if let data = resp.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let entries = json["entries"] as? [[String: Any]] {
                for e in entries {
                    if let idx = e["index"] as? Int, let tech = e["technique"] as? String {
                        results[idx] = tech
                    }
                }
            }

            globalIdx += batch.count
            onProgress(min((batchNum + 1) * batchSize, segments.count), segments.count)
        }
        return results
    }
}

enum OpenAIError: LocalizedError {
    case missingAPIKey
    case httpError(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "OpenAI APIキーが未設定です (Secrets.xcconfig に OPENAI_API_KEY を追加)"
        case .httpError(let c): return "OpenAI API エラー (HTTP \(c))"
        case .invalidResponse: return "OpenAI レスポンス解析失敗"
        }
    }
}

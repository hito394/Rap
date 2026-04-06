import Foundation

struct OpenAIService {
    static var apiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String ?? ""
    }

    static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    /// Stream a deep-dive GPT-4o response for a lyric line.
    /// Yields text chunks via AsyncThrowingStream.
    static func deepDive(lyric: String, explanation: String, rapper1: String, rapper2: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let system = """
あなたは伝説的なヒップホップライター兼批評家です。
MCバトル「\(rapper1) vs \(rapper2)」の一節について深く掘り下げてください。

以下を含めて詳しく解説してください:
1. 韻の構造（どの音が踏まれているか、母音/子音の一致）
2. パンチラインの多重解釈（表面的意味と隠された意味）
3. 相手へのディスの具体的内容（何を攻撃しているか）
4. 文化的・音楽的リファレンス（サンプリング元、バトル史上の文脈）
5. フロウとリズムパターンの特徴
6. このラインがバトル全体に与えるインパクト

日本語で詳細に解説してください。
"""

                let body: [String: Any] = [
                    "model": "gpt-4o",
                    "stream": true,
                    "max_tokens": 800,
                    "temperature": 0.5,
                    "messages": [
                        ["role": "system", "content": system],
                        ["role": "user", "content": "ライン:「\(lyric)」\n\n基本解説:\(explanation)\n\nこのラインを深く掘り下げてください。"],
                    ]
                ]

                guard !apiKey.isEmpty,
                      let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
                    continuation.finish(throwing: OpenAIError.missingAPIKey)
                    return
                }

                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = jsonData

                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                        continuation.finish(throwing: OpenAIError.httpError(http.statusCode))
                        return
                    }
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" { break }
                        if let data = payload.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let choices = json["choices"] as? [[String: Any]],
                           let delta = choices.first?["delta"] as? [String: Any],
                           let content = delta["content"] as? String {
                            continuation.yield(content)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

enum OpenAIError: LocalizedError {
    case missingAPIKey
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "OpenAI APIキーが設定されていません"
        case .httpError(let code): return "OpenAI APIエラー (HTTP \(code))"
        }
    }
}

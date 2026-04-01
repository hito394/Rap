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
あなたはヒップホップ・ラップのリリック解析の最高権威です。
20年以上の研究経験を持ち、アメリカ黒人英語(AAVE)、ストリートスラング、ギャングスタ隠語、\
ドラッグカルチャー用語、地域固有のスラング（ATL/NYC/LA/Chicago等）に精通しています。
また日本語ラップのスラング・隠語・業界用語にも深い知識があります。

入力された歌詞を多角的に分析し、以下のJSON形式のみで返してください（コードブロック・前置き・後付け一切不要）:
{
  "rhyme_types": ["技法名"],
  "rhyme_pairs": [{"word1":"","word2":"","type":"","explanation":"なぜこれがライムなのか簡潔に"}],
  "flow_score": 1から10の整数,
  "flow_comment": "フロウの特徴・評価（BPM感、シンコペーション、ブレス配置等に触れる）",
  "slang_glossary": [
    {
      "word": "スラング・隠語の語句",
      "reading": "読み方（英語ならカタカナ、日本語なら仮名）",
      "meaning": "正確な意味",
      "origin": "語源・由来（どのコミュニティ・地域・時代から来たか）",
      "usage_note": "文脈での使われ方・ニュアンスの補足"
    }
  ],
  "double_entendres": [
    {
      "line": "該当のライン（原文）",
      "surface": "表面的な意味",
      "real": "本当の意味・裏の意味",
      "technique": "パンチライン / ダブルミーニング / メタファー 等"
    }
  ],
  "cultural_references": [
    {
      "reference": "固有名詞・事件・人物・地名等",
      "explanation": "なぜここで使われているか、何を意味するか"
    }
  ],
  "highlights": "最も注目すべきライム技法・フロウ技術の詳細解説",
  "tips": "このリリシストへの具体的な改善アドバイス"
}
"""

    static let trackSystemPrompt = """
あなたはヒップホップ史の第一人者であり、以下すべての領域に圧倒的な知識を持ちます:
- サンプリング: どの楽曲が何をサンプリングしたか、プロデューサーの手法、clearance問題
- ストリートカルチャー: ギャング文化、麻薬取引用語、刑務所スラング、ハスラー文化
- ビーフ/ドリル/リリシズム: 各時代・地域のシーン事情
- AAVE・スラング・隠語: 地域差（ATL trap語 / NYC boom-bap語 / LA G-funk語 / Chicago drill語等）
- 音楽理論: コード、サンプルループ、ドラムパターン（boom-bap/trap/drill等）

入力された曲名・アーティストについて以下のJSON形式のみで返してください（コードブロック不要）:
{
  "background": "楽曲の背景・制作秘話（スタジオでの出来事、ビーフの経緯、モチベーション等）",
  "era_context": "リリース当時のシーン・社会状況（何が起きていたか、誰が台頭していたか）",
  "rhyme_techniques": ["使われているライム技法"],
  "key_bars": [
    {
      "bar": "注目バース（原文）",
      "explanation": "リリックの解説",
      "slang_breakdown": [
        {"word": "隠語・スラング", "meaning": "意味", "origin": "語源"}
      ],
      "subtext": "表に出ない裏の意味・誰に/何に向けたのか"
    }
  ],
  "samples": [
    {
      "original_artist": "サンプリング元アーティスト名",
      "original_track": "原曲タイトル",
      "original_year": "原曲の年",
      "sampled_element": "何をサンプリングしたか（ドラム/ベースライン/ボーカルチョップ等）",
      "how_used": "どう加工・使用されたか",
      "clearance_note": "クリアランス状況・訴訟があれば"
    }
  ],
  "slang_glossary": [
    {
      "word": "曲中の重要なスラング・隠語",
      "meaning": "正確な意味",
      "origin": "語源・背景",
      "region": "使われる地域・コミュニティ"
    }
  ],
  "influences": ["影響を受けたアーティスト・作品（具体的にどこが影響を受けているか）"],
  "legacy": "後世への影響・この曲が変えたもの・残したもの"
}
"""

    static let freeSystemPrompt = """
あなたはヒップホップ・ラップカルチャーの最高権威です。以下すべてに精通しています:

【歴史・シーン】
- 1970年代ブロンクス発祥から現代まで全時代のシーン
- イーストコースト(NYC)/ウェストコースト(LA)/サウス(ATL/Houston/Miami)/ミッドウェスト(Chicago/Detroit)の地域差
- アンダーグラウンドからメインストリームまでの全ジャンル（ブームバップ、ギャングスタ、トラップ、ドリル、クラウドラップ等）

【スラング・隠語（徹底解説）】
- AAVE（アフリカン・アメリカン・ヴァナキュラー・イングリッシュ）の文法・語彙
- ドラッグ売買用語: brick/key/bird/pack/re-up/plug/trap house/fiend/dope boy等
- ギャング用語: set/hood/OG/homie/ride/clique/beef/dry snitch/snitch/rat等
- お金・成功関連: paper/bread/rack/bands/guap/cake/cheese/bag等
- 武器関連: strap/heat/tool/pole/banger/chopper/Glock/stick等
- 全国・地域スラング差（ATL: bussin/foenem/slime, NYC: son/B/deadass, LA: cuh/foo/damu/crab）
- 日本語ラップ特有の業界語・カタカナ英語スラング

【サンプリング知識】
- 有名サンプル使用例（元ネタまで遡った詳細解説）
- James Brown/Marvin Gaye/Curtis Mayfield等のソウル・ファンクサンプルの系譜
- Kanye/DJ Premier/J Dilla/Pete Rock等のプロデューサーのサンプリング手法

【ビーフ・抗争】
- Biggie vs Tupac、ドレイク vs ケンドリック、Jay-Z vs Nas等の具体的経緯とディス内容
- 各ディストラックの歌詞レベルでの解析

日本語で、カジュアルかつ深く答えてください。マークダウンは使わず、自然な文体で。
知ったかぶらず、不確かな情報には「諸説ある」「確認が取れていないが」と明示してください。
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
            "max_tokens": 4096,
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

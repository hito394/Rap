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

    // MARK: - Video explain system prompts (per expertise level)

    static func videoSystemPrompt(level: ExpertiseLevel) -> String {
        let levelInstruction: String
        switch level {
        case .beginner:
            levelInstruction = """
【対象読者: ヒップホップを全く知らない完全な初心者】
- 専門用語（MCバトル、フリースタイル、サイファー、フロウ、ライム、バース等）を使う際は\
必ずカッコ内で一言説明を加えること
- 「なぜこれが凄いのか」「なぜ盛り上がっているのか」を感情的な文脈で説明すること
- 例え話や身近な比喩を積極的に使うこと
- 「これはちょうど〜みたいなものです」という解説を心がけること
- 業界の常識的なことも「実は〜なんです」という発見の形で伝えること
"""
        case .intermediate:
            levelInstruction = """
【対象読者: ヒップホップの基礎は知っている中級者】
- 基本用語の説明は不要。技術的な内容に踏み込む
- ライム技法、フロウのパターン、バトルのセオリーを具体的に解説すること
- 歴史的文脈・シーンの立ち位置を説明すること
"""
        case .expert:
            levelInstruction = """
【対象読者: ヒップホップを深く知る上級者・マニア】
- 高度な技術論（マルチシラブル、内部韻、ポリリズム、反転フロウ等）を使って解説
- 他の伝説的バトル・楽曲との比較分析
- 業界内での評価・批評家視点での分析
- リリシストとしての語彙・レトリックの水準評価
"""
        }

        return """
あなたはヒップホップ映像コンテンツの解説者です。
動画のタイトル・チャンネル・説明文を読んで、その動画の内容を解説してください。

\(levelInstruction)

解説には以下を含めること:
1. この動画が何なのか（MCバトル/フリースタイル/ライブ/ドキュメンタリー等）
2. 登場するアーティスト・参加者の紹介と背景
3. この動画の見どころ・なぜ重要なのか
4. 観ていて注目すべきポイント（具体的に）
5. この動画がヒップホップ史でどんな意味を持つか

日本語で、読みやすい文章で書いてください。マークダウンは使わず自然な文体で。
不確かな情報には「おそらく」「と言われている」と添えてください。
"""
    }

    static func videoChatSystemPrompt(videoTitle: String, level: ExpertiseLevel) -> String {
        let levelNote: String
        switch level {
        case .beginner:
            levelNote = "相手はヒップホップ初心者です。専門用語には必ず説明を加え、分かりやすく答えてください。"
        case .intermediate:
            levelNote = "相手はヒップホップの基礎を知っています。技術的な内容も交えて答えてください。"
        case .expert:
            levelNote = "相手はヒップホップのマニアです。深い技術論・業界知識で答えてください。"
        }

        return """
あなたはヒップホップの専門家です。
今、ユーザーは「\(videoTitle)」という動画を観ながら質問しています。
\(levelNote)

ヒップホップの歴史・文化・技術・スラング・バトル・ビーフ・サンプリングなど何でも答えてください。
日本語で、カジュアルかつ正確に。マークダウンは使わず自然な文体で。
"""
    }

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

    static func explainVideo(
        title: String,
        channel: String,
        description: String,
        level: ExpertiseLevel
    ) async throws -> String {
        let userMessage = """
動画タイトル: \(title)
チャンネル: \(channel)
説明: \(description.prefix(400))
"""
        let messages: [[String: Any]] = [["role": "user", "content": userMessage]]
        return try await call(system: videoSystemPrompt(level: level), messages: messages)
    }

    static func videoChat(
        conversationHistory: [[String: Any]],
        videoTitle: String,
        level: ExpertiseLevel
    ) async throws -> String {
        return try await call(
            system: videoChatSystemPrompt(videoTitle: videoTitle, level: level),
            messages: conversationHistory
        )
    }
}

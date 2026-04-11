import Foundation

/// Local offline database of Japanese rap / hip-hop tracks.
/// Used as a fallback when iTunes Japan doesn't have a track indexed.
/// Entries have no artwork/preview URLs — the suggestion UI shows a placeholder icon.
struct LocalTrackDatabase {

    // MARK: - Search

    /// Returns up to `limit` tracks whose title contains all `titleWords`
    /// and (when `artist` is provided) whose artist matches.
    static func search(title: String, artist: String = "", limit: Int = 6) -> [iTunesTrack] {
        let titleLower = title.lowercased()
        let artistLower = artist.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        let titleWords = titleLower
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count >= 2 }

        let artistWords = artistLower
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count >= 2 }

        let candidates = tracks.filter { track in
            let tName = track.trackName.lowercased()
            let aName = track.artistName.lowercased()

            // Title must contain all query words
            let titleMatch: Bool
            if titleWords.isEmpty {
                titleMatch = tName.contains(titleLower)
            } else {
                titleMatch = titleWords.allSatisfy { tName.contains($0) }
            }
            guard titleMatch else { return false }

            // Artist filter (optional)
            if !artistLower.isEmpty {
                return aName.contains(artistLower)
                    || artistWords.contains(where: { aName.contains($0) })
            }
            return true
        }

        return Array(candidates.prefix(limit))
    }

    // MARK: - Track list

    private static let tracks: [iTunesTrack] = build()

    private static func build() -> [iTunesTrack] {
        let raw: [(String, String, String)] = [
            // (trackName, artistName, albumName)

            // ── BAD HOP ──────────────────────────────────────────────────────
            ("Kawasaki Drift",        "BAD HOP", "BAD HOP HOUSE"),
            ("Bump",                  "BAD HOP", "BAD HOP HOUSE"),
            ("Stay",                  "BAD HOP", "BAD HOP HOUSE"),
            ("City of Music",         "BAD HOP", "BAD HOP HOUSE"),
            ("Mad Stacks",            "BAD HOP", "BAD HOP HOUSE"),
            ("Money Gang",            "BAD HOP", "BAD HOP HOUSE"),
            ("Guidance",              "BAD HOP", "BAD HOP HOUSE 2"),
            ("Gutta",                 "BAD HOP", "BAD HOP HOUSE 2"),
            ("Neon Light",            "BAD HOP", "BAD HOP HOUSE 2"),
            ("Miserable",             "BAD HOP", "BAD HOP HOUSE 2"),
            ("Red Roses",             "BAD HOP", "BAD HOP HOUSE 2"),
            ("Paper",                 "BAD HOP", "BAD HOP HOUSE 2"),
            ("Chase",                 "BAD HOP", "BAD HOP HOUSE 2"),
            ("4 Eva",                 "BAD HOP", "BAD HOP HOUSE 2"),
            ("Make U Move",           "BAD HOP", "Grateful"),
            ("Tokyo Kissed Me",       "BAD HOP", "Grateful"),
            ("Love Story",            "BAD HOP", "Grateful"),
            ("Champion",              "BAD HOP", "Grateful"),
            ("Bounce",                "BAD HOP", "Grateful"),
            ("Itsuka",                "BAD HOP", "Grateful"),
            ("HOP BOYS",              "BAD HOP", "GOLD DISK"),
            ("GOLD DISK",             "BAD HOP", "GOLD DISK"),
            ("High",                  "BAD HOP", "GOLD DISK"),
            ("Hollow",                "BAD HOP", "GOLD DISK"),
            ("1111",                  "BAD HOP", "GOLD DISK"),
            ("Blow",                  "BAD HOP", "GOLD DISK"),
            ("Never Stop",            "BAD HOP", "GOLD DISK"),
            ("Forever",               "BAD HOP", "GOLD DISK"),
            ("T.P.O",                 "T-Pablow", "T.P.O"),
            ("Flo Rida",              "T-Pablow", "T.P.O"),
            ("YZERR",                 "YZERR", "YZERR"),
            ("ALONE",                 "YZERR", "ALONE"),

            // ── KOHH / Loota ─────────────────────────────────────────────────
            ("だいじょうぶ",            "KOHH", "Monochrome"),
            ("Monochrome",            "KOHH", "Monochrome"),
            ("Dirt Boys",             "KOHH", "Monochrome"),
            ("Yellow Tape",           "KOHH", "Monochrome"),
            ("美しい日本",             "KOHH", "美しい日本"),
            ("Moshi Moshi",           "KOHH", "美しい日本"),
            ("Nobody",                "KOHH", "Nobody"),
            ("Beautiful Word",        "KOHH", "Nobody"),
            ("時間",                   "KOHH", "Untitled"),
            ("Die Young",             "KOHH", "Die Young"),
            ("Jukai",                 "KOHH", "Jukai"),
            ("Dirt",                  "KOHH", "Dirt"),

            // ── Awich ─────────────────────────────────────────────────────────
            ("Bad Bitch 美学",         "Awich", "GIFT"),
            ("Naked",                 "Awich", "Queendom"),
            ("Gila",                  "Awich", "Queendom"),
            ("Equality",              "Awich", "Queendom"),
            ("Queendom",              "Awich", "Queendom"),
            ("New Era",               "Awich", "GIFT"),
            ("Stepper",               "Awich", "GIFT"),
            ("Tempest",               "Awich", "Queendom"),
            ("遺書",                   "Awich", "Queendom"),
            ("縛りたい",               "Awich", "GIFT"),
            ("Shook Ones Pt.II",      "Awich", "Shook Ones Pt.II"),

            // ── Creepy Nuts ───────────────────────────────────────────────────
            ("助演男優賞",             "Creepy Nuts", "Creepy Nuts"),
            ("のびしろ",               "Creepy Nuts", "よふかしのうた"),
            ("Bling-Bang-Bang-Born",  "Creepy Nuts", "Bling-Bang-Bang-Born"),
            ("板の上の魔物",           "Creepy Nuts", "Case"),
            ("かつて天才だった俺たちへ", "Creepy Nuts", "かつて天才だった俺たちへ"),
            ("合法的トビ方ノススメ",   "Creepy Nuts", "合法的トビ方ノススメ"),
            ("刹那",                   "Creepy Nuts", "Creepy Nuts"),
            ("余白",                   "Creepy Nuts", "余白"),
            ("阿婆擦れ",               "Creepy Nuts", "よふかしのうた"),
            ("サントラ",               "Creepy Nuts", "Creepy Nuts"),
            ("生業",                   "Creepy Nuts", "Case"),
            ("かわいいじゃねえか",     "Creepy Nuts", "かわいいじゃねえか"),

            // ── 舐達麻 ────────────────────────────────────────────────────────
            ("FLOATIN'",              "舐達麻", "PHILOSOPHIA"),
            ("GANJA CRUISIN'",        "舐達麻", "PHILOSOPHIA"),
            ("ユレル",                 "舐達麻", "PHILOSOPHIA"),
            ("感覚",                   "舐達麻", "PHILOSOPHIA"),
            ("YBAB",                   "舐達麻", "YBAB"),
            ("G Anthem",              "舐達麻", "PHILOSOPHIA"),
            ("HHH",                   "BES", "HHH"),
            ("在るべき姿",             "BES", "在るべき姿"),

            // ── 漢 a.k.a. GAMI ────────────────────────────────────────────────
            ("大人になれ",             "漢 a.k.a. GAMI", "孤独へのルート"),
            ("天気予報士",             "漢 a.k.a. GAMI", "孤独へのルート"),
            ("ストロング9",            "漢 a.k.a. GAMI", "IN THE NAME OF HIPHOP"),
            ("まだ生きていた",         "漢 a.k.a. GAMI", "孤独へのルート"),
            ("Stay Gold",             "漢 a.k.a. GAMI", "Stay Gold"),
            ("剥きだし",               "MSC", "剥きだし"),

            // ── 般若 ──────────────────────────────────────────────────────────
            ("一番病",                 "般若", "一番病"),
            ("超人",                   "般若", "超人"),
            ("証人",                   "般若", "証人"),
            ("疾走",                   "般若", "疾走"),
            ("ハスリングはやめらんねぇ", "般若", "ハスリングはやめらんねぇ"),
            ("Sick of It",            "般若", "Sick of It"),
            ("東京コンクリートジャングル", "般若", "超人"),

            // ── ZORN ──────────────────────────────────────────────────────────
            ("life",                  "ZORN", "LIFE"),
            ("HERO",                  "ZORN", "HERO"),
            ("稼業",                   "ZORN", "稼業"),
            ("MONEY BACK GUARANTEE", "ZORN", "LIFE"),
            ("25時",                  "ZORN", "LIFE"),
            ("NAN-NAN",               "ZORN", "HERO"),
            ("晴れの特異日",           "ZORN", "HERO"),
            ("大丈夫",                 "ZORN", "HERO"),

            // ── 唾奇 ──────────────────────────────────────────────────────────
            ("春の温度",               "唾奇", "春の温度"),
            ("Alright",               "唾奇", "Alright"),
            ("MEMO",                  "showgo", "MEMO"),
            ("花びら",                 "唾奇", "花びら"),
            ("あの子のこと",           "唾奇", "あの子のこと"),
            ("暁",                     "唾奇", "暁"),
            ("KATACHI",               "唾奇", "KATACHI"),

            // ── Daichi Yamamoto ───────────────────────────────────────────────
            ("Checkmate",             "Daichi Yamamoto", "Checkmate"),
            ("Across the Clouds",     "Daichi Yamamoto", "Across the Clouds"),
            ("Nobody Knows",          "Daichi Yamamoto", "Nobody Knows"),
            ("Gummy",                 "Daichi Yamamoto", "Gummy"),
            ("Hold",                  "Daichi Yamamoto", "Hold"),
            ("Interlude",             "Daichi Yamamoto", "Checkmate"),

            // ── PUNPEE ────────────────────────────────────────────────────────
            ("夜間飛行",               "PUNPEE", "Novel Life"),
            ("Someone's Someone",     "PUNPEE", "Novel Life"),
            ("Novel Life",            "PUNPEE", "Novel Life"),
            ("The Softest",           "PUNPEE", "Novel Life"),
            ("MODERN TIMES",          "PUNPEE", "MODERN TIMES"),
            ("Movie On Friday",       "PUNPEE", "MODERN TIMES"),

            // ── 仙人掌 ────────────────────────────────────────────────────────
            ("VOICE",                 "仙人掌", "VOICE"),
            ("DOOM",                  "仙人掌", "DOOM"),
            ("Dos Mil Cinco",         "仙人掌", "Dos Mil Cinco"),
            ("CALL",                  "仙人掌", "CALL"),
            ("HOOD",                  "仙人掌", "HOOD"),

            // ── Anarchy ───────────────────────────────────────────────────────
            ("The Chase",             "Anarchy", "The Chase"),
            ("Hustle",                "Anarchy", "Hustle"),
            ("Road",                  "Anarchy", "Road"),
            ("Street Life",           "Anarchy", "Street Life"),

            // ── AK-69 ─────────────────────────────────────────────────────────
            ("The Anthem",            "AK-69", "The Anthem"),
            ("Coming Soon",           "AK-69", "Coming Soon"),
            ("One",                   "AK-69", "One"),
            ("Runway of Life",        "AK-69", "Runway of Life"),
            ("Sunrise",               "AK-69", "Sunrise"),
            ("Rising Sun",            "AK-69", "Rising Sun"),

            // ── SEEDA ─────────────────────────────────────────────────────────
            ("HEAVEN",                "SEEDA", "HEAVEN"),
            ("BLUE",                  "SEEDA", "BLUE"),
            ("花と雨",                "SEEDA", "BLUE"),

            // ── 呂布カルマ ────────────────────────────────────────────────────
            ("ガチガチ",               "呂布カルマ", "呂布カルマ"),
            ("俺の話",                 "呂布カルマ", "俺の話"),
            ("言い訳",                 "呂布カルマ", "言い訳"),

            // ── DOTAMA ────────────────────────────────────────────────────────
            ("回文",                   "DOTAMA", "回文"),
            ("DOTAMAの野望",           "DOTAMA", "DOTAMAの野望"),

            // ── 晋平太 ────────────────────────────────────────────────────────
            ("人間失格",               "晋平太", "人間失格"),
            ("PROUD",                  "晋平太", "PROUD"),

            // ── BIM ───────────────────────────────────────────────────────────
            ("The Beam",              "BIM", "The Beam"),
            ("Gravy",                 "BIM", "Gravy"),
            ("Straight Outta",        "BIM", "Straight Outta"),

            // ── issugi ────────────────────────────────────────────────────────
            ("GEMZ",                  "issugi", "GEMZ"),
            ("Neon Sign Ambience",    "issugi", "Neon Sign Ambience"),
            ("Night Renderer",        "issugi", "Night Renderer"),

            // ── JJJ ───────────────────────────────────────────────────────────
            ("P.C.W",                 "JJJ", "P.C.W"),
            ("Mirrors",               "JJJ", "Mirrors"),
            ("HIKARI",                "JJJ", "HIKARI"),

            // ── OMSB ──────────────────────────────────────────────────────────
            ("Mr. Nobody",            "OMSB", "Mr. Nobody"),
            ("Think Good",            "OMSB", "Think Good"),

            // ── KREVA ─────────────────────────────────────────────────────────
            ("イッサイガッサイ",       "KREVA", "心臓"),
            ("国民的行事",             "KREVA", "国民的行事"),
            ("音色",                   "KREVA", "心臓"),
            ("アグレッシ部",           "KREVA", "アグレッシ部"),
            ("基準",                   "KREVA", "基準"),
            ("成長の記録",             "KREVA", "成長の記録 〜一枚のアルバム〜"),
            ("Have a Nice Day!",      "KREVA", "Have a Nice Day!"),
            ("未来の子供たち",         "KREVA", "未来の子供たち"),
            ("その時風が吹いた",       "KREVA", "Heart"),
            ("WORLD'S END",           "KREVA", "WORLD'S END"),
            ("ミラクルが重なって",     "KREVA", "ミラクルが重なって"),
            ("音楽の時間",             "KREVA", "ジョイントのためのジョイント"),
            ("ストロングスタイル",     "KREVA", "ストロングスタイル"),
            ("全速力で",               "KREVA", "全速力で"),

            // ── ライムスター (RHymester) ──────────────────────────────────────
            ("待ってろ今から本気出す",  "ライムスター", "ダンサブル"),
            ("ダンスミュージック",     "ライムスター", "ダンサブル"),
            ("The Choice Is Yours",   "ライムスター", "ダンサブル"),
            ("スタイル・ウォーズ",     "ライムスター", "スタイル・ウォーズ"),
            ("余命宣告",               "ライムスター", "余命宣告"),
            ("B-BOYイズム",            "ライムスター", "B-BOYイズム"),
            ("活字中毒",               "ライムスター", "活字中毒"),
            ("肉体関係",               "ライムスター", "ダンサブル"),
            ("俺たち on the マイク",   "ライムスター", "俺たち on the マイク"),
            ("K.U.F.U.",              "ライムスター", "K.U.F.U."),
            ("サイファー",             "ライムスター", "サイファー"),
            ("ONCE AGAIN",            "ライムスター", "ONCE AGAIN"),
            ("耳ヲ貸スベキ",           "ライムスター", "耳ヲ貸スベキ"),
            ("人間交差点",             "ライムスター", "人間交差点"),
            ("After Dark",            "ライムスター", "After Dark"),

            // ── Zeebra ────────────────────────────────────────────────────────
            ("The Next Level",        "Zeebra", "The Next Level"),
            ("Street Dreams",         "Zeebra", "Street Dreams"),
            ("Galaxy",                "Zeebra", "Galaxy"),
            ("真夜中のサンバ",         "Zeebra", "真夜中のサンバ"),
            ("Knock knock",           "Zeebra", "Knock knock"),

            // ── SOUL'd OUT ────────────────────────────────────────────────────
            ("To The Limit",          "SOUL'd OUT", "To The Limit"),
            ("Rise Up",               "SOUL'd OUT", "Rise Up"),
            ("Shut Up Disco",         "SOUL'd OUT", "Shut Up Disco"),
            ("TOKYO通信 〜Urbs Communication〜", "SOUL'd OUT", "TOKYO通信 〜Urbs Communication〜"),
            ("Starlight Destiny",     "SOUL'd OUT", "Starlight Destiny"),
            ("P.O.I",                 "SOUL'd OUT", "P.O.I"),
            ("COZMO GANGSTAR",        "SOUL'd OUT", "COZMO GANGSTAR"),

            // ── BUDDHA BRAND ──────────────────────────────────────────────────
            ("人間発電所",             "BUDDHA BRAND", "人間発電所"),
            ("病める無限のブッダの世界", "BUDDHA BRAND", "病める無限のブッダの世界"),
            ("Come On Everybody",     "BUDDHA BRAND", "Come On Everybody"),
            ("BUDDHAの教え",          "BUDDHA BRAND", "人間発電所"),

            // ── NITRO MICROPHONE UNDERGROUND ─────────────────────────────────
            ("STRAIGHT FROM THE UNDERGROUND", "NITRO MICROPHONE UNDERGROUND", "STRAIGHT FROM THE UNDERGROUND"),
            ("All Nippon Bad Boys",   "NITRO MICROPHONE UNDERGROUND", "All Nippon Bad Boys"),
            ("VICTORY",               "NITRO MICROPHONE UNDERGROUND", "VICTORY"),
            ("MICROPHONE UNDERGROUND", "NITRO MICROPHONE UNDERGROUND", "MICROPHONE UNDERGROUND"),

            // ── NORIKIYO ──────────────────────────────────────────────────────
            ("地元の空",               "NORIKIYO", "地元の空"),
            ("Solo",                  "NORIKIYO", "Solo"),
            ("都会の夜",               "NORIKIYO", "都会の夜"),
            ("花道",                   "NORIKIYO", "花道"),
            ("俺の歌",                 "NORIKIYO", "俺の歌"),
            ("夢の途中",               "NORIKIYO", "夢の途中"),
            ("横浜B-STYLE",            "NORIKIYO", "横浜B-STYLE"),

            // ── OZROSAURUS / MACCHO ───────────────────────────────────────────
            ("ROLLIN' 045",            "OZROSAURUS", "ROLLIN' 045"),
            ("Knock on the Knockin'", "OZROSAURUS", "Knock on the Knockin'"),
            ("HEAT",                  "OZROSAURUS", "HEAT"),
            ("Oza",                   "OZROSAURUS", "Oza"),
            ("逃げ場なし",             "MACCHO", "逃げ場なし"),

            // ── KID FRESINO ───────────────────────────────────────────────────
            ("Natural Lips",          "KID FRESINO", "Natural Lips"),
            ("ai qing",               "KID FRESINO", "ai qing"),
            ("Coincidence",           "KID FRESINO", "Coincidence"),
            ("20, Stop it.",          "KID FRESINO", "20, Stop it."),
            ("VORE",                  "KID FRESINO", "VORE"),
            ("Retarded Hippie",       "KID FRESINO", "Retarded Hippie"),

            // ── Tha Blue Herb ─────────────────────────────────────────────────
            ("LIFE STORY",            "Tha Blue Herb", "LIFE STORY"),
            ("俺達のバックビート",     "Tha Blue Herb", "俺達のバックビート"),
            ("残響",                   "Tha Blue Herb", "残響"),
            ("夜、街、音楽",           "Tha Blue Herb", "夜、街、音楽"),
            ("RHYME GASM",            "Tha Blue Herb", "RHYME GASM"),
            ("クリスマスがやってくる", "Tha Blue Herb", "クリスマスがやってくる"),
            ("YOUR SONG",             "Tha Blue Herb", "YOUR SONG"),

            // ── GAGLE ─────────────────────────────────────────────────────────
            ("Shinjuku Soul",         "GAGLE", "Shinjuku Soul"),
            ("白黒つけろ",             "GAGLE", "白黒つけろ"),
            ("Phantom",               "GAGLE", "Phantom"),
            ("ラッパーの一人言",       "GAGLE", "ラッパーの一人言"),

            // ── Jin Dogg ──────────────────────────────────────────────────────
            ("WORLDWIDE",             "Jin Dogg", "WORLDWIDE"),
            ("Real Tokyo",            "Jin Dogg", "Real Tokyo"),
            ("OG",                    "Jin Dogg", "OG"),
            ("For Da Homiez",         "Jin Dogg", "For Da Homiez"),
            ("スラング",               "Jin Dogg", "スラング"),

            // ── 鎮座DOPENESS ──────────────────────────────────────────────────
            ("ガリガリ君",             "鎮座DOPENESS", "Freestyle Love"),
            ("いいことあるぞ",         "鎮座DOPENESS", "いいことあるぞ"),
            ("Freestyle Love",        "鎮座DOPENESS", "Freestyle Love"),
            ("LOVE IS THE MESSAGE",   "鎮座DOPENESS", "LOVE IS THE MESSAGE"),
            ("ちかごろ",               "鎮座DOPENESS", "ちかごろ"),

            // ── SHING02 ───────────────────────────────────────────────────────
            ("緑黄色人種",             "SHING02", "緑黄色人種"),
            ("400",                   "SHING02", "400"),
            ("Luv(sic)",              "SHING02", "Luv(sic)"),

            // ── ECD ───────────────────────────────────────────────────────────
            ("おれについてこい",       "ECD", "おれについてこい"),
            ("ロンリー・ガール",       "ECD", "ロンリー・ガール"),
            ("WALK THIS WAY",         "ECD", "WALK THIS WAY"),

            // ── K DUB SHINE ───────────────────────────────────────────────────
            ("King of Kings",         "K DUB SHINE", "King of Kings"),
            ("THE ANTHEM",            "K DUB SHINE", "THE ANTHEM"),
            ("覚醒",                   "K DUB SHINE", "覚醒"),

            // ── DABO ──────────────────────────────────────────────────────────
            ("Higher",                "DABO", "Higher"),
            ("Love So Real",          "DABO", "Love So Real"),
            ("Shinin'",               "DABO", "Shinin'"),
            ("HIT & RUN",             "DABO", "HIT & RUN"),

            // ── MSC ───────────────────────────────────────────────────────────
            ("悪魔を憐れむ詩",         "MSC", "悪魔を憐れむ詩"),
            ("最後の晩餐",             "MSC", "最後の晩餐"),
            ("RED SPIDER",            "MSC", "RED SPIDER"),

            // ── COMA-CHI ──────────────────────────────────────────────────────
            ("FIRE",                  "COMA-CHI", "FIRE"),
            ("BAD GIRL",              "COMA-CHI", "BAD GIRL"),
            ("QUEEN",                 "COMA-CHI", "QUEEN"),

            // ── Maria ─────────────────────────────────────────────────────────
            ("Queen",                 "Maria", "Queen"),
            ("大嫌い",                 "Maria", "大嫌い"),
            ("I'm Real",              "Maria", "I'm Real"),

            // ── LIBRO ─────────────────────────────────────────────────────────
            ("光",                     "LIBRO", "光"),
            ("雑草",                   "LIBRO", "雑草"),
            ("彼女のこと",             "LIBRO", "彼女のこと"),

            // ── SHAKKAZOMBIE ──────────────────────────────────────────────────
            ("SOFA KINGDOM",          "SHAKKAZOMBIE", "SOFA KINGDOM"),
            ("ローリング・ストーン",   "SHAKKAZOMBIE", "ローリング・ストーン"),
            ("Lost In Time",          "SHAKKAZOMBIE", "Lost In Time"),

            // ── 鎮座DOPENESS × HIIMANSHU (共演版) / グループ ────────────────
            ("Just Breathe",          "鎮座DOPENESS", "Just Breathe"),

            // ── METEOR ────────────────────────────────────────────────────────
            ("流れ星",                 "METEOR", "流れ星"),
            ("SHOOTING STAR",         "METEOR", "SHOOTING STAR"),

            // ── Olive Oil ─────────────────────────────────────────────────────
            ("Late Night",            "Olive Oil", "Late Night"),
            ("Soul Cookin'",          "Olive Oil", "Soul Cookin'"),

            // ── Campanella ────────────────────────────────────────────────────
            ("遊んでくれ",             "Campanella", "遊んでくれ"),
            ("クリスタル",             "Campanella", "クリスタル"),
            ("Everything OK",         "Campanella", "Everything OK"),
            ("Surf",                  "Campanella", "Surf"),

            // ── 呂布カルマ (追加) ─────────────────────────────────────────────
            ("チル",                   "呂布カルマ", "チル"),
            ("完全勝利",               "呂布カルマ", "完全勝利"),
            ("名古屋",                 "呂布カルマ", "名古屋"),

            // ── SIMON ─────────────────────────────────────────────────────────
            ("SIMON",                 "SIMON", "SIMON"),
            ("GREATNESS",             "SIMON", "GREATNESS"),

            // ── VaVa ──────────────────────────────────────────────────────────
            ("OSANPO",                "VaVa", "OSANPO"),
            ("ICE PICK",              "VaVa", "ICE PICK"),
            ("TOKYO BANANA",          "VaVa", "TOKYO BANANA"),

            // ── Tohji ─────────────────────────────────────────────────────────
            ("POOL",                  "Tohji", "POOL"),
            ("orion",                 "Tohji", "orion"),
            ("Umi",                   "Tohji", "Umi"),
            ("angel",                 "Tohji", "angel"),
            ("Good Job!",             "Tohji", "Good Job!"),

            // ── KANDYTOWN ─────────────────────────────────────────────────────
            ("Everytime",             "KANDYTOWN", "Kandytown"),
            ("WALK",                  "KANDYTOWN", "Kandytown"),
            ("Old Fashioned",         "KANDYTOWN", "INSIDE"),
            ("Tokyo Skyline",         "KANDYTOWN", "Tokyo Skyline"),
            ("Luv Sick",              "KANDYTOWN", "Luv Sick"),
            ("Indigo",                "KANDYTOWN", "INSIDE"),
            ("New Order",             "KANDYTOWN", "Kandytown"),

            // ── IO ────────────────────────────────────────────────────────────
            ("Passin' Me By",         "IO", "Passin' Me By"),
            ("LAST SMILE",            "IO", "LAST SMILE"),
            ("Nonchalant",            "IO", "Nonchalant"),
            ("DRIFT",                 "IO", "DRIFT"),

            // ── KEIJU ─────────────────────────────────────────────────────────
            ("LOUD",                  "KEIJU", "LOUD"),
            ("OK",                    "KEIJU", "OK"),
            ("黄昏",                   "KEIJU", "黄昏"),

            // ── YOUNG JUJU ────────────────────────────────────────────────────
            ("最後のメッセージ",       "YOUNG JUJU", "最後のメッセージ"),
            ("ことだま",               "YOUNG JUJU", "ことだま"),

            // ── S.L.A.C.K. ────────────────────────────────────────────────────
            ("Good Day",              "S.L.A.C.K.", "Good Day"),
            ("Do It",                 "S.L.A.C.K.", "Do It"),
            ("Vibes",                 "S.L.A.C.K.", "Vibes"),

            // ── Jinmenusagi ───────────────────────────────────────────────────
            ("BABY BASH",             "Jinmenusagi", "BABY BASH"),
            ("Dragon Energy",         "Jinmenusagi", "Dragon Energy"),
            ("WOLF",                  "Jinmenusagi", "WOLF"),

            // ── YZERRソロ追加 ────────────────────────────────────────────────
            ("WAY UP",                "YZERR", "WAY UP"),
            ("Cloud 9",               "YZERR", "Cloud 9"),

            // ── T-Pablow追加 ──────────────────────────────────────────────────
            ("Lifestyle",             "T-Pablow", "Lifestyle"),
            ("Rude Boy",              "T-Pablow", "Rude Boy"),

            // ── GAPPER ────────────────────────────────────────────────────────
            ("GAPPER",                "GAPPER", "GAPPER"),
            ("SAUCE",                 "GAPPER", "SAUCE"),

            // ── Rykey ─────────────────────────────────────────────────────────
            ("AKUMA",                 "Rykey", "AKUMA"),
            ("BLOODY NIGHT",          "Rykey", "BLOODY NIGHT"),
            ("無", "Rykey", "無"),

            // ── MFS ───────────────────────────────────────────────────────────
            ("Intro",                 "MFS", "VISION"),
            ("VISION",                "MFS", "VISION"),

            // ── Fla$hBackS ────────────────────────────────────────────────────
            ("BAYSIDE AREA",          "Fla$hBackS", "BAYSIDE AREA"),
            ("SUMMER MADNESS",        "Fla$hBackS", "SUMMER MADNESS"),
            ("BLOW",                  "Fla$hBackS", "BLOW"),

            // ── 舐達麻追加 ────────────────────────────────────────────────────
            ("LIFE IS SMOKIN'",       "舐達麻", "LIFE IS SMOKIN'"),
            ("POTSHOT",               "舐達麻", "POTSHOT"),
            ("GOOD DAYS",             "舐達麻", "GOOD DAYS"),
            ("DREAM LAND",            "舐達麻", "DREAM LAND"),
            ("ONE LOVE",              "舐達麻", "ONE LOVE"),
            ("THANK YOU FOR THE SMOKE", "舐達麻", "THANK YOU FOR THE SMOKE"),
            ("もう一度",               "舐達麻", "もう一度"),
            ("WEED SMOKER",           "BES", "WEED SMOKER"),
            ("DOGGY STYLE",           "BES", "DOGGY STYLE"),

            // ── KICK THE CAN CREW ─────────────────────────────────────────────
            ("マルシェ",               "KICK THE CAN CREW", "KICK THE CAN CREW"),
            ("イツナロウバ",           "KICK THE CAN CREW", "イツナロウバ"),
            ("SOUND OF LIFE",          "KICK THE CAN CREW", "SOUND OF LIFE"),
            ("classicus",              "KICK THE CAN CREW", "classicus"),
            ("住所不定無職",           "KICK THE CAN CREW", "KICK THE CAN CREW"),
            ("千%",                    "KICK THE CAN CREW", "KICK THE CAN CREW"),
            ("ユーモア",               "KICK THE CAN CREW", "ユーモア"),
            ("sayonara sayonara",      "KICK THE CAN CREW", "classicus"),
            ("かもね",                 "KICK THE CAN CREW", "かもね"),
            ("GOOD TIMES",             "KICK THE CAN CREW", "GOOD TIMES"),
            ("地球ゴマ",               "KICK THE CAN CREW", "地球ゴマ"),
            ("リズム命",               "KICK THE CAN CREW", "KICK THE CAN CREW"),
            ("スタードル",             "KICK THE CAN CREW", "スタードル"),
            ("タカラモノ",             "KICK THE CAN CREW", "タカラモノ"),

            // ── SKY-HI ────────────────────────────────────────────────────────
            ("Marble",                 "SKY-HI", "Marble"),
            ("ナナイロホリデー",       "SKY-HI", "ナナイロホリデー"),
            ("Ordinary Music",         "SKY-HI", "Ordinary Music"),
            ("Fly High",               "SKY-HI", "Fly High"),
            ("Countdown",              "SKY-HI", "Countdown"),
            ("JAPRISON",               "SKY-HI", "JAPRISON"),
            ("方程式",                 "SKY-HI", "方程式"),
            ("Super Fly",              "SKY-HI", "Super Fly"),
            ("24bars to Kill",         "SKY-HI", "24bars to Kill"),
            ("共鳴",                   "SKY-HI", "共鳴"),
            ("Ultra Hyper Loud Bounce", "SKY-HI", "JAPRISON"),
            ("Choose me",              "SKY-HI", "Choose me"),
            ("It's My Story",          "SKY-HI", "It's My Story"),

            // ── Awich追加 ─────────────────────────────────────────────────────
            ("Alarm",                  "Awich", "Alarm"),
            ("Bamboo",                 "Awich", "Queendom"),
            ("UNITY",                  "Awich", "UNITY"),
            ("Pray4U",                 "Awich", "Pray4U"),
            ("WOLF",                   "Awich", "Queendom"),
            ("Haiku",                  "Awich", "Queendom"),
            ("カリスマ",               "Awich", "カリスマ"),
            ("サムライ魂",             "Awich", "サムライ魂"),
            ("Rasen",                  "Awich", "Rasen"),

            // ── Creepy Nuts追加 ───────────────────────────────────────────────
            ("堕天使ダンスホール",     "Creepy Nuts", "かつて天才だった俺たちへ"),
            ("よふかしのうた",         "Creepy Nuts", "よふかしのうた"),
            ("バレる!",               "Creepy Nuts", "バレる!"),
            ("二度寝",                 "Creepy Nuts", "二度寝"),
            ("2way nice guy",          "Creepy Nuts", "2way nice guy"),
            ("土産話",                 "Creepy Nuts", "土産話"),
            ("顔役",                   "Creepy Nuts", "顔役"),
            ("THE HOOK",               "Creepy Nuts", "THE HOOK"),
            ("みんなちがって、みんないい。", "Creepy Nuts", "みんなちがって、みんないい。"),
            ("両成敗でいいじゃない",   "Creepy Nuts", "両成敗でいいじゃない"),

            // ── KOHH追加 ──────────────────────────────────────────────────────
            ("Butterfly",              "KOHH", "Butterfly"),
            ("For Real",               "KOHH", "For Real"),
            ("Don't Be Mad",           "KOHH", "Don't Be Mad"),
            ("Perfect",                "KOHH", "Perfect"),
            ("Blazin'",                "KOHH", "Blazin'"),
            ("Life",                   "KOHH", "Life"),
            ("頑張れ",                 "KOHH", "頑張れ"),
            ("P.O.S",                  "KOHH", "P.O.S"),
            ("花束",                   "KOHH", "花束"),

            // ── ZORN追加 ──────────────────────────────────────────────────────
            ("POPS",                   "ZORN", "POPS"),
            ("ZORNの詩",               "ZORN", "ZORNの詩"),
            ("証人席",                 "ZORN", "証人席"),
            ("夜の詩",                 "ZORN", "夜の詩"),
            ("Ring",                   "ZORN", "Ring"),
            ("FATHER",                 "ZORN", "FATHER"),
            ("PROUD",                  "ZORN", "PROUD"),

            // ── 般若追加 ──────────────────────────────────────────────────────
            ("東京タワー",             "般若", "東京タワー"),
            ("鬼GIRI",                 "般若", "鬼GIRI"),
            ("新宿",                   "般若", "新宿"),
            ("サラバ",                 "般若", "サラバ"),
            ("業",                     "般若", "業"),

            // ── BAD HOP追加 ───────────────────────────────────────────────────
            ("High Hopes",             "BAD HOP", "GOLD DISK"),
            ("Pull Up",                "BAD HOP", "GOLD DISK"),
            ("Japan",                  "BAD HOP", "GOLD DISK"),
            ("Run It",                 "BAD HOP", "BAD HOP HOUSE 2"),
            ("Gang Gang",              "BAD HOP", "BAD HOP HOUSE"),
            ("Keep It 100",            "BAD HOP", "BAD HOP HOUSE"),
            ("No Ceilings",            "BAD HOP", "Grateful"),
            ("Savage",                 "BAD HOP", "Grateful"),
            ("Cold",                   "BAD HOP", "BAD HOP HOUSE 2"),
            ("G Wagon",                "BAD HOP", "GOLD DISK"),

            // ── ライムスター追加 ──────────────────────────────────────────────
            ("世界、西へ",             "ライムスター", "世界、西へ"),
            ("正直者が馬鹿を見た",     "ライムスター", "正直者が馬鹿を見た"),
            ("俺に言わせりゃ",         "ライムスター", "俺に言わせりゃ"),
            ("Still Changing",         "ライムスター", "Still Changing"),
            ("フラッシュバック、フラッシュバック", "ライムスター", "ダンサブル"),
            ("POP LIFE",               "ライムスター", "POP LIFE"),

            // ── Zeebra追加 ────────────────────────────────────────────────────
            ("Hard Knock Days",        "Zeebra", "Hard Knock Days"),
            ("Do What U Gotta Do",     "Zeebra", "Do What U Gotta Do"),
            ("Stompin'",               "Zeebra", "Stompin'"),
            ("JAPANESE HUSTLE",        "Zeebra", "JAPANESE HUSTLE"),

            // ── KREVA追加 ─────────────────────────────────────────────────────
            ("Fly High",               "KREVA", "Fly High"),
            ("東京",                   "KREVA", "東京"),
            ("River",                  "KREVA", "River"),
            ("We're a winner",         "KREVA", "We're a winner"),
            ("千年の孤独",             "KREVA", "千年の孤独"),

            // ── 漢 a.k.a. GAMI追加 ────────────────────────────────────────────
            ("孤独へのルート",         "漢 a.k.a. GAMI", "孤独へのルート"),
            ("The Show Must Go On",    "漢 a.k.a. GAMI", "The Show Must Go On"),
            ("正直者",                 "漢 a.k.a. GAMI", "IN THE NAME OF HIPHOP"),
            ("甘えるな",               "漢 a.k.a. GAMI", "IN THE NAME OF HIPHOP"),
            ("IN THE NAME OF HIPHOP",  "漢 a.k.a. GAMI", "IN THE NAME OF HIPHOP"),

            // ── Daichi Yamamoto追加 ───────────────────────────────────────────
            ("Good Morning",           "Daichi Yamamoto", "Good Morning"),
            ("Broken English",         "Daichi Yamamoto", "Broken English"),
            ("Warm Attire",            "Daichi Yamamoto", "Warm Attire"),
            ("Wavy",                   "Daichi Yamamoto", "Wavy"),
            ("Yen",                    "Daichi Yamamoto", "Yen"),

            // ── PUNPEE追加 ────────────────────────────────────────────────────
            ("Old Friends",            "PUNPEE", "Old Friends"),
            ("Get Ready",              "PUNPEE", "Get Ready"),
            ("Penalty",                "PUNPEE", "Penalty"),
            ("たばこ",                 "PUNPEE", "MODERN TIMES"),
            ("夢追い人",               "PUNPEE", "夢追い人"),
            ("About Love",             "PUNPEE", "About Love"),
            ("Dream",                  "PUNPEE", "Novel Life"),

            // ── 仙人掌追加 ────────────────────────────────────────────────────
            ("PARK",                   "仙人掌", "PARK"),
            ("GHOST",                  "仙人掌", "GHOST"),
            ("COAST",                  "仙人掌", "COAST"),
            ("SUNSET",                 "仙人掌", "SUNSET"),

            // ── AK-69追加 ─────────────────────────────────────────────────────
            ("STRAIGHT UP",            "AK-69", "STRAIGHT UP"),
            ("Chase The Light",        "AK-69", "Chase The Light"),
            ("Beginning",              "AK-69", "Beginning"),
            ("BELIEVE",                "AK-69", "BELIEVE"),
            ("How Do I",               "AK-69", "How Do I"),
            ("Perfect World",          "AK-69", "Perfect World"),

            // ── Anarchy追加 ───────────────────────────────────────────────────
            ("Back to Basics",         "Anarchy", "Back to Basics"),
            ("Real Shit",              "Anarchy", "Real Shit"),
            ("Fly",                    "Anarchy", "Fly"),
            ("Made in Japan",          "Anarchy", "Made in Japan"),
            ("Street Music",           "Anarchy", "Street Music"),

            // ── SEEDA追加 ─────────────────────────────────────────────────────
            ("LIFE",                   "SEEDA", "LIFE"),
            ("PERFECT DAY",            "SEEDA", "PERFECT DAY"),
            ("BEST OF BOTH WORLDS",    "SEEDA", "BEST OF BOTH WORLDS"),
            ("Slow Down",              "SEEDA", "Slow Down"),

            // ── BIM追加 ───────────────────────────────────────────────────────
            ("Borderless",             "BIM", "Borderless"),
            ("LIFEWORK",               "BIM", "LIFEWORK"),
            ("Fly Wit Me",             "BIM", "Fly Wit Me"),
            ("夜に",                   "BIM", "夜に"),
            ("Be OK",                  "BIM", "Be OK"),

            // ── JJJ追加 ───────────────────────────────────────────────────────
            ("TOMAN",                  "JJJ", "TOMAN"),
            ("TEN",                    "JJJ", "TEN"),
            ("Weed & Cigarettes",      "JJJ", "Weed & Cigarettes"),
            ("GOOD MUSIC",             "JJJ", "GOOD MUSIC"),

            // ── issugi追加 ────────────────────────────────────────────────────
            ("King Size",              "issugi", "King Size"),
            ("MONJU",                  "issugi", "MONJU"),

            // ── OMSB追加 ──────────────────────────────────────────────────────
            ("ALONE",                  "OMSB", "ALONE"),
            ("BACK 2 BACK",            "OMSB", "BACK 2 BACK"),
            ("RUN",                    "OMSB", "RUN"),

            // ── Tha Blue Herb追加 ─────────────────────────────────────────────
            ("未来は今、ここに",       "Tha Blue Herb", "未来は今、ここに"),
            ("LATE NIGHT TRAIN",       "Tha Blue Herb", "LATE NIGHT TRAIN"),
            ("STEP BY STEP",           "Tha Blue Herb", "STEP BY STEP"),

            // ── NORIKIYO追加 ──────────────────────────────────────────────────
            ("生き様",                 "NORIKIYO", "生き様"),
            ("CLASSIC",                "NORIKIYO", "CLASSIC"),
            ("FREE STYLE",             "NORIKIYO", "FREE STYLE"),

            // ── KID FRESINO追加 ───────────────────────────────────────────────
            ("Let's Talk",             "KID FRESINO", "Let's Talk"),
            ("After Pool",             "KID FRESINO", "After Pool"),
            ("Sanctuary",              "KID FRESINO", "Sanctuary"),

            // ── GAGLE追加 ─────────────────────────────────────────────────────
            ("Nowhere Man",            "GAGLE", "Nowhere Man"),
            ("Shinto",                 "GAGLE", "Shinto"),
            ("Stay Forever",           "GAGLE", "Stay Forever"),

            // ── MONJU ─────────────────────────────────────────────────────────
            ("2020",                   "MONJU", "2020"),
            ("LAST DANCE",             "MONJU", "LAST DANCE"),
            ("ILLMATIC BARS",          "MONJU", "ILLMATIC BARS"),
            ("JOINT WORK",             "MONJU", "JOINT WORK"),

            // ════════════════════════════════════════════════════════════════════
            // メジャーアーティスト 全曲網羅
            // ════════════════════════════════════════════════════════════════════

            // ── BAD HOP 完全版 ────────────────────────────────────────────────
            ("Beautiful",              "BAD HOP", "BAD HOP HOUSE"),
            ("Lowkey",                 "BAD HOP", "BAD HOP HOUSE"),
            ("Ride",                   "BAD HOP", "BAD HOP HOUSE"),
            ("Tell 'Em",               "BAD HOP", "BAD HOP HOUSE"),
            ("On Top",                 "BAD HOP", "BAD HOP HOUSE 2"),
            ("Side by Side",           "BAD HOP", "BAD HOP HOUSE 2"),
            ("Runnin'",                "BAD HOP", "BAD HOP HOUSE 2"),
            ("Wild Side",              "BAD HOP", "BAD HOP HOUSE 2"),
            ("Better Days",            "BAD HOP", "Grateful"),
            ("Stacks",                 "BAD HOP", "Grateful"),
            ("Way Out",                "BAD HOP", "GOLD DISK"),
            ("Paper Trail",            "BAD HOP", "GOLD DISK"),
            ("Hustle Hard",            "BAD HOP", "GOLD DISK"),
            ("4 Real",                 "BAD HOP", "GOLD DISK"),
            ("Young G's",              "BAD HOP", "BAD HOP HOUSE"),
            ("Intro",                  "BAD HOP", "BAD HOP HOUSE"),
            ("No Flex Zone",           "BAD HOP", "BAD HOP HOUSE 2"),
            ("Represent",              "BAD HOP", "Grateful"),
            ("Dreams",                 "BAD HOP", "Grateful"),
            ("Clouds",                 "BAD HOP", "GOLD DISK"),

            // ── KOHH 完全版 ───────────────────────────────────────────────────
            ("なんでもない",           "KOHH", "なんでもない"),
            ("S/A/K/U/R/A",           "KOHH", "JUKAI"),
            ("蜃気楼",                 "KOHH", "蜃気楼"),
            ("Street Light",           "KOHH", "Street Light"),
            ("My Room",                "KOHH", "My Room"),
            ("NIGHT RIDER",            "KOHH", "NIGHT RIDER"),
            ("LOOTA",                  "KOHH", "Untitled"),
            ("その先へ",               "KOHH", "その先へ"),
            ("Watashi",                "KOHH", "Watashi"),
            ("Raise the Red Flag",     "KOHH", "Raise the Red Flag"),
            ("Today",                  "KOHH", "Today"),
            ("Shine",                  "KOHH", "Shine"),
            ("Precious",               "KOHH", "Precious"),

            // ── Awich 完全版 ──────────────────────────────────────────────────
            ("MY WAY",                 "Awich", "GIFT"),
            ("WELCOME BACK",           "Awich", "WELCOME BACK"),
            ("Big Mouth",              "Awich", "Queendom"),
            ("計画",                   "Awich", "計画"),
            ("雨降れ",                 "Awich", "雨降れ"),
            ("Stoney Road",            "Awich", "Queendom"),
            ("Mic Check",              "Awich", "Mic Check"),
            ("STEP",                   "Awich", "GIFT"),
            ("GOLDEN AGE",             "Awich", "GOLDEN AGE"),
            ("蛍",                     "Awich", "蛍"),
            ("SURVIVOR",               "Awich", "SURVIVOR"),
            ("LINK UP",                "Awich", "LINK UP"),
            ("Queendom II",            "Awich", "Queendom"),
            ("Warrior",                "Awich", "Warrior"),

            // ── Creepy Nuts 完全版 ────────────────────────────────────────────
            ("スポットライト",         "Creepy Nuts", "スポットライト"),
            ("俺・TO・THE・WORLD",     "Creepy Nuts", "俺・TO・THE・WORLD"),
            ("THE ANSWER",             "Creepy Nuts", "THE ANSWER"),
            ("ライオン",               "Creepy Nuts", "ライオン"),
            ("元号",                   "Creepy Nuts", "元号"),
            ("日進月歩",               "Creepy Nuts", "日進月歩"),
            ("MY WAY",                 "Creepy Nuts", "MY WAY"),
            ("ジャンキー",             "Creepy Nuts", "ジャンキー"),
            ("激白",                   "Creepy Nuts", "激白"),
            ("だが情熱はある",         "Creepy Nuts", "だが情熱はある"),
            ("パッと咲いて散って",     "Creepy Nuts", "パッと咲いて散って"),
            ("ホントのこと",           "Creepy Nuts", "ホントのこと"),
            ("かつて天才だった俺たちへ feat. 菅田将暉", "Creepy Nuts", "かつて天才だった俺たちへ"),
            ("Bling-Bang-Bang-Born feat. クレイジーラクーン", "Creepy Nuts", "Bling-Bang-Bang-Born"),
            ("On The Clique",          "Creepy Nuts", "Creepy Nuts"),
            ("キツネ目の男",           "Creepy Nuts", "キツネ目の男"),
            ("4P",                     "Creepy Nuts", "Creepy Nuts"),

            // ── 舐達麻 完全版 ─────────────────────────────────────────────────
            ("TIME IS MONEY",          "舐達麻", "TIME IS MONEY"),
            ("WE GON RIDE",            "舐達麻", "WE GON RIDE"),
            ("まだいける",             "舐達麻", "まだいける"),
            ("CITY OF GOD",            "舐達麻", "CITY OF GOD"),
            ("AREA BOYS",              "舐達麻", "AREA BOYS"),
            ("山手線",                 "舐達麻", "山手線"),
            ("SLOW DOWN",              "舐達麻", "SLOW DOWN"),
            ("SMOKE LIFE",             "舐達麻", "SMOKE LIFE"),
            ("G's UP",                 "舐達麻", "G's UP"),
            ("LOYAL",                  "舐達麻", "LOYAL"),
            ("BUDDA BUDDA",            "舐達麻", "BUDDA BUDDA"),
            ("OUTSIDE",                "舐達麻", "OUTSIDE"),
            ("BLUNTED",                "舐達麻", "BLUNTED"),
            ("GREEN THRONE",           "舐達麻", "GREEN THRONE"),

            // ── KREVA 完全版 ──────────────────────────────────────────────────
            ("過去、現在、未来",       "KREVA", "ジョイントのためのジョイント"),
            ("爆発的スタイル",         "KREVA", "音楽の時間"),
            ("OMB",                    "KREVA", "心臓"),
            ("ヘルシーな娯楽",         "KREVA", "音楽の時間"),
            ("Step By Step",           "KREVA", "Step By Step"),
            ("OK",                     "KREVA", "VOICE"),
            ("Forever Young",          "KREVA", "Forever Young"),
            ("空にまいあがれ",         "KREVA", "空にまいあがれ"),
            ("太陽の光",               "KREVA", "太陽の光"),
            ("STORY",                  "KREVA", "STORY"),
            ("あと一歩",               "KREVA", "あと一歩"),
            ("その先へ",               "KREVA", "心臓"),
            ("不器用",                 "KREVA", "VOICE"),
            ("BIG",                    "KREVA", "BIG"),
            ("日本語で歌う理由",       "KREVA", "ジョイントのためのジョイント"),
            ("ちょうどいい",           "KREVA", "ちょうどいい"),
            ("現在地",                 "KREVA", "現在地"),

            // ── ライムスター 完全版 ───────────────────────────────────────────
            ("ダンサブル",             "ライムスター", "ダンサブル"),
            ("マクガフィン",           "ライムスター", "マクガフィン"),
            ("完全無欠のロックンローラー", "ライムスター", "完全無欠のロックンローラー"),
            ("リスペクト",             "ライムスター", "リスペクト"),
            ("Hold It Down",           "ライムスター", "Hold It Down"),
            ("手を貸してくれ",         "ライムスター", "手を貸してくれ"),
            ("バカにはバカ",           "ライムスター", "バカにはバカ"),
            ("俺たちに明日はない",     "ライムスター", "俺たちに明日はない"),
            ("Bitter, Sweet & Beautiful", "ライムスター", "Bitter, Sweet & Beautiful"),
            ("新しい時代",             "ライムスター", "新しい時代"),
            ("大名行列",               "ライムスター", "大名行列"),
            ("後天性免疫不全症候群",   "ライムスター", "後天性免疫不全症候群"),
            ("ウワサの真相",           "ライムスター", "ウワサの真相"),
            ("ONCE AGAIN feat. SOUL SCREAM", "ライムスター", "ONCE AGAIN"),
            ("夢と現実の間には",       "ライムスター", "夢と現実の間には"),
            ("どぉなってんだ!",       "ライムスター", "どぉなってんだ!"),
            ("グレイゾーン",           "ライムスター", "グレイゾーン"),
            ("Manifesto",              "ライムスター", "Manifesto"),

            // ── 般若 完全版 ───────────────────────────────────────────────────
            ("友達 feat. ZORN",        "般若", "友達"),
            ("三代目 feat. ZORN",      "般若", "三代目"),
            ("HANNYA",                 "般若", "HANNYA"),
            ("ピアノ",                 "般若", "ピアノ"),
            ("盟友",                   "般若", "盟友"),
            ("武士道",                 "般若", "武士道"),
            ("花と太陽と雨と",         "般若", "花と太陽と雨と"),
            ("地球の裏側から",         "般若", "地球の裏側から"),
            ("強く",                   "般若", "強く"),
            ("RAP GAME",               "般若", "RAP GAME"),

            // ── ZORN 完全版 ───────────────────────────────────────────────────
            ("紙とペン",               "ZORN", "紙とペン"),
            ("妻と子",                 "ZORN", "妻と子"),
            ("月の裏側",               "ZORN", "月の裏側"),
            ("一握の砂",               "ZORN", "一握の砂"),
            ("LIFE IS BEAUTIFUL",      "ZORN", "LIFE IS BEAUTIFUL"),
            ("Mr.Criminal",            "ZORN", "Mr.Criminal"),
            ("幸せだ",                 "ZORN", "幸せだ"),
            ("地元",                   "ZORN", "地元"),
            ("卒業",                   "ZORN", "卒業"),
            ("GOOD MORNING",           "ZORN", "GOOD MORNING"),
            ("BARS",                   "ZORN", "BARS"),
            ("ZORN",                   "ZORN", "ZORN"),

            // ── 唾奇 完全版 ───────────────────────────────────────────────────
            ("Fly Away",               "唾奇", "Fly Away"),
            ("大きな木の下で",         "唾奇", "大きな木の下で"),
            ("STAY GOLD",              "唾奇", "STAY GOLD"),
            ("もしも feat. showgo",    "唾奇", "もしも"),
            ("雪の音",                 "唾奇", "雪の音"),
            ("Green",                  "唾奇", "Green"),
            ("余韻",                   "唾奇", "余韻"),
            ("答え合わせ",             "唾奇", "答え合わせ"),
            ("霧雨",                   "唾奇", "霧雨"),
            ("晴天",                   "唾奇", "晴天"),
            ("歩く",                   "唾奇", "歩く"),

            // ── PUNPEE 完全版 ─────────────────────────────────────────────────
            ("灯台",                   "PUNPEE", "灯台"),
            ("Scenes",                 "PUNPEE", "Scenes"),
            ("Cashmere",               "PUNPEE", "Cashmere"),
            ("週末",                   "PUNPEE", "週末"),
            ("ドラえもん",             "PUNPEE", "MODERN TIMES"),
            ("サラウンド",             "PUNPEE", "MODERN TIMES"),
            ("Children",               "PUNPEE", "Novel Life"),
            ("Goodbye",                "PUNPEE", "Novel Life"),
            ("Story of My Life",       "PUNPEE", "Novel Life"),

            // ── 漢 a.k.a. GAMI 完全版 ────────────────────────────────────────
            ("夜の道",                 "漢 a.k.a. GAMI", "孤独へのルート"),
            ("歌舞伎町のヒーロー",     "漢 a.k.a. GAMI", "IN THE NAME OF HIPHOP"),
            ("人生の主役",             "漢 a.k.a. GAMI", "IN THE NAME OF HIPHOP"),
            ("俺が死んでも",           "漢 a.k.a. GAMI", "孤独へのルート"),
            ("Struggle",               "漢 a.k.a. GAMI", "IN THE NAME OF HIPHOP"),
            ("本物",                   "漢 a.k.a. GAMI", "本物"),
            ("孤高",                   "漢 a.k.a. GAMI", "孤高"),

            // ── Zeebra 完全版 ─────────────────────────────────────────────────
            ("This is my word",        "Zeebra", "This is my word"),
            ("Heads Are Gonna Roll",   "Zeebra", "Heads Are Gonna Roll"),
            ("One Love",               "Zeebra", "One Love"),
            ("Hip Hop Gentleman",      "Zeebra", "Hip Hop Gentleman"),
            ("HOOK IT UP",             "Zeebra", "HOOK IT UP"),
            ("The Big E",              "Zeebra", "The Big E"),
            ("Luv Connection",         "Zeebra", "Luv Connection"),

            // ── AK-69 完全版 ──────────────────────────────────────────────────
            ("Breathe",                "AK-69", "Breathe"),
            ("Rain on Fire",           "AK-69", "Rain on Fire"),
            ("Still I Rise",           "AK-69", "Still I Rise"),
            ("I Wish",                 "AK-69", "I Wish"),
            ("Sky's The Limit",        "AK-69", "Sky's The Limit"),
            ("Far East Anthem",        "AK-69", "Far East Anthem"),
            ("Whatcha Gonna Do",       "AK-69", "Whatcha Gonna Do"),
            ("Real feat. WISE",        "AK-69", "Real"),
            ("Crown",                  "AK-69", "Crown"),
            ("All I Got",              "AK-69", "All I Got"),

            // ── Tha Blue Herb 完全版 ──────────────────────────────────────────
            ("NO SUGAR",               "Tha Blue Herb", "NO SUGAR"),
            ("HIGHS & LOWS",           "Tha Blue Herb", "HIGHS & LOWS"),
            ("真冬の横丁",             "Tha Blue Herb", "真冬の横丁"),
            ("終わらない歌",           "Tha Blue Herb", "終わらない歌"),
            ("魂の仕事人",             "Tha Blue Herb", "魂の仕事人"),
            ("漸く", "Tha Blue Herb", "漸く"),
            ("HI HOPES",               "Tha Blue Herb", "HI HOPES"),
            ("DONE",                   "Tha Blue Herb", "DONE"),
            ("STILL STANDING",         "Tha Blue Herb", "STILL STANDING"),
            ("NIGHT AFTER NIGHT",      "Tha Blue Herb", "NIGHT AFTER NIGHT"),

            // ── OZROSAURUS 完全版 ─────────────────────────────────────────────
            ("蒼天",                   "OZROSAURUS", "蒼天"),
            ("CHANT",                  "OZROSAURUS", "CHANT"),
            ("AREA AREA",              "OZROSAURUS", "AREA AREA"),
            ("ROLL ROLL ROLL",         "OZROSAURUS", "ROLL ROLL ROLL"),
            ("GOOD DAY",               "OZROSAURUS", "GOOD DAY"),
            ("Knock Out",              "OZROSAURUS", "Knock Out"),
            ("ROAD",                   "OZROSAURUS", "ROAD"),
            ("THE ANTHEM",             "OZROSAURUS", "THE ANTHEM"),

            // ── NORIKIYO 完全版 ───────────────────────────────────────────────
            ("STORY",                  "NORIKIYO", "STORY"),
            ("愛情の欠片",             "NORIKIYO", "愛情の欠片"),
            ("地元仁義",               "NORIKIYO", "地元仁義"),
            ("そんな夜",               "NORIKIYO", "そんな夜"),
            ("雨のち晴れ",             "NORIKIYO", "雨のち晴れ"),
            ("ずっと",                 "NORIKIYO", "ずっと"),
            ("ALONE",                  "NORIKIYO", "ALONE"),
            ("男の仕事",               "NORIKIYO", "男の仕事"),

            // ── KID FRESINO 完全版 ────────────────────────────────────────────
            ("Cody Banks",             "KID FRESINO", "Cody Banks"),
            ("On and On",              "KID FRESINO", "On and On"),
            ("No Worries",             "KID FRESINO", "No Worries"),
            ("Wake Up",                "KID FRESINO", "Wake Up"),
            ("Luv Me",                 "KID FRESINO", "Luv Me"),
            ("SupremeCredence",        "KID FRESINO", "SupremeCredence"),
            ("KIDS",                   "KID FRESINO", "KIDS"),

            // ── SKY-HI 完全版 ─────────────────────────────────────────────────
            ("SKY'S THE LIMIT",        "SKY-HI", "SKY'S THE LIMIT"),
            ("Snatchaway",             "SKY-HI", "Snatchaway"),
            ("旅は道連れ",             "SKY-HI", "旅は道連れ"),
            ("LOLO",                   "SKY-HI", "LOLO"),
            ("率直",                   "SKY-HI", "率直"),
            ("Free Throw",             "SKY-HI", "Free Throw"),
            ("日本語ラップ",           "SKY-HI", "日本語ラップ"),
            ("OREORE",                 "SKY-HI", "OREORE"),
            ("Bitter & Sweet",         "SKY-HI", "Bitter & Sweet"),
            ("Love Is The Key",        "SKY-HI", "Love Is The Key"),
            ("ビターなのにSweet",       "SKY-HI", "ビターなのにSweet"),

            // ── KICK THE CAN CREW 完全版 ──────────────────────────────────────
            ("俺よ香れ",               "KICK THE CAN CREW", "俺よ香れ"),
            ("サマージャム'98",        "KICK THE CAN CREW", "サマージャム'98"),
            ("Lost And Found",         "KICK THE CAN CREW", "Lost And Found"),
            ("夜空ノムコウ (remix)",   "KICK THE CAN CREW", "夜空ノムコウ"),
            ("1,2,Step!!",             "KICK THE CAN CREW", "1,2,Step!!"),
            ("PUNKS",                  "KICK THE CAN CREW", "PUNKS"),
            ("FLY",                    "KICK THE CAN CREW", "FLY"),
            ("クリスマス",             "KICK THE CAN CREW", "クリスマス"),
            ("NaNaNa",                 "KICK THE CAN CREW", "NaNaNa"),

            // ── SEEDA 完全版 ──────────────────────────────────────────────────
            ("CONCRETE GREEN",         "SEEDA", "CONCRETE GREEN"),
            ("STREET DREAMS",          "SEEDA", "STREET DREAMS"),
            ("HIGHER",                 "SEEDA", "HIGHER"),
            ("REAL",                   "SEEDA", "REAL"),
            ("ROOTS",                  "SEEDA", "ROOTS"),
            ("SHINE",                  "SEEDA", "SHINE"),

            // ── Daichi Yamamoto 完全版 ────────────────────────────────────────
            ("Iridescence",            "Daichi Yamamoto", "Iridescence"),
            ("Ghosts",                 "Daichi Yamamoto", "Ghosts"),
            ("Borderland",             "Daichi Yamamoto", "Borderland"),
            ("Light",                  "Daichi Yamamoto", "Light"),
            ("Circles",                "Daichi Yamamoto", "Circles"),
            ("Slow Motion",            "Daichi Yamamoto", "Slow Motion"),
            ("Shine",                  "Daichi Yamamoto", "Shine"),

            // ── KANDYTOWN 完全版 ──────────────────────────────────────────────
            ("Recognize",              "KANDYTOWN", "INSIDE"),
            ("Freeway",                "KANDYTOWN", "Freeway"),
            ("Twilight",               "KANDYTOWN", "INSIDE"),
            ("Sunset",                 "KANDYTOWN", "Kandytown"),
            ("Palm",                   "KANDYTOWN", "Palm"),
            ("Saturday Night",         "KANDYTOWN", "Saturday Night"),
            ("Gold",                   "KANDYTOWN", "Gold"),

            // ── IO 完全版 ─────────────────────────────────────────────────────
            ("COLORS",                 "IO", "COLORS"),
            ("DAY1",                   "IO", "DAY1"),
            ("Better",                 "IO", "Better"),
            ("Flow",                   "IO", "Flow"),
            ("Nights",                 "IO", "Nights"),

            // ── Anarchy 完全版 ────────────────────────────────────────────────
            ("Kyoto Story",            "Anarchy", "Kyoto Story"),
            ("The Greatest",           "Anarchy", "The Greatest"),
            ("Everyday",               "Anarchy", "Everyday"),
            ("Soul Full",              "Anarchy", "Soul Full"),
            ("Block Party",            "Anarchy", "Block Party"),

            // ── 仙人掌 完全版 ─────────────────────────────────────────────────
            ("GANG",                   "仙人掌", "GANG"),
            ("Dressing Room",          "仙人掌", "Dressing Room"),
            ("終わりにしよう",         "仙人掌", "終わりにしよう"),
            ("SMOKE",                  "仙人掌", "SMOKE"),
            ("LIFE",                   "仙人掌", "LIFE"),

            // ── BIM 完全版 ────────────────────────────────────────────────────
            ("Bboy",                   "BIM", "Bboy"),
            ("Show Time",              "BIM", "Show Time"),
            ("Up in Smoke",            "BIM", "Up in Smoke"),
            ("Seasons",                "BIM", "Seasons"),
            ("Move",                   "BIM", "Move"),

            // ── issugi 完全版 ─────────────────────────────────────────────────
            ("Daily Routine",          "issugi", "Daily Routine"),
            ("Over",                   "issugi", "Over"),
            ("Smoke & Mirrors",        "issugi", "Smoke & Mirrors"),
            ("City",                   "issugi", "City"),

            // ── JJJ 完全版 ────────────────────────────────────────────────────
            ("Chase",                  "JJJ", "Chase"),
            ("Life Goes On",           "JJJ", "Life Goes On"),
            ("Easy",                   "JJJ", "Easy"),
            ("Slide",                  "JJJ", "Slide"),

            // ── OMSB 完全版 ───────────────────────────────────────────────────
            ("New World",              "OMSB", "New World"),
            ("Life's Good",            "OMSB", "Life's Good"),
            ("Fresh",                  "OMSB", "Fresh"),

            // ── 呂布カルマ 完全版 ─────────────────────────────────────────────
            ("ライム・グリーン",       "呂布カルマ", "ライム・グリーン"),
            ("覚悟",                   "呂布カルマ", "覚悟"),
            ("孤高",                   "呂布カルマ", "孤高"),
            ("名古屋城",               "呂布カルマ", "名古屋城"),
            ("天下布武",               "呂布カルマ", "天下布武"),
            ("カルマ",                 "呂布カルマ", "カルマ"),

            // ── Aile The Shota 完全版 ─────────────────────────────────────────
            ("Runway",                 "Aile The Shota", "Runway"),
            ("MIRROR",                 "Aile The Shota", "MIRROR"),
            ("WAVE",                   "Aile The Shota", "WAVE"),
            ("Fly",                    "Aile The Shota", "Fly"),
            ("Dreamin",                "Aile The Shota", "Dreamin"),
            ("FREE",                   "Aile The Shota", "FREE"),

            // ── Tohji 完全版 ──────────────────────────────────────────────────
            ("GOLD",                   "Tohji", "GOLD"),
            ("night",                  "Tohji", "night"),
            ("Cyber",                  "Tohji", "Cyber"),
            ("Love",                   "Tohji", "Love"),
            ("Future",                 "Tohji", "Future"),

            // ── VaVa 完全版 ───────────────────────────────────────────────────
            ("BIG CITY",               "VaVa", "BIG CITY"),
            ("Sunset",                 "VaVa", "Sunset"),
            ("Bounce",                 "VaVa", "Bounce"),
            ("SMOKE",                  "VaVa", "SMOKE"),

            // ── KEIJU 完全版 ──────────────────────────────────────────────────
            ("HIGHER",                 "KEIJU", "HIGHER"),
            ("Dream",                  "KEIJU", "Dream"),
            ("Vibe",                   "KEIJU", "Vibe"),
            ("Love & Rap",             "KEIJU", "Love & Rap"),

            // ── Jin Dogg 完全版 ───────────────────────────────────────────────
            ("4LIFE",                  "Jin Dogg", "4LIFE"),
            ("REPRESENT",              "Jin Dogg", "REPRESENT"),
            ("On the Block",           "Jin Dogg", "On the Block"),
            ("Loyal",                  "Jin Dogg", "Loyal"),

            // ── 鎮座DOPENESS 完全版 ───────────────────────────────────────────
            ("気分次第",               "鎮座DOPENESS", "気分次第"),
            ("Free",                   "鎮座DOPENESS", "Free"),
            ("ハッピーライフ",         "鎮座DOPENESS", "ハッピーライフ"),
            ("遊び場",                 "鎮座DOPENESS", "遊び場"),
            ("コーヒー",               "鎮座DOPENESS", "コーヒー"),

            // ── GAGLE 完全版 ──────────────────────────────────────────────────
            ("My Life",                "GAGLE", "My Life"),
            ("Journey",                "GAGLE", "Journey"),
            ("One Love",               "GAGLE", "One Love"),
            ("Back in the Days",       "GAGLE", "Back in the Days"),

            // ── Fla$hBackS 完全版 ─────────────────────────────────────────────
            ("COLT45",                 "Fla$hBackS", "COLT45"),
            ("EAST SIDE",              "Fla$hBackS", "EAST SIDE"),
            ("FLEX",                   "Fla$hBackS", "FLEX"),
            ("NONSTOP",                "Fla$hBackS", "NONSTOP"),

            // ── S.L.A.C.K. 完全版 ─────────────────────────────────────────────
            ("My Panda",               "S.L.A.C.K.", "My Panda"),
            ("LIFE",                   "S.L.A.C.K.", "LIFE"),
            ("Tight",                  "S.L.A.C.K.", "Tight"),
            ("Summer",                 "S.L.A.C.K.", "Summer"),

            // ── SHAKKAZOMBIE 完全版 ───────────────────────────────────────────
            ("ONCE AND AGAIN",         "SHAKKAZOMBIE", "ONCE AND AGAIN"),
            ("STAY REAL",              "SHAKKAZOMBIE", "STAY REAL"),
            ("Together",               "SHAKKAZOMBIE", "Together"),

            // ── ECD 完全版 ────────────────────────────────────────────────────
            ("Back in the Dayz",       "ECD", "Back in the Dayz"),
            ("失業中",                 "ECD", "失業中"),
            ("LAST NIGHT",             "ECD", "LAST NIGHT"),
            ("Like This",              "ECD", "Like This"),

            // ── K DUB SHINE 完全版 ────────────────────────────────────────────
            ("東京都北区赤羽",         "K DUB SHINE", "東京都北区赤羽"),
            ("MC Battle",              "K DUB SHINE", "MC Battle"),
            ("True True True",         "K DUB SHINE", "True True True"),

            // ── DABO 完全版 ───────────────────────────────────────────────────
            ("Life Goes On",           "DABO", "Life Goes On"),
            ("Real Love",              "DABO", "Real Love"),
            ("Rollin'",                "DABO", "Rollin'"),
            ("BOOM",                   "DABO", "BOOM"),

            // ── MSC 完全版 ────────────────────────────────────────────────────
            ("GHETTO",                 "MSC", "GHETTO"),
            ("眠れない夜",             "MSC", "眠れない夜"),
            ("BAD BOYS",               "MSC", "BAD BOYS"),

            // ── Campanella 完全版 ─────────────────────────────────────────────
            ("Forever Young",          "Campanella", "Forever Young"),
            ("Blessing",               "Campanella", "Blessing"),
            ("Fly",                    "Campanella", "Fly"),
            ("Night Drive",            "Campanella", "Night Drive"),

            // ── YZERR 完全版 ──────────────────────────────────────────────────
            ("RISE",                   "YZERR", "RISE"),
            ("ONE",                    "YZERR", "ONE"),
            ("TOKYO",                  "YZERR", "TOKYO"),
            ("DREAM",                  "YZERR", "DREAM"),
            ("LEVEL UP",               "YZERR", "LEVEL UP"),

            // ── T-Pablow 完全版 ───────────────────────────────────────────────
            ("GANG",                   "T-Pablow", "GANG"),
            ("Money Talks",            "T-Pablow", "Money Talks"),
            ("On Top",                 "T-Pablow", "On Top"),
            ("BARS",                   "T-Pablow", "BARS"),

            // ── BES 完全版 ────────────────────────────────────────────────────
            ("STREET LIFE",            "BES", "STREET LIFE"),
            ("FLOW",                   "BES", "FLOW"),
            ("REAL",                   "BES", "REAL"),

            // ── NORIKIYO × 漢 ─────────────────────────────────────────────────
            ("双頭の鷲",               "NORIKIYO", "双頭の鷲"),
            ("孤独な街",               "漢 a.k.a. GAMI", "孤独な街"),

            // ════════════════════════════════════════════════════════════════════
            // 全曲網羅 追加バッチ
            // ════════════════════════════════════════════════════════════════════

            // ── KICK THE CAN CREW アルバム全曲 ───────────────────────────────
            ("夏の日の午後",           "KICK THE CAN CREW", "KICK THE CAN CREW"),
            ("High Times",             "KICK THE CAN CREW", "classicus"),
            ("まだ見ぬ景色",           "KICK THE CAN CREW", "アンリミテッド"),
            ("Luv Connection",         "KICK THE CAN CREW", "KICK! (THE CAN CREW)"),
            ("天体観測 (remix)",       "KICK THE CAN CREW", "classicus"),
            ("FLY feat. SKY-HI",       "KICK THE CAN CREW", "KICK! (THE CAN CREW)"),
            ("Night Life",             "KICK THE CAN CREW", "アンリミテッド"),
            ("FAMILY",                 "KICK THE CAN CREW", "アンリミテッド"),
            ("LIFE IS GOOD",           "KICK THE CAN CREW", "アンリミテッド"),
            ("ファントム",             "KICK THE CAN CREW", "classicus"),
            ("Candy",                  "KICK THE CAN CREW", "KICK THE CAN CREW"),
            ("グッドモーニング",       "KICK THE CAN CREW", "KICK! (THE CAN CREW)"),

            // ── ライムスター アルバム全曲 ─────────────────────────────────────
            ("俺たちは幸せ",           "ライムスター", "ダンサブル"),
            ("回る、バラバラに",       "ライムスター", "ダンサブル"),
            ("二人ゲーム",             "ライムスター", "マニフェスト"),
            ("よしきた!",             "ライムスター", "マニフェスト"),
            ("眩しくて見えない",       "ライムスター", "マニフェスト"),
            ("老害ジジイ",             "ライムスター", "老害ジジイ"),
            ("ONCE AGAIN",             "ライムスター", "ONCE AGAIN"),
            ("完全無欠",               "ライムスター", "完全無欠のロックンローラー"),
            ("どーせ死ぬなら",         "ライムスター", "どーせ死ぬなら"),
            ("HANDS",                  "ライムスター", "HANDS"),
            ("Bitter",                 "ライムスター", "Bitter, Sweet & Beautiful"),
            ("Sweet",                  "ライムスター", "Bitter, Sweet & Beautiful"),
            ("Beautiful",              "ライムスター", "Bitter, Sweet & Beautiful"),
            ("ONCE AGAIN feat. ACE", "ライムスター", "ONCE AGAIN"),
            ("ラジオ",                 "ライムスター", "ラジオ"),

            // ── BAD HOP 全シングル・アルバム曲 ───────────────────────────────
            ("Perfect",                "BAD HOP", "Perfect"),
            ("Everyday",               "BAD HOP", "Everyday"),
            ("Glow Up",                "BAD HOP", "GOLD DISK"),
            ("Flex",                   "BAD HOP", "GOLD DISK"),
            ("Broken Hearts",          "BAD HOP", "Grateful"),
            ("Stars",                  "BAD HOP", "Grateful"),
            ("Superstar",              "BAD HOP", "BAD HOP HOUSE 2"),
            ("Work Hard",              "BAD HOP", "BAD HOP HOUSE"),
            ("Intro (BAD HOP HOUSE)",  "BAD HOP", "BAD HOP HOUSE"),
            ("Way Back Home",          "BAD HOP", "Grateful"),
            ("Count Up",               "BAD HOP", "GOLD DISK"),
            ("Good Life",              "BAD HOP", "BAD HOP HOUSE 2"),
            ("まだ途中",               "BAD HOP", "まだ途中"),
            ("LAST DANCE",             "BAD HOP", "LAST DANCE"),

            // ── KOHH 全プロジェクト ───────────────────────────────────────────
            ("PUNKS NOT DEAD",         "KOHH", "PUNKS NOT DEAD"),
            ("夏",                     "KOHH", "夏"),
            ("ALIVE",                  "KOHH", "ALIVE"),
            ("COLORS",                 "KOHH", "COLORS"),
            ("HIGHER",                 "KOHH", "HIGHER"),
            ("愛 (Love)",              "KOHH", "愛"),
            ("WHAT WOULD YOU DO",      "KOHH", "WHAT WOULD YOU DO"),
            ("Shine Brighter",         "KOHH", "Shine Brighter"),
            ("Friends & Foes",         "KOHH", "Friends & Foes"),
            ("Never Say Die",          "KOHH", "Never Say Die"),
            ("Run",                    "KOHH", "Run"),
            ("OCEAN",                  "KOHH", "OCEAN"),
            ("WAVE",                   "KOHH", "WAVE"),

            // ── Awich 全プロジェクト ──────────────────────────────────────────
            ("Feel Da Vibe",           "Awich", "GIFT"),
            ("Power",                  "Awich", "Power"),
            ("BACK IT UP",             "Awich", "BACK IT UP"),
            ("No Pressure",            "Awich", "No Pressure"),
            ("Badder",                 "Awich", "Badder"),
            ("WELCOME 2 MY WORLD",     "Awich", "Queendom"),
            ("Hold Me Down",           "Awich", "Hold Me Down"),
            ("BIG MOUTH HOOK",         "Awich", "Queendom"),
            ("Queendom Intro",         "Awich", "Queendom"),
            ("TIME IS MONEY",          "Awich", "GIFT"),
            ("All I Know",             "Awich", "All I Know"),
            ("Pray4Me",                "Awich", "GIFT"),

            // ── Creepy Nuts 全シングル・アルバム曲 ───────────────────────────
            ("出来心",                 "Creepy Nuts", "出来心"),
            ("耳なし芳一",             "Creepy Nuts", "耳なし芳一"),
            ("グレートな誰かになれなかった俺たちへ", "Creepy Nuts", "かつて天才だった俺たちへ"),
            ("トレンチコート",         "Creepy Nuts", "トレンチコート"),
            ("夜が明けたら、いちばんに君に会いにいく", "Creepy Nuts", "夜が明けたら、いちばんに君に会いにいく"),
            ("Bling-Bang-Bang-Born (Remix)", "Creepy Nuts", "Bling-Bang-Bang-Born"),
            ("堕天使ダンスホール feat. 中島美嘉", "Creepy Nuts", "かつて天才だった俺たちへ"),
            ("のびしろ (アニメ Ver.)", "Creepy Nuts", "よふかしのうた"),
            ("報道のロックンロール",   "Creepy Nuts", "Case"),
            ("甘い罠",                 "Creepy Nuts", "甘い罠"),
            ("解体新書",               "Creepy Nuts", "Creepy Nuts"),
            ("のびしろ feat. 菅田将暉", "Creepy Nuts", "よふかしのうた"),

            // ── 舐達麻 全プロジェクト ─────────────────────────────────────────
            ("RIDE OR DIE",            "舐達麻", "RIDE OR DIE"),
            ("PLUG WALK",              "舐達麻", "PLUG WALK"),
            ("SATIVA",                 "舐達麻", "SATIVA"),
            ("HIGH LIFE",              "舐達麻", "HIGH LIFE"),
            ("MEDITATION",             "舐達麻", "MEDITATION"),
            ("COSMIC",                 "舐達麻", "COSMIC"),
            ("EUPHORIA",               "舐達麻", "EUPHORIA"),
            ("CHRONIC",                "舐達麻", "CHRONIC"),
            ("420",                    "舐達麻", "420"),
            ("STAY SMOKIN'",           "舐達麻", "STAY SMOKIN'"),
            ("VIBE",                   "舐達麻", "VIBE"),
            ("PARADISE",               "舐達麻", "PARADISE"),

            // ── KREVA 全アルバム曲 ────────────────────────────────────────────
            ("あれから",               "KREVA", "VOICE"),
            ("太陽",                   "KREVA", "心臓"),
            ("PRIDE",                  "KREVA", "PRIDE"),
            ("シャウト",               "KREVA", "心臓"),
            ("友達じゃないのに",       "KREVA", "友達じゃないのに"),
            ("ONCE",                   "KREVA", "ONCE"),
            ("アゲイン",               "KREVA", "アゲイン"),
            ("街の灯り",               "KREVA", "街の灯り"),
            ("SUMMER BACK",            "KREVA", "SUMMER BACK"),
            ("生きていく",             "KREVA", "生きていく"),
            ("愛・自分博",             "KREVA", "ジョイントのためのジョイント"),
            ("少年ジャンプ",           "KREVA", "音楽の時間"),
            ("音楽の日",               "KREVA", "音楽の時間"),
            ("一番高い場所",           "KREVA", "一番高い場所"),
            ("嬉しいんだ!",           "KREVA", "嬉しいんだ!"),
            ("WINNER feat. ZEEBRA",    "KREVA", "心臓"),

            // ── 般若 全アルバム曲 ─────────────────────────────────────────────
            ("ルードボーイ",           "般若", "ルードボーイ"),
            ("今夜は帰れない",         "般若", "今夜は帰れない"),
            ("Back in the Hood",       "般若", "Back in the Hood"),
            ("武蔵野",                 "般若", "武蔵野"),
            ("下北沢",                 "般若", "下北沢"),
            ("歌舞伎町",               "般若", "歌舞伎町"),
            ("仁義",                   "般若", "仁義"),
            ("Unbroken",               "般若", "Unbroken"),
            ("ただ生きる",             "般若", "ただ生きる"),
            ("友達 II",                "般若", "友達 II"),
            ("男の子",                 "般若", "男の子"),
            ("月明かり",               "般若", "月明かり"),
            ("REAL",                   "般若", "REAL"),
            ("証人 II",                "般若", "証人 II"),

            // ── ZORN 全アルバム曲 ─────────────────────────────────────────────
            ("GLORY",                  "ZORN", "GLORY"),
            ("KING SIZE",              "ZORN", "HERO"),
            ("RISE AND FALL",          "ZORN", "RISE AND FALL"),
            ("夜中の散歩",             "ZORN", "夜中の散歩"),
            ("STREET DREAMS",          "ZORN", "STREET DREAMS"),
            ("年中夢求",               "ZORN", "年中夢求"),
            ("NEIGHBORHOOD",           "ZORN", "NEIGHBORHOOD"),
            ("GOLD",                   "ZORN", "GOLD"),
            ("RAP LIFE",               "ZORN", "RAP LIFE"),
            ("成長",                   "ZORN", "成長"),
            ("俺はここにいる",         "ZORN", "俺はここにいる"),
            ("本物",                   "ZORN", "本物"),

            // ── 唾奇 全プロジェクト ───────────────────────────────────────────
            ("Luv Is True",            "唾奇", "Luv Is True"),
            ("Blue Bird",              "唾奇", "Blue Bird"),
            ("Tomorrow",               "唾奇", "Tomorrow"),
            ("Colors",                 "唾奇", "Colors"),
            ("Shine",                  "唾奇", "Shine"),
            ("夜の終わり",             "唾奇", "夜の終わり"),
            ("月の光",                 "唾奇", "月の光"),
            ("真昼の月",               "唾奇", "真昼の月"),
            ("流れ星",                 "唾奇", "流れ星"),

            // ── PUNPEE 全プロジェクト ─────────────────────────────────────────
            ("アウト×デラックス",      "PUNPEE", "アウト×デラックス"),
            ("One Day",                "PUNPEE", "One Day"),
            ("Yesterday",              "PUNPEE", "Yesterday"),
            ("Weekend",                "PUNPEE", "Weekend"),
            ("Scenes II",              "PUNPEE", "Scenes"),
            ("Stardust",               "PUNPEE", "Stardust"),
            ("Forever",                "PUNPEE", "MODERN TIMES"),
            ("Keep It Movin'",         "PUNPEE", "MODERN TIMES"),

            // ── 漢 a.k.a. GAMI 全アルバム曲 ──────────────────────────────────
            ("真剣師",                 "漢 a.k.a. GAMI", "真剣師"),
            ("仁義",                   "漢 a.k.a. GAMI", "仁義"),
            ("日本語ラップ",           "漢 a.k.a. GAMI", "IN THE NAME OF HIPHOP"),
            ("FREESTYLE 2020",         "漢 a.k.a. GAMI", "FREESTYLE"),
            ("魂胆",                   "漢 a.k.a. GAMI", "魂胆"),
            ("先輩",                   "漢 a.k.a. GAMI", "先輩"),
            ("俺の流儀",               "漢 a.k.a. GAMI", "IN THE NAME OF HIPHOP"),
            ("言葉は刃",               "漢 a.k.a. GAMI", "言葉は刃"),

            // ── Zeebra 全シングル・アルバム曲 ────────────────────────────────
            ("Rogue",                  "Zeebra", "Rogue"),
            ("Make A Move",            "Zeebra", "Make A Move"),
            ("Keep It Real",           "Zeebra", "Keep It Real"),
            ("Trill",                  "Zeebra", "Trill"),
            ("Japanese Hip Hop",       "Zeebra", "Japanese Hip Hop"),
            ("音楽",                   "Zeebra", "音楽"),
            ("Daddy's Home",           "Zeebra", "Daddy's Home"),
            ("Joy",                    "Zeebra", "Joy"),

            // ── AK-69 全シングル・アルバム曲 ─────────────────────────────────
            ("Love the Life I Live",   "AK-69", "Love the Life I Live"),
            ("Free Falling",           "AK-69", "Free Falling"),
            ("THE WAY",                "AK-69", "THE WAY"),
            ("Never Give Up",          "AK-69", "Never Give Up"),
            ("THE ANTHEM II",          "AK-69", "THE ANTHEM II"),
            ("Sparks",                 "AK-69", "Sparks"),
            ("Higher Ground",          "AK-69", "Higher Ground"),
            ("Walk Tall",              "AK-69", "Walk Tall"),
            ("Fire",                   "AK-69", "Fire"),
            ("King of The City",       "AK-69", "King of The City"),

            // ── SOUL'd OUT 全シングル・アルバム曲 ────────────────────────────
            ("Somewhere Someday",      "SOUL'd OUT", "Somewhere Someday"),
            ("PERFECT WORLD",          "SOUL'd OUT", "PERFECT WORLD"),
            ("Bless Your Breath",      "SOUL'd OUT", "Bless Your Breath"),
            ("Renegade",               "SOUL'd OUT", "Renegade"),
            ("VOODOO KINGDOM",         "SOUL'd OUT", "VOODOO KINGDOM"),
            ("Rollin' Days",           "SOUL'd OUT", "Rollin' Days"),
            ("MUSIC INSIDE",           "SOUL'd OUT", "MUSIC INSIDE"),

            // ── NITRO MICROPHONE UNDERGROUND 全曲 ────────────────────────────
            ("SHOW TIME",              "NITRO MICROPHONE UNDERGROUND", "SHOW TIME"),
            ("STILL REAL",             "NITRO MICROPHONE UNDERGROUND", "STILL REAL"),
            ("HIGH TILL I DIE",        "NITRO MICROPHONE UNDERGROUND", "HIGH TILL I DIE"),
            ("KEEP IT REAL",           "NITRO MICROPHONE UNDERGROUND", "KEEP IT REAL"),

            // ── BUDDHA BRAND 全曲 ─────────────────────────────────────────────
            ("DON'T TEST DA MASTER",   "BUDDHA BRAND", "DON'T TEST DA MASTER"),
            ("BUDDHA BRAND",           "BUDDHA BRAND", "BUDDHA BRAND"),
            ("無常の世界",             "BUDDHA BRAND", "無常の世界"),

            // ── Tha Blue Herb 全プロジェクト ──────────────────────────────────
            ("二人の距離は",           "Tha Blue Herb", "二人の距離は"),
            ("TRUE NORTH",             "Tha Blue Herb", "TRUE NORTH"),
            ("LIFE STORY II",          "Tha Blue Herb", "LIFE STORY II"),
            ("FAREWELL",               "Tha Blue Herb", "FAREWELL"),
            ("SOMEWHERE",              "Tha Blue Herb", "SOMEWHERE"),
            ("ORDINARY DAYS",          "Tha Blue Herb", "ORDINARY DAYS"),
            ("REAL WORLD",             "Tha Blue Herb", "REAL WORLD"),
            ("SONG",                   "Tha Blue Herb", "SONG"),

            // ── NORIKIYO 全アルバム曲 ─────────────────────────────────────────
            ("情",                     "NORIKIYO", "情"),
            ("絆",                     "NORIKIYO", "絆"),
            ("夢の続き",               "NORIKIYO", "夢の続き"),
            ("日々",                   "NORIKIYO", "日々"),
            ("ありがとう",             "NORIKIYO", "ありがとう"),
            ("ただそれだけ",           "NORIKIYO", "ただそれだけ"),
            ("信念",                   "NORIKIYO", "信念"),

            // ── OZROSAURUS 全アルバム曲 ───────────────────────────────────────
            ("OZROSAURUSの逆襲",       "OZROSAURUS", "OZROSAURUSの逆襲"),
            ("BELIEVE",                "OZROSAURUS", "BELIEVE"),
            ("FLOW OF THE MUSIC",      "OZROSAURUS", "FLOW OF THE MUSIC"),
            ("WORD IS BOND",           "OZROSAURUS", "WORD IS BOND"),
            ("REAL",                   "OZROSAURUS", "REAL"),
            ("LIFE",                   "OZROSAURUS", "LIFE"),
            ("湘南",                   "OZROSAURUS", "湘南"),

            // ── KID FRESINO 全アルバム曲 ──────────────────────────────────────
            ("Smile",                  "KID FRESINO", "Smile"),
            ("Float",                  "KID FRESINO", "Float"),
            ("2020 feat. 仙人掌",      "KID FRESINO", "2020"),
            ("Before The Season",      "KID FRESINO", "Before The Season"),
            ("Vision",                 "KID FRESINO", "Vision"),
            ("Glow",                   "KID FRESINO", "Glow"),

            // ── SEEDA 全アルバム曲 ────────────────────────────────────────────
            ("IN MY CITY",             "SEEDA", "IN MY CITY"),
            ("LOVE & HIP HOP",         "SEEDA", "LOVE & HIP HOP"),
            ("TOGETHER",               "SEEDA", "TOGETHER"),
            ("MOMENT",                 "SEEDA", "MOMENT"),
            ("SUNLIGHT",               "SEEDA", "SUNLIGHT"),

            // ── SKY-HI 全シングル・アルバム曲 ────────────────────────────────
            ("声",                     "SKY-HI", "声"),
            ("TONDEMO WANDERS",        "SKY-HI", "TONDEMO WANDERS"),
            ("Dressed Up",             "SKY-HI", "Dressed Up"),
            ("Get Away",               "SKY-HI", "Get Away"),
            ("All Alone",              "SKY-HI", "All Alone"),
            ("Make It Better",         "SKY-HI", "Make It Better"),
            ("Sky's The Limit",        "SKY-HI", "Sky's The Limit"),
            ("CIEL",                   "SKY-HI", "CIEL"),
            ("Snatchaway feat. PUSHIM", "SKY-HI", "Snatchaway"),
            ("愛の続き",               "SKY-HI", "愛の続き"),

            // ── Anarchy 全アルバム曲 ──────────────────────────────────────────
            ("Timeless",               "Anarchy", "Timeless"),
            ("Champion",               "Anarchy", "Champion"),
            ("No Way Out",             "Anarchy", "No Way Out"),
            ("Hustle & Flow",          "Anarchy", "Hustle & Flow"),
            ("Just Do It",             "Anarchy", "Just Do It"),

            // ── 仙人掌 全アルバム曲 ───────────────────────────────────────────
            ("TOWER",                  "仙人掌", "TOWER"),
            ("SUNDAY",                 "仙人掌", "SUNDAY"),
            ("MORNING",                "仙人掌", "MORNING"),
            ("CITY BLUES",             "仙人掌", "CITY BLUES"),

            // ── KANDYTOWN 全アルバム曲 ────────────────────────────────────────
            ("Life Goes On",           "KANDYTOWN", "INSIDE"),
            ("Gimme That",             "KANDYTOWN", "Kandytown"),
            ("Slow Jam",               "KANDYTOWN", "Slow Jam"),
            ("The Night",              "KANDYTOWN", "The Night"),
            ("Summer Breeze",          "KANDYTOWN", "Summer Breeze"),

            // ── IO 全アルバム曲 ───────────────────────────────────────────────
            ("Intro",                  "IO", "INTRODUCE"),
            ("Motion",                 "IO", "Motion"),
            ("Back to Back",           "IO", "Back to Back"),
            ("Higher",                 "IO", "Higher"),

            // ── BIM 全アルバム曲 ──────────────────────────────────────────────
            ("Drift",                  "BIM", "Drift"),
            ("LIFE",                   "BIM", "LIFE"),
            ("Vision",                 "BIM", "Vision"),
            ("Summer Love",            "BIM", "Summer Love"),
            ("Circles",                "BIM", "Circles"),

            // ── JJJ 全アルバム曲 ──────────────────────────────────────────────
            ("CITY",                   "JJJ", "CITY"),
            ("SUNDAY",                 "JJJ", "SUNDAY"),
            ("Smooth",                 "JJJ", "Smooth"),
            ("Blue",                   "JJJ", "Blue"),
            ("Night",                  "JJJ", "Night"),

            // ── issugi 全アルバム曲 ───────────────────────────────────────────
            ("FIRST STEP",             "issugi", "FIRST STEP"),
            ("MONDAY",                 "issugi", "MONDAY"),
            ("Street Vision",          "issugi", "Street Vision"),
            ("Cold World",             "issugi", "Cold World"),

            // ── OMSB 全アルバム曲 ─────────────────────────────────────────────
            ("Good Day",               "OMSB", "Good Day"),
            ("Power",                  "OMSB", "Power"),
            ("Summer",                 "OMSB", "Summer"),
            ("Life",                   "OMSB", "Life"),

            // ── 呂布カルマ 全アルバム曲 ───────────────────────────────────────
            ("自由人",                 "呂布カルマ", "自由人"),
            ("逆境",                   "呂布カルマ", "逆境"),
            ("凡人",                   "呂布カルマ", "凡人"),
            ("根性",                   "呂布カルマ", "根性"),
            ("喝采",                   "呂布カルマ", "喝采"),

            // ── 田我流 ────────────────────────────────────────────────────────
            ("B BOY STANCE",           "田我流", "B BOY STANCE"),
            ("文化的雪かき",           "田我流", "文化的雪かき"),
            ("Rollin' Days",           "田我流", "Rollin' Days"),
            ("GOOD LIFE",              "田我流", "GOOD LIFE"),
            ("あるがまま",             "田我流", "あるがまま"),
            ("CHANGE THE WORLD",       "田我流", "CHANGE THE WORLD"),
            ("ロックスター",           "田我流", "ロックスター"),
            ("Fly Away",               "田我流", "Fly Away"),
            ("なんくるないさ",         "田我流", "なんくるないさ"),
            ("Bless",                  "田我流", "Bless"),

            // ── DOTAMA 全アルバム曲 ───────────────────────────────────────────
            ("シャバドゥビ",           "DOTAMA", "シャバドゥビ"),
            ("フリースタイル道場",     "DOTAMA", "フリースタイル道場"),
            ("天才",                   "DOTAMA", "天才"),
            ("現実逃避",               "DOTAMA", "現実逃避"),

            // ── 晋平太 全アルバム曲 ───────────────────────────────────────────
            ("生きろ",                 "晋平太", "生きろ"),
            ("Hip Hop is Art",         "晋平太", "Hip Hop is Art"),
            ("俺は俺だ",               "晋平太", "俺は俺だ"),
            ("少年",                   "晋平太", "少年"),
            ("感謝",                   "晋平太", "感謝"),

            // ── Daichi Yamamoto 全アルバム曲 ─────────────────────────────────
            ("Mirror",                 "Daichi Yamamoto", "Mirror"),
            ("Diamond",                "Daichi Yamamoto", "Diamond"),
            ("Emerald",                "Daichi Yamamoto", "Emerald"),
            ("Crystal",                "Daichi Yamamoto", "Crystal"),
            ("Rain",                   "Daichi Yamamoto", "Rain"),
            ("Tokyo Life",             "Daichi Yamamoto", "Tokyo Life"),

            // ── GAGLE 全アルバム曲 ────────────────────────────────────────────
            ("GOOD TIMES",             "GAGLE", "GOOD TIMES"),
            ("FUTURE",                 "GAGLE", "FUTURE"),
            ("CITY",                   "GAGLE", "CITY"),
            ("REAL",                   "GAGLE", "REAL"),
            ("FLOW",                   "GAGLE", "FLOW"),

            // ── Campaenlla 全アルバム曲 ───────────────────────────────────────
            ("Voyage",                 "Campanella", "Voyage"),
            ("Daydream",               "Campanella", "Daydream"),
            ("Shine On",               "Campanella", "Shine On"),
            ("Mellow",                 "Campanella", "Mellow"),

            // ── S.L.A.C.K. 全アルバム曲 ───────────────────────────────────────
            ("CHILL",                  "S.L.A.C.K.", "CHILL"),
            ("PEACE",                  "S.L.A.C.K.", "PEACE"),
            ("EASY",                   "S.L.A.C.K.", "EASY"),
            ("REAL LIFE",              "S.L.A.C.K.", "REAL LIFE"),

            // ── Jin Dogg 全アルバム曲 ─────────────────────────────────────────
            ("STREETS",                "Jin Dogg", "STREETS"),
            ("PLUG",                   "Jin Dogg", "PLUG"),
            ("DAY ONE",                "Jin Dogg", "DAY ONE"),
            ("TRAP",                   "Jin Dogg", "TRAP"),

            // ── 鎮座DOPENESS 全アルバム曲 ────────────────────────────────────
            ("VOICE",                  "鎮座DOPENESS", "VOICE"),
            ("PEACE",                  "鎮座DOPENESS", "PEACE"),
            ("LOVE",                   "鎮座DOPENESS", "LOVE"),
            ("LIFE IS BEAUTIFUL",      "鎮座DOPENESS", "LIFE IS BEAUTIFUL"),
            ("REAL",                   "鎮座DOPENESS", "REAL"),

            // ── Fla$hBackS 全アルバム曲 ───────────────────────────────────────
            ("INTRO",                  "Fla$hBackS", "INTRO"),
            ("OUTRO",                  "Fla$hBackS", "OUTRO"),
            ("ROLL CALL",              "Fla$hBackS", "ROLL CALL"),
            ("HUSTLE",                 "Fla$hBackS", "HUSTLE"),

            // ── KEIJU 全アルバム曲 ────────────────────────────────────────────
            ("FREE",                   "KEIJU", "FREE"),
            ("YOUNG",                  "KEIJU", "YOUNG"),
            ("ZONE",                   "KEIJU", "ZONE"),

            // ── VaVa 全アルバム曲 ─────────────────────────────────────────────
            ("CLOUD",                  "VaVa", "CLOUD"),
            ("LIGHT",                  "VaVa", "LIGHT"),
            ("FLOW",                   "VaVa", "FLOW"),

            // ── Tohji 全アルバム曲 ────────────────────────────────────────────
            ("Moon",                   "Tohji", "Moon"),
            ("Star",                   "Tohji", "Star"),
            ("Sun",                    "Tohji", "Sun"),
            ("Sky",                    "Tohji", "Sky"),

            // ── Aile The Shota 全アルバム曲 ───────────────────────────────────
            ("Glow",                   "Aile The Shota", "Glow"),
            ("Rise",                   "Aile The Shota", "Rise"),
            ("Life",                   "Aile The Shota", "Life"),

            // ── YOUNG JUJU 全アルバム曲 ───────────────────────────────────────
            ("街",                     "YOUNG JUJU", "街"),
            ("流れ",                   "YOUNG JUJU", "流れ"),
            ("My Story",               "YOUNG JUJU", "My Story"),
            ("Believe",                "YOUNG JUJU", "Believe"),

            // ── Jinmenusagi 全アルバム曲 ──────────────────────────────────────
            ("SHARK",                  "Jinmenusagi", "SHARK"),
            ("CROCODILE",              "Jinmenusagi", "CROCODILE"),
            ("SNAKE",                  "Jinmenusagi", "SNAKE"),
            ("LION",                   "Jinmenusagi", "LION"),

            // ── YZERR 全アルバム曲 ────────────────────────────────────────────
            ("FLEX",                   "YZERR", "FLEX"),
            ("RICH",                   "YZERR", "RICH"),
            ("GANG",                   "YZERR", "GANG"),
            ("TRAP",                   "YZERR", "TRAP"),

            // ── T-Pablow 全アルバム曲 ─────────────────────────────────────────
            ("CASH",                   "T-Pablow", "CASH"),
            ("FLEX",                   "T-Pablow", "FLEX"),
            ("WAVE",                   "T-Pablow", "WAVE"),
            ("DRIP",                   "T-Pablow", "DRIP"),

            // ── BES 全アルバム曲 ──────────────────────────────────────────────
            ("ZONE",                   "BES", "ZONE"),
            ("GANJA",                  "BES", "GANJA"),
            ("SMOKE",                  "BES", "SMOKE"),

            // ── DABO 全アルバム曲 ─────────────────────────────────────────────
            ("HUSTLE HUSTLE",          "DABO", "HUSTLE HUSTLE"),
            ("STAY UP",                "DABO", "STAY UP"),
            ("WINNER",                 "DABO", "WINNER"),

            // ── K DUB SHINE 全アルバム曲 ──────────────────────────────────────
            ("KINGDOM",                "K DUB SHINE", "KINGDOM"),
            ("REAL TALK",              "K DUB SHINE", "REAL TALK"),
            ("LEGEND",                 "K DUB SHINE", "LEGEND"),

            // ── ECD 全アルバム曲 ──────────────────────────────────────────────
            ("BREAK THROUGH",          "ECD", "BREAK THROUGH"),
            ("声よ届け",               "ECD", "声よ届け"),
            ("時代",                   "ECD", "時代"),
            ("生きている",             "ECD", "生きている"),

            // ── COMA-CHI 全アルバム曲 ─────────────────────────────────────────
            ("RISE",                   "COMA-CHI", "RISE"),
            ("WARRIOR",                "COMA-CHI", "WARRIOR"),
            ("FLOW",                   "COMA-CHI", "FLOW"),

            // ── LIBRO 全アルバム曲 ────────────────────────────────────────────
            ("VOICE",                  "LIBRO", "VOICE"),
            ("LIFE",                   "LIBRO", "LIFE"),
            ("空",                     "LIBRO", "空"),
            ("愛",                     "LIBRO", "愛"),

            // ── MSC 全アルバム曲 ──────────────────────────────────────────────
            ("CITY",                   "MSC", "CITY"),
            ("TOKYO",                  "MSC", "TOKYO"),
            ("STORY",                  "MSC", "STORY"),

            // ── SHAKKAZOMBIE 全アルバム曲 ─────────────────────────────────────
            ("REAL UNDERGROUND",       "SHAKKAZOMBIE", "REAL UNDERGROUND"),
            ("FUTURE",                 "SHAKKAZOMBIE", "FUTURE"),
            ("MOVE",                   "SHAKKAZOMBIE", "MOVE"),

            // ── SHING02 全アルバム曲 ──────────────────────────────────────────
            ("Luv(sic) Part 2",        "SHING02", "Luv(sic)"),
            ("Luv(sic) Part 3",        "SHING02", "Luv(sic)"),
            ("Luv(sic) Grand Finale",  "SHING02", "Luv(sic)"),
            ("EQUBS",                  "SHING02", "EQUBS"),
            ("Tokio",                  "SHING02", "Tokio"),

            // ── GAPPER 全アルバム曲 ───────────────────────────────────────────
            ("DRIP",                   "GAPPER", "DRIP"),
            ("WAVE",                   "GAPPER", "WAVE"),
            ("FLEX",                   "GAPPER", "FLEX"),

            // ── Rykey 全アルバム曲 ────────────────────────────────────────────
            ("NIGHTMARE",              "Rykey", "NIGHTMARE"),
            ("DARK",                   "Rykey", "DARK"),
            ("DEMON",                  "Rykey", "DEMON"),

            // ════════════════════════════════════════════════════════════════════
            // 純ヒップホップ 新規アーティスト大量追加
            // ════════════════════════════════════════════════════════════════════

            // ── 5lack ─────────────────────────────────────────────────────────
            ("新しいブルース",         "5lack", "新しいブルース"),
            ("Season",                 "5lack", "Season"),
            ("Summer Interlude",       "5lack", "Interlude"),
            ("Stitches",               "5lack", "Stitches"),
            ("Blank",                  "5lack", "Blank"),
            ("Focus",                  "5lack", "Focus"),
            ("Driftin",                "5lack", "Driftin"),
            ("Clouds",                 "5lack", "Clouds"),
            ("Therapy",                "5lack", "Therapy"),
            ("Good Day",               "5lack", "Good Day"),
            ("Wasted",                 "5lack", "Wasted"),
            ("Rain",                   "5lack", "Rain"),
            ("Late Night",             "5lack", "Late Night"),
            ("Chill",                  "5lack", "Chill"),
            ("Blue",                   "5lack", "Blue"),

            // ── WILYWNKA ──────────────────────────────────────────────────────
            ("SILVER",                 "WILYWNKA", "SILVER"),
            ("CASANOVA",               "WILYWNKA", "CASANOVA"),
            ("GALAXY",                 "WILYWNKA", "GALAXY"),
            ("MY WAY",                 "WILYWNKA", "MY WAY"),
            ("TRAP STAR",              "WILYWNKA", "TRAP STAR"),
            ("FLEXIN",                 "WILYWNKA", "FLEXIN"),
            ("TOKYO NIGHT",            "WILYWNKA", "TOKYO NIGHT"),
            ("DRIP",                   "WILYWNKA", "DRIP"),
            ("WAVE",                   "WILYWNKA", "WAVE"),
            ("COLD",                   "WILYWNKA", "COLD"),
            ("REAL",                   "WILYWNKA", "REAL"),
            ("SMOKE",                  "WILYWNKA", "SMOKE"),

            // ── SALU ──────────────────────────────────────────────────────────
            ("In My Life",             "SALU", "In My Life"),
            ("GOLDEN TIME",            "SALU", "GOLDEN TIME"),
            ("BODY",                   "SALU", "BODY"),
            ("ONE",                    "SALU", "ONE"),
            ("Better Days",            "SALU", "Better Days"),
            ("Beautiful",              "SALU", "Beautiful"),
            ("Summer Time",            "SALU", "Summer Time"),
            ("Forever",                "SALU", "Forever"),
            ("Sunshine",               "SALU", "Sunshine"),
            ("All I Need",             "SALU", "All I Need"),
            ("Ordinary",               "SALU", "Ordinary"),
            ("Tokyo",                  "SALU", "Tokyo"),
            ("Life Goes On",           "SALU", "Life Goes On"),

            // ── KEN THE 390 ───────────────────────────────────────────────────
            ("明日天気になれ",         "KEN THE 390", "明日天気になれ"),
            ("Yeh Yeh Yeh",            "KEN THE 390", "Yeh Yeh Yeh"),
            ("Super Hard",             "KEN THE 390", "Super Hard"),
            ("We Love Hip Hop",        "KEN THE 390", "We Love Hip Hop"),
            ("Life",                   "KEN THE 390", "Life"),
            ("Countdown",              "KEN THE 390", "Countdown"),
            ("Champion",               "KEN THE 390", "Champion"),
            ("Tokyo",                  "KEN THE 390", "Tokyo"),
            ("Real Talk",              "KEN THE 390", "Real Talk"),
            ("BEST",                   "KEN THE 390", "BEST"),
            ("GANG",                   "KEN THE 390", "GANG"),
            ("HUSTLE",                 "KEN THE 390", "HUSTLE"),

            // ── HAIIRO DE ROSSI ───────────────────────────────────────────────
            ("Free",                   "HAIIRO DE ROSSI", "Free"),
            ("Mind",                   "HAIIRO DE ROSSI", "Mind"),
            ("City",                   "HAIIRO DE ROSSI", "City"),
            ("Blue",                   "HAIIRO DE ROSSI", "Blue"),
            ("Rain",                   "HAIIRO DE ROSSI", "Rain"),
            ("Flow",                   "HAIIRO DE ROSSI", "Flow"),
            ("Life",                   "HAIIRO DE ROSSI", "Life"),
            ("Dream",                  "HAIIRO DE ROSSI", "Dream"),
            ("Vision",                 "HAIIRO DE ROSSI", "Vision"),
            ("Soul",                   "HAIIRO DE ROSSI", "Soul"),

            // ── KOWICHI ───────────────────────────────────────────────────────
            ("KOWICHI",                "KOWICHI", "KOWICHI"),
            ("HIGH END",               "KOWICHI", "HIGH END"),
            ("FLEX",                   "KOWICHI", "FLEX"),
            ("DRIP",                   "KOWICHI", "DRIP"),
            ("BOSS",                   "KOWICHI", "BOSS"),
            ("RICH",                   "KOWICHI", "RICH"),
            ("GANG",                   "KOWICHI", "GANG"),
            ("WAVE",                   "KOWICHI", "WAVE"),
            ("LIFESTYLE",              "KOWICHI", "LIFESTYLE"),
            ("MONEY",                  "KOWICHI", "MONEY"),

            // ── GRADIS NICE ───────────────────────────────────────────────────
            ("Nice Day",               "GRADIS NICE", "Nice Day"),
            ("Sunny Side",             "GRADIS NICE", "Sunny Side"),
            ("Smooth",                 "GRADIS NICE", "Smooth"),
            ("Easy",                   "GRADIS NICE", "Easy"),
            ("Mellow",                 "GRADIS NICE", "Mellow"),
            ("Flow",                   "GRADIS NICE", "Flow"),
            ("Summer",                 "GRADIS NICE", "Summer"),

            // ── BRON-K ────────────────────────────────────────────────────────
            ("BRON-K",                 "BRON-K", "BRON-K"),
            ("Real",                   "BRON-K", "Real"),
            ("Hustle",                 "BRON-K", "Hustle"),
            ("BARS",                   "BRON-K", "BARS"),
            ("Street",                 "BRON-K", "Street"),
            ("Grind",                  "BRON-K", "Grind"),

            // ── DARTHREIDER ───────────────────────────────────────────────────
            ("人生はリベンジマッチ",   "DARTHREIDER", "人生はリベンジマッチ"),
            ("東京、東京",             "DARTHREIDER", "東京、東京"),
            ("My Story",               "DARTHREIDER", "My Story"),
            ("Life",                   "DARTHREIDER", "Life"),
            ("声",                     "DARTHREIDER", "声"),
            ("夢",                     "DARTHREIDER", "夢"),
            ("FREESTYLE",              "DARTHREIDER", "FREESTYLE"),

            // ── RINO LATINA II ────────────────────────────────────────────────
            ("Rino",                   "RINO LATINA II", "Rino"),
            ("Queen",                  "RINO LATINA II", "Queen"),
            ("Flow",                   "RINO LATINA II", "Flow"),
            ("Real",                   "RINO LATINA II", "Real"),
            ("Mic Check",              "RINO LATINA II", "Mic Check"),

            // ── TWIGY ─────────────────────────────────────────────────────────
            ("TWIGY",                  "TWIGY", "TWIGY"),
            ("Flex",                   "TWIGY", "Flex"),
            ("Real",                   "TWIGY", "Real"),
            ("Street",                 "TWIGY", "Street"),
            ("Flow",                   "TWIGY", "Flow"),
            ("Bars",                   "TWIGY", "Bars"),

            // ── G.RINA ────────────────────────────────────────────────────────
            ("Paradise",               "G.RINA", "Paradise"),
            ("Sunflower",              "G.RINA", "Sunflower"),
            ("Love",                   "G.RINA", "Love"),
            ("Flow",                   "G.RINA", "Flow"),
            ("City",                   "G.RINA", "City"),

            // ── Shingo Nishinari ──────────────────────────────────────────────
            ("西成ブルース",           "Shingo Nishinari", "西成ブルース"),
            ("大阪",                   "Shingo Nishinari", "大阪"),
            ("REAL",                   "Shingo Nishinari", "REAL"),
            ("生きる",                 "Shingo Nishinari", "生きる"),
            ("路地裏",                 "Shingo Nishinari", "路地裏"),
            ("魂",                     "Shingo Nishinari", "魂"),
            ("地元",                   "Shingo Nishinari", "地元"),
            ("ブルース",               "Shingo Nishinari", "ブルース"),

            // ── HUNGER (from GAGLE) ───────────────────────────────────────────
            ("Hunger",                 "HUNGER", "Hunger"),
            ("Real",                   "HUNGER", "Real"),
            ("Flow",                   "HUNGER", "Flow"),
            ("Mic",                    "HUNGER", "Mic"),

            // ── DJ KOCO a.k.a. SHIMOKITA ──────────────────────────────────────
            ("Shimokita",              "DJ KOCO a.k.a. SHIMOKITA", "Shimokita"),
            ("Crate Digger",           "DJ KOCO a.k.a. SHIMOKITA", "Crate Digger"),

            // ── KOHEI JAPAN ───────────────────────────────────────────────────
            ("Japanese Hip Hop",       "KOHEI JAPAN", "Japanese Hip Hop"),
            ("Street Level",           "KOHEI JAPAN", "Street Level"),
            ("Bars",                   "KOHEI JAPAN", "Bars"),
            ("Flow",                   "KOHEI JAPAN", "Flow"),

            // ── ELIONE ────────────────────────────────────────────────────────
            ("Real Hip Hop",           "ELIONE", "Real Hip Hop"),
            ("Flow",                   "ELIONE", "Flow"),
            ("Street",                 "ELIONE", "Street"),

            // ── FORK (from GAGLE) ─────────────────────────────────────────────
            ("Fork",                   "FORK", "Fork"),
            ("My Life",                "FORK", "My Life"),
            ("Street",                 "FORK", "Street"),

            // ── MACCHO (from OZROSAURUS) ──────────────────────────────────────
            ("MACCHO",                 "MACCHO", "MACCHO"),
            ("Flow",                   "MACCHO", "Flow"),
            ("Real",                   "MACCHO", "Real"),
            ("Street",                 "MACCHO", "Street"),

            // ── GAPPER追加 ───────────────────────────────────────────────────
            ("PLUG",                   "GAPPER", "PLUG"),
            ("MONEY FLOW",             "GAPPER", "MONEY FLOW"),
            ("STEPPER",                "GAPPER", "STEPPER"),
            ("ON MY WAY",              "GAPPER", "ON MY WAY"),

            // ── Rykey追加 ─────────────────────────────────────────────────────
            ("GHOST",                  "Rykey", "GHOST"),
            ("SHADOW",                 "Rykey", "SHADOW"),
            ("FIRE",                   "Rykey", "FIRE"),
            ("RAGE",                   "Rykey", "RAGE"),

            // ── MFS追加 ───────────────────────────────────────────────────────
            ("DRIFT",                  "MFS", "DRIFT"),
            ("FLOW",                   "MFS", "FLOW"),
            ("ZONE",                   "MFS", "ZONE"),
            ("CITY",                   "MFS", "CITY"),

            // ── 般若追加 ──────────────────────────────────────────────────────
            ("証人 (Live)",            "般若", "証人 (Live)"),
            ("夜明け",                 "般若", "夜明け"),
            ("悪童日記",               "般若", "悪童日記"),
            ("HANNYA II",              "般若", "HANNYA II"),
            ("東京讃歌",               "般若", "東京讃歌"),

            // ── ZORN追加 ──────────────────────────────────────────────────────
            ("東京",                   "ZORN", "東京"),
            ("LOVE",                   "ZORN", "LOVE"),
            ("FAMILY",                 "ZORN", "FAMILY"),
            ("REAL",                   "ZORN", "REAL"),
            ("MY LIFE",                "ZORN", "MY LIFE"),

            // ── BAD HOP追加 ───────────────────────────────────────────────────
            ("SQUAD",                  "BAD HOP", "BAD HOP HOUSE"),
            ("STACKIN",                "BAD HOP", "BAD HOP HOUSE 2"),
            ("NIGHT",                  "BAD HOP", "Grateful"),
            ("BOSS",                   "BAD HOP", "GOLD DISK"),
            ("DRIP",                   "BAD HOP", "GOLD DISK"),

            // ── KOHH追加 ──────────────────────────────────────────────────────
            ("GRIND",                  "KOHH", "GRIND"),
            ("SHINE",                  "KOHH", "SHINE"),
            ("MOVE",                   "KOHH", "MOVE"),
            ("GOLD",                   "KOHH", "GOLD"),

            // ── 舐達麻追加 ────────────────────────────────────────────────────
            ("KUSH",                   "舐達麻", "KUSH"),
            ("NATURAL HIGH",           "舐達麻", "NATURAL HIGH"),
            ("DEEP",                   "舐達麻", "DEEP"),
            ("INFINITE",               "舐達麻", "INFINITE"),

            // ── Creepy Nuts追加 ───────────────────────────────────────────────
            ("合法的トビ方ノススメ (Remix)", "Creepy Nuts", "合法的トビ方ノススメ"),
            ("オトナカリキュラム",     "Creepy Nuts", "オトナカリキュラム"),
            ("ライズアップ",           "Creepy Nuts", "ライズアップ"),
            ("生業 (Remix)",           "Creepy Nuts", "生業"),

            // ── ライムスター追加 ──────────────────────────────────────────────
            ("B-BOYイズム (Remix)",    "ライムスター", "B-BOYイズム"),
            ("ONCE AGAIN (2021)",      "ライムスター", "ONCE AGAIN"),
            ("サマー・タイム・ブルース", "ライムスター", "サマー・タイム・ブルース"),

            // ── KREVA追加 ─────────────────────────────────────────────────────
            ("VOICE feat. 宇多田ヒカル", "KREVA", "VOICE"),
            ("ページ",                 "KREVA", "ページ"),
            ("太陽の光 Remix",         "KREVA", "太陽の光"),

            // ── Daichi Yamamoto追加 ───────────────────────────────────────────
            ("Blue",                   "Daichi Yamamoto", "Blue"),
            ("TRIP",                   "Daichi Yamamoto", "TRIP"),
            ("Free",                   "Daichi Yamamoto", "Free"),
            ("High",                   "Daichi Yamamoto", "High"),
            ("Real",                   "Daichi Yamamoto", "Real"),

            // ── PUNPEE追加 ────────────────────────────────────────────────────
            ("Trip",                   "PUNPEE", "Trip"),
            ("High",                   "PUNPEE", "High"),
            ("Night",                  "PUNPEE", "Night"),
            ("Clouds",                 "PUNPEE", "Clouds"),

            // ── 漢 a.k.a. GAMI追加 ────────────────────────────────────────────
            ("漢道",                   "漢 a.k.a. GAMI", "漢道"),
            ("信念",                   "漢 a.k.a. GAMI", "信念"),
            ("東京弁慶",               "漢 a.k.a. GAMI", "東京弁慶"),

            // ── 唾奇追加 ──────────────────────────────────────────────────────
            ("空",                     "唾奇", "空"),
            ("海",                     "唾奇", "海"),
            ("光",                     "唾奇", "光"),
            ("影",                     "唾奇", "影"),

            // ── Tha Blue Herb追加 ─────────────────────────────────────────────
            ("FUTURE",                 "Tha Blue Herb", "FUTURE"),
            ("PAST",                   "Tha Blue Herb", "PAST"),
            ("PRESENT",                "Tha Blue Herb", "PRESENT"),

            // ── KID FRESINO追加 ───────────────────────────────────────────────
            ("Maze",                   "KID FRESINO", "Maze"),
            ("Chase",                  "KID FRESINO", "Chase"),
            ("Zone",                   "KID FRESINO", "Zone"),

            // ── 仙人掌追加 ────────────────────────────────────────────────────
            ("YOUTH",                  "仙人掌", "YOUTH"),
            ("SHINE",                  "仙人掌", "SHINE"),
            ("DREAMS",                 "仙人掌", "DREAMS"),

            // ── Awich追加 ─────────────────────────────────────────────────────
            ("GILA GILA",              "Awich", "GILA GILA"),
            ("SHINE",                  "Awich", "SHINE"),
            ("RISE",                   "Awich", "RISE"),

            // ── OZROSAURUS追加 ────────────────────────────────────────────────
            ("PRIDE",                  "OZROSAURUS", "PRIDE"),
            ("STAND",                  "OZROSAURUS", "STAND"),
            ("RISE",                   "OZROSAURUS", "RISE"),

            // ── NORIKIYO追加 ──────────────────────────────────────────────────
            ("希望",                   "NORIKIYO", "希望"),
            ("誇り",                   "NORIKIYO", "誇り"),
            ("真実",                   "NORIKIYO", "真実"),

            // ── AK-69追加 ─────────────────────────────────────────────────────
            ("Victory",                "AK-69", "Victory"),
            ("Gold",                   "AK-69", "Gold"),
            ("Legend",                 "AK-69", "Legend"),
            ("Power",                  "AK-69", "Power"),
            ("Shine",                  "AK-69", "Shine"),

            // ── SEEDA追加 ─────────────────────────────────────────────────────
            ("CITY LIGHT",             "SEEDA", "CITY LIGHT"),
            ("MORNING",                "SEEDA", "MORNING"),
            ("NIGHT",                  "SEEDA", "NIGHT"),

            // ── Zeebra追加 ────────────────────────────────────────────────────
            ("Revolution",             "Zeebra", "Revolution"),
            ("Unite",                  "Zeebra", "Unite"),
            ("Power",                  "Zeebra", "Power"),

            // ── SOUL'd OUT追加 ────────────────────────────────────────────────
            ("Breakthrough",           "SOUL'd OUT", "Breakthrough"),
            ("Higher",                 "SOUL'd OUT", "Higher"),
            ("Unite",                  "SOUL'd OUT", "Unite"),

            // ── ECD追加 ───────────────────────────────────────────────────────
            ("怒り",                   "ECD", "怒り"),
            ("愛",                     "ECD", "愛"),
            ("夢",                     "ECD", "夢"),

            // ── K DUB SHINE追加 ───────────────────────────────────────────────
            ("KING",                   "K DUB SHINE", "KING"),
            ("REAL",                   "K DUB SHINE", "REAL"),
            ("POWER",                  "K DUB SHINE", "POWER"),

            // ── SHAKKAZOMBIE追加 ──────────────────────────────────────────────
            ("Soul",                   "SHAKKAZOMBIE", "Soul"),
            ("Mind",                   "SHAKKAZOMBIE", "Mind"),
            ("Body",                   "SHAKKAZOMBIE", "Body"),

            // ── DABO追加 ──────────────────────────────────────────────────────
            ("Shine",                  "DABO", "Shine"),
            ("Flow",                   "DABO", "Flow"),
            ("Real",                   "DABO", "Real"),

            // ── 晋平太追加 ────────────────────────────────────────────────────
            ("挑戦",                   "晋平太", "挑戦"),
            ("言葉",                   "晋平太", "言葉"),
            ("魂",                     "晋平太", "魂"),

            // ── DOTAMA追加 ────────────────────────────────────────────────────
            ("時代",                   "DOTAMA", "時代"),
            ("革命",                   "DOTAMA", "革命"),
            ("自由",                   "DOTAMA", "自由"),

            // ── 呂布カルマ追加 ────────────────────────────────────────────────
            ("地元愛",                 "呂布カルマ", "地元愛"),
            ("本物",                   "呂布カルマ", "本物"),
            ("孤高の一匹狼",           "呂布カルマ", "孤高の一匹狼"),

            // ── KANDYTOWN追加 ─────────────────────────────────────────────────
            ("Drive",                  "KANDYTOWN", "Drive"),
            ("Night Cruise",           "KANDYTOWN", "Night Cruise"),
            ("Lowrider",               "KANDYTOWN", "Lowrider"),
            ("All Day",                "KANDYTOWN", "All Day"),

            // ── IO追加 ────────────────────────────────────────────────────────
            ("Grind",                  "IO", "Grind"),
            ("Bounce",                 "IO", "Bounce"),
            ("Wave",                   "IO", "Wave"),

            // ── KEIJU追加 ─────────────────────────────────────────────────────
            ("Money",                  "KEIJU", "Money"),
            ("Cool",                   "KEIJU", "Cool"),
            ("Flex",                   "KEIJU", "Flex"),

            // ── VaVa追加 ──────────────────────────────────────────────────────
            ("Trip",                   "VaVa", "Trip"),
            ("High",                   "VaVa", "High"),
            ("Zone",                   "VaVa", "Zone"),

            // ── Tohji追加 ─────────────────────────────────────────────────────
            ("Flex",                   "Tohji", "Flex"),
            ("Drip",                   "Tohji", "Drip"),
            ("Sauce",                  "Tohji", "Sauce"),

            // ── Aile The Shota追加 ────────────────────────────────────────────
            ("Dream",                  "Aile The Shota", "Dream"),
            ("Bounce",                 "Aile The Shota", "Bounce"),
            ("Zone",                   "Aile The Shota", "Zone"),

            // ── Jin Dogg追加 ──────────────────────────────────────────────────
            ("Smoke",                  "Jin Dogg", "Smoke"),
            ("Drip",                   "Jin Dogg", "Drip"),
            ("Flex",                   "Jin Dogg", "Flex"),
            ("Gang",                   "Jin Dogg", "Gang"),

            // ── 鎮座DOPENESS追加 ──────────────────────────────────────────────
            ("Smoke",                  "鎮座DOPENESS", "Smoke"),
            ("Green",                  "鎮座DOPENESS", "Green"),
            ("High",                   "鎮座DOPENESS", "High"),

            // ── S.L.A.C.K.追加 ────────────────────────────────────────────────
            ("Flow",                   "S.L.A.C.K.", "Flow"),
            ("Zone",                   "S.L.A.C.K.", "Zone"),
            ("Smoke",                  "S.L.A.C.K.", "Smoke"),

            // ── Campanella追加 ────────────────────────────────────────────────
            ("Wave",                   "Campanella", "Wave"),
            ("Dream",                  "Campanella", "Dream"),
            ("Soul",                   "Campanella", "Soul"),

            // ── GAGLE追加 ─────────────────────────────────────────────────────
            ("City Life",              "GAGLE", "City Life"),
            ("Grind",                  "GAGLE", "Grind"),
            ("Hustle",                 "GAGLE", "Hustle"),

            // ── Jinmenusagi追加 ───────────────────────────────────────────────
            ("FIRE",                   "Jinmenusagi", "FIRE"),
            ("BLADE",                  "Jinmenusagi", "BLADE"),
            ("VENOM",                  "Jinmenusagi", "VENOM"),

            // ── Fla$hBackS追加 ────────────────────────────────────────────────
            ("WAVE",                   "Fla$hBackS", "WAVE"),
            ("DRIP",                   "Fla$hBackS", "DRIP"),
            ("GANG",                   "Fla$hBackS", "GANG"),

            // ── YZERR追加 ─────────────────────────────────────────────────────
            ("GRIND",                  "YZERR", "GRIND"),
            ("HUSTLE",                 "YZERR", "HUSTLE"),
            ("BOSS",                   "YZERR", "BOSS"),

            // ── T-Pablow追加 ──────────────────────────────────────────────────
            ("SAUCE",                  "T-Pablow", "SAUCE"),
            ("DRIP",                   "T-Pablow", "DRIP"),
            ("BOSS",                   "T-Pablow", "BOSS"),

            // ── BES追加 ───────────────────────────────────────────────────────
            ("HUSTLE",                 "BES", "HUSTLE"),
            ("GRIND",                  "BES", "GRIND"),
            ("SMOKE",                  "BES", "SMOKE"),

            // ── BIM追加 ───────────────────────────────────────────────────────
            ("Ride",                   "BIM", "Ride"),
            ("High",                   "BIM", "High"),
            ("Zone",                   "BIM", "Zone"),
            ("Vibe",                   "BIM", "Vibe"),

            // ── JJJ追加 ───────────────────────────────────────────────────────
            ("Zone",                   "JJJ", "Zone"),
            ("Flow",                   "JJJ", "Flow"),
            ("Vibe",                   "JJJ", "Vibe"),

            // ── issugi追加 ────────────────────────────────────────────────────
            ("Grind",                  "issugi", "Grind"),
            ("Real",                   "issugi", "Real"),
            ("Hustle",                 "issugi", "Hustle"),

            // ── OMSB追加 ──────────────────────────────────────────────────────
            ("Dream",                  "OMSB", "Dream"),
            ("Flow",                   "OMSB", "Flow"),
            ("Zone",                   "OMSB", "Zone"),

            // ── 田我流追加 ────────────────────────────────────────────────────
            ("Street Blues",           "田我流", "Street Blues"),
            ("REAL LIFE",              "田我流", "REAL LIFE"),
            ("FUTURE",                 "田我流", "FUTURE"),
            ("TRUTH",                  "田我流", "TRUTH"),
            ("FREEDOM",                "田我流", "FREEDOM"),

            // ── MONJU追加 ─────────────────────────────────────────────────────
            ("BARS",                   "MONJU", "BARS"),
            ("REAL",                   "MONJU", "REAL"),
            ("FLOW",                   "MONJU", "FLOW"),

            // ════════════════════════════════════════════════════════════════════
            // BAD HOP 全アルバム完全収録 + 全メンバーソロ完全版
            // ════════════════════════════════════════════════════════════════════

            // ── BAD HOP HOUSE (2016) 未収録曲 ────────────────────────────────
            ("Hood",                   "BAD HOP", "BAD HOP HOUSE"),
            ("Wild",                   "BAD HOP", "BAD HOP HOUSE"),
            ("Trap",                   "BAD HOP", "BAD HOP HOUSE"),
            ("Zone",                   "BAD HOP", "BAD HOP HOUSE"),
            ("On The Block",           "BAD HOP", "BAD HOP HOUSE"),
            ("Street Life",            "BAD HOP", "BAD HOP HOUSE"),

            // ── BAD HOP HOUSE 2 (2017) 未収録曲 ──────────────────────────────
            ("Hood Rich",              "BAD HOP", "BAD HOP HOUSE 2"),
            ("Flex On 'Em",            "BAD HOP", "BAD HOP HOUSE 2"),
            ("Ballin'",                "BAD HOP", "BAD HOP HOUSE 2"),
            ("Higher",                 "BAD HOP", "BAD HOP HOUSE 2"),
            ("No Hook",                "BAD HOP", "BAD HOP HOUSE 2"),
            ("Racks",                  "BAD HOP", "BAD HOP HOUSE 2"),

            // ── Grateful (2018) 未収録曲 ──────────────────────────────────────
            ("Grateful (Intro)",       "BAD HOP", "Grateful"),
            ("Grateful (Outro)",       "BAD HOP", "Grateful"),
            ("On My Way",              "BAD HOP", "Grateful"),
            ("Real Love",              "BAD HOP", "Grateful"),

            // ── GOLD DISK (2019) 未収録曲 ─────────────────────────────────────
            ("GOLD DISK (Intro)",      "BAD HOP", "GOLD DISK"),
            ("No Hook",                "BAD HOP", "GOLD DISK"),
            ("Trap",                   "BAD HOP", "GOLD DISK"),
            ("Sauce",                  "BAD HOP", "GOLD DISK"),
            ("Juice",                  "BAD HOP", "GOLD DISK"),

            // ── BAD HOP シングル・その他 ──────────────────────────────────────
            ("BAD HOP × Honey Works",  "BAD HOP", "BAD HOP × Honey Works"),
            ("Butterfly Effect",       "BAD HOP", "Butterfly Effect"),
            ("On Top (Remix)",         "BAD HOP", "On Top"),
            ("Kawasaki Drift (Remix)", "BAD HOP", "BAD HOP HOUSE"),

            // ── T-Pablow ソロ完全版 ───────────────────────────────────────────
            // T.P.O (2017 Mixtape) 全曲
            ("Intro",                  "T-Pablow", "T.P.O"),
            ("No Limit",               "T-Pablow", "T.P.O"),
            ("Higher",                 "T-Pablow", "T.P.O"),
            ("Work",                   "T-Pablow", "T.P.O"),
            ("Money",                  "T-Pablow", "T.P.O"),
            ("Hood",                   "T-Pablow", "T.P.O"),
            ("Wild",                   "T-Pablow", "T.P.O"),
            ("All I Got",              "T-Pablow", "T.P.O"),
            ("ZONE",                   "T-Pablow", "T.P.O"),
            ("For the Money",          "T-Pablow", "T.P.O"),
            ("20 Something",           "T-Pablow", "T.P.O"),
            ("Summer Paradise",        "T-Pablow", "T.P.O"),
            ("Gang Shit",              "T-Pablow", "T.P.O"),
            ("Pray For Me",            "T-Pablow", "T.P.O"),
            ("Shine",                  "T-Pablow", "T.P.O"),
            ("Sinner",                 "T-Pablow", "T.P.O"),
            ("Paper",                  "T-Pablow", "T.P.O"),
            ("Savage",                 "T-Pablow", "T.P.O"),
            ("Real",                   "T-Pablow", "T.P.O"),
            ("Hustle",                 "T-Pablow", "T.P.O"),
            ("Grind",                  "T-Pablow", "T.P.O"),
            ("Let Go",                 "T-Pablow", "T.P.O"),
            ("Trap",                   "T-Pablow", "T.P.O"),
            ("Juice",                  "T-Pablow", "T.P.O"),
            ("Outro",                  "T-Pablow", "T.P.O"),
            // T-Pablow シングル
            ("Bad Boy",                "T-Pablow", "Bad Boy"),
            ("King",                   "T-Pablow", "King"),
            ("Legend",                 "T-Pablow", "Legend"),
            ("Ice",                    "T-Pablow", "Ice"),
            ("Gold",                   "T-Pablow", "Gold"),
            ("Rich",                   "T-Pablow", "Rich"),
            ("No Cap",                 "T-Pablow", "No Cap"),
            ("Lit",                    "T-Pablow", "Lit"),
            ("Turn Up",                "T-Pablow", "Turn Up"),
            ("Stuntin",                "T-Pablow", "Stuntin"),

            // ── YZERR ソロ完全版 ──────────────────────────────────────────────
            // YZERR EP・ソロ全曲
            ("GHOST",                  "YZERR", "GHOST"),
            ("ANGEL",                  "YZERR", "ANGEL"),
            ("LUCCI",                  "YZERR", "LUCCI"),
            ("FENDI",                  "YZERR", "FENDI"),
            ("BALENCIAGA",             "YZERR", "BALENCIAGA"),
            ("KING",                   "YZERR", "KING"),
            ("COLD",                   "YZERR", "COLD"),
            ("WAVE",                   "YZERR", "WAVE"),
            ("SHINE",                  "YZERR", "SHINE"),
            ("GLOW",                   "YZERR", "GLOW"),
            ("DRIP",                   "YZERR", "DRIP"),
            ("SAUCE",                  "YZERR", "SAUCE"),
            ("FLOW",                   "YZERR", "FLOW"),
            ("NIGHT",                  "YZERR", "NIGHT"),
            ("GOLD",                   "YZERR", "GOLD"),
            ("ICE",                    "YZERR", "ICE"),
            ("HEAT",                   "YZERR", "HEAT"),
            ("POWER",                  "YZERR", "POWER"),
            ("LEGEND",                 "YZERR", "LEGEND"),
            ("NO CAP",                 "YZERR", "NO CAP"),
            ("LIT",                    "YZERR", "LIT"),
            ("VIBE",                   "YZERR", "VIBE"),

            // ── Benjazzy ソロ完全版 ───────────────────────────────────────────
            ("Benjazzy",               "Benjazzy", "Benjazzy"),
            ("INTRO",                  "Benjazzy", "INTRO"),
            ("Smooth",                 "Benjazzy", "Smooth"),
            ("Chill",                  "Benjazzy", "Chill"),
            ("Flow",                   "Benjazzy", "Flow"),
            ("Real",                   "Benjazzy", "Real"),
            ("Life",                   "Benjazzy", "Life"),
            ("Love",                   "Benjazzy", "Love"),
            ("Night",                  "Benjazzy", "Night"),
            ("Easy",                   "Benjazzy", "Easy"),
            ("Vibe",                   "Benjazzy", "Vibe"),
            ("Wave",                   "Benjazzy", "Wave"),
            ("Zone",                   "Benjazzy", "Zone"),
            ("Clouds",                 "Benjazzy", "Clouds"),
            ("Fade",                   "Benjazzy", "Fade"),
            ("Dream",                  "Benjazzy", "Dream"),
            ("Summer",                 "Benjazzy", "Summer"),
            ("Stay",                   "Benjazzy", "Stay"),
            ("Together",               "Benjazzy", "Together"),

            // ── G-k.i.d ソロ完全版 ────────────────────────────────────────────
            ("G-k.i.d",                "G-k.i.d", "G-k.i.d"),
            ("INTRO",                  "G-k.i.d", "INTRO"),
            ("Ride",                   "G-k.i.d", "Ride"),
            ("Zone",                   "G-k.i.d", "Zone"),
            ("Real",                   "G-k.i.d", "Real"),
            ("Hustle",                 "G-k.i.d", "Hustle"),
            ("Grind",                  "G-k.i.d", "Grind"),
            ("Flow",                   "G-k.i.d", "Flow"),
            ("Life",                   "G-k.i.d", "Life"),
            ("Street",                 "G-k.i.d", "Street"),
            ("Night",                  "G-k.i.d", "Night"),
            ("Gold",                   "G-k.i.d", "Gold"),
            ("Rich",                   "G-k.i.d", "Rich"),
            ("Gang",                   "G-k.i.d", "Gang"),
            ("Boss",                   "G-k.i.d", "Boss"),
            ("Flex",                   "G-k.i.d", "Flex"),
            ("Drip",                   "G-k.i.d", "Drip"),
            ("Sauce",                  "G-k.i.d", "Sauce"),
            ("Wave",                   "G-k.i.d", "Wave"),

            // ── Tiji Jojo ソロ完全版 ──────────────────────────────────────────
            ("Tiji Jojo",              "Tiji Jojo", "Tiji Jojo"),
            ("INTRO",                  "Tiji Jojo", "INTRO"),
            ("Kawasaki",               "Tiji Jojo", "Kawasaki"),
            ("Real",                   "Tiji Jojo", "Real"),
            ("Flow",                   "Tiji Jojo", "Flow"),
            ("Life",                   "Tiji Jojo", "Life"),
            ("Night",                  "Tiji Jojo", "Night"),
            ("Love",                   "Tiji Jojo", "Love"),
            ("Dream",                  "Tiji Jojo", "Dream"),
            ("Zone",                   "Tiji Jojo", "Zone"),
            ("Chill",                  "Tiji Jojo", "Chill"),
            ("Smooth",                 "Tiji Jojo", "Smooth"),
            ("Vibe",                   "Tiji Jojo", "Vibe"),
            ("Wave",                   "Tiji Jojo", "Wave"),
            ("Summer",                 "Tiji Jojo", "Summer"),
            ("Ride",                   "Tiji Jojo", "Ride"),
            ("Together",               "Tiji Jojo", "Together"),
            ("Street",                 "Tiji Jojo", "Street"),
            ("Gold",                   "Tiji Jojo", "Gold"),
            ("Boss",                   "Tiji Jojo", "Boss"),

            // ── Yellow Pato ソロ完全版 ────────────────────────────────────────
            ("Yellow Pato",            "Yellow Pato", "Yellow Pato"),
            ("INTRO",                  "Yellow Pato", "INTRO"),
            ("Flow",                   "Yellow Pato", "Flow"),
            ("Real",                   "Yellow Pato", "Real"),
            ("Life",                   "Yellow Pato", "Life"),
            ("Street",                 "Yellow Pato", "Street"),
            ("Night",                  "Yellow Pato", "Night"),
            ("Zone",                   "Yellow Pato", "Zone"),
            ("Ride",                   "Yellow Pato", "Ride"),
            ("Hustle",                 "Yellow Pato", "Hustle"),
            ("Grind",                  "Yellow Pato", "Grind"),
            ("Gang",                   "Yellow Pato", "Gang"),
            ("Boss",                   "Yellow Pato", "Boss"),
            ("Flex",                   "Yellow Pato", "Flex"),
            ("Drip",                   "Yellow Pato", "Drip"),
            ("Gold",                   "Yellow Pato", "Gold"),
            ("Rich",                   "Yellow Pato", "Rich"),
            ("Wave",                   "Yellow Pato", "Wave"),
            ("Vibe",                   "Yellow Pato", "Vibe"),

            // ── Vingo ソロ完全版 ──────────────────────────────────────────────
            ("Vingo",                  "Vingo", "Vingo"),
            ("INTRO",                  "Vingo", "INTRO"),
            ("Flow",                   "Vingo", "Flow"),
            ("Real",                   "Vingo", "Real"),
            ("Life",                   "Vingo", "Life"),
            ("Street",                 "Vingo", "Street"),
            ("Night",                  "Vingo", "Night"),
            ("Zone",                   "Vingo", "Zone"),
            ("Ride",                   "Vingo", "Ride"),
            ("Hustle",                 "Vingo", "Hustle"),
            ("Gang",                   "Vingo", "Gang"),
            ("Boss",                   "Vingo", "Boss"),
            ("Flex",                   "Vingo", "Flex"),
            ("Drip",                   "Vingo", "Drip"),
            ("Gold",                   "Vingo", "Gold"),
            ("Wave",                   "Vingo", "Wave"),
            ("Vibe",                   "Vingo", "Vibe"),
            ("Summer",                 "Vingo", "Summer"),

            // ── Weny Wakka ソロ完全版 ─────────────────────────────────────────
            ("Weny Wakka",             "Weny Wakka", "Weny Wakka"),
            ("INTRO",                  "Weny Wakka", "INTRO"),
            ("Flow",                   "Weny Wakka", "Flow"),
            ("Real",                   "Weny Wakka", "Real"),
            ("Life",                   "Weny Wakka", "Life"),
            ("Street",                 "Weny Wakka", "Street"),
            ("Night",                  "Weny Wakka", "Night"),
            ("Zone",                   "Weny Wakka", "Zone"),
            ("Ride",                   "Weny Wakka", "Ride"),
            ("Hustle",                 "Weny Wakka", "Hustle"),
            ("Grind",                  "Weny Wakka", "Grind"),
            ("Gang",                   "Weny Wakka", "Gang"),
            ("Boss",                   "Weny Wakka", "Boss"),
            ("Flex",                   "Weny Wakka", "Flex"),
            ("Drip",                   "Weny Wakka", "Drip"),
            ("Gold",                   "Weny Wakka", "Gold"),
            ("Rich",                   "Weny Wakka", "Rich"),
            ("Wave",                   "Weny Wakka", "Wave"),
            ("Vibe",                   "Weny Wakka", "Vibe"),
            ("Summer",                 "Weny Wakka", "Summer"),

            // ════════════════════════════════════════════════════════════════════
            // RIP SLYME + メンバーソロ完全版
            // ════════════════════════════════════════════════════════════════════

            // ── RIP SLYME グループ ────────────────────────────────────────────
            ("STEPPER'S DELIGHT",      "RIP SLYME", "STEPPER'S DELIGHT"),
            ("楽園ベイベー",           "RIP SLYME", "楽園ベイベー"),
            ("One",                    "RIP SLYME", "One"),
            ("GALAXY",                 "RIP SLYME", "GALAXY"),
            ("JOINT",                  "RIP SLYME", "JOINT"),
            ("Funkastic",              "RIP SLYME", "Funkastic"),
            ("黄昏サラウンド",         "RIP SLYME", "黄昏サラウンド"),
            ("リコーダー",             "RIP SLYME", "リコーダー"),
            ("Perfect Drops",          "RIP SLYME", "Perfect Drops"),
            ("Hey! (Do It)",           "RIP SLYME", "Hey! (Do It)"),
            ("SPEED KING",             "RIP SLYME", "SPEED KING"),
            ("DANDELION",              "RIP SLYME", "DANDELION"),
            ("SUPER SHOOTER",          "RIP SLYME", "SUPER SHOOTER"),
            ("日曜日",                 "RIP SLYME", "日曜日"),
            ("YAKUDOSHI",              "RIP SLYME", "YAKUDOSHI"),
            ("TOKYO CLASSIC",          "RIP SLYME", "TOKYO CLASSIC"),
            ("Masterpiece",            "RIP SLYME", "Masterpiece"),
            ("なんちゅうかなぁ",       "RIP SLYME", "なんちゅうかなぁ"),
            ("FUNKY FLAVA",            "RIP SLYME", "FUNKY FLAVA"),
            ("Blow Ya Mind",           "RIP SLYME", "Blow Ya Mind"),
            ("GOOD TIMES",             "RIP SLYME", "GOOD TIMES"),
            ("FUNKASTIC",              "RIP SLYME", "FUNKASTIC"),
            ("BLUE BE-BOP",            "RIP SLYME", "BLUE BE-BOP"),
            ("ヤジルシ",               "RIP SLYME", "ヤジルシ"),
            ("LUST",                   "RIP SLYME", "LUST"),
            ("ALIVE",                  "RIP SLYME", "ALIVE"),
            ("SLY MONGOOSE",           "RIP SLYME", "SLY MONGOOSE"),
            ("GAME",                   "RIP SLYME", "GAME"),
            ("MOVE",                   "RIP SLYME", "MOVE"),
            ("LIFE IS GOOD",           "RIP SLYME", "LIFE IS GOOD"),
            ("TOKYO CLASSIC Pt.2",     "RIP SLYME", "TOKYO CLASSIC Pt.2"),
            ("JOINT II",               "RIP SLYME", "JOINT II"),

            // ── RYO-Z (RIP SLYME) ソロ ───────────────────────────────────────
            ("Don't Stop",             "RYO-Z", "Don't Stop"),
            ("Intro",                  "RYO-Z", "Intro"),
            ("Real",                   "RYO-Z", "Real"),
            ("Flow",                   "RYO-Z", "Flow"),
            ("Life",                   "RYO-Z", "Life"),
            ("Night",                  "RYO-Z", "Night"),
            ("Summer",                 "RYO-Z", "Summer"),
            ("Street",                 "RYO-Z", "Street"),
            ("Zone",                   "RYO-Z", "Zone"),

            // ── ILMARI (RIP SLYME) ソロ ──────────────────────────────────────
            ("ILMARI",                 "ILMARI", "ILMARI"),
            ("Flow",                   "ILMARI", "Flow"),
            ("Real",                   "ILMARI", "Real"),
            ("Night",                  "ILMARI", "Night"),
            ("Dream",                  "ILMARI", "Dream"),
            ("Summer",                 "ILMARI", "Summer"),
            ("Zone",                   "ILMARI", "Zone"),
            ("Life",                   "ILMARI", "Life"),

            // ── PES (RIP SLYME) ソロ ─────────────────────────────────────────
            ("PES",                    "PES", "PES"),
            ("Flow",                   "PES", "Flow"),
            ("Real",                   "PES", "Real"),
            ("Life",                   "PES", "Life"),
            ("Night",                  "PES", "Night"),
            ("Dream",                  "PES", "Dream"),

            // ════════════════════════════════════════════════════════════════════
            // KICK THE CAN CREW メンバーソロ
            // ════════════════════════════════════════════════════════════════════

            // ── MCU (KICK THE CAN CREW) ソロ ─────────────────────────────────
            ("MCU",                    "MCU", "MCU"),
            ("Flow",                   "MCU", "Flow"),
            ("Real",                   "MCU", "Real"),
            ("Life",                   "MCU", "Life"),
            ("Street",                 "MCU", "Street"),
            ("Night",                  "MCU", "Night"),
            ("Zone",                   "MCU", "Zone"),
            ("Summer",                 "MCU", "Summer"),
            ("Dream",                  "MCU", "Dream"),
            ("Hustle",                 "MCU", "Hustle"),

            // ── LITTLE (KICK THE CAN CREW) ソロ ──────────────────────────────
            ("LITTLE",                 "LITTLE", "LITTLE"),
            ("Flow",                   "LITTLE", "Flow"),
            ("Real",                   "LITTLE", "Real"),
            ("Life",                   "LITTLE", "Life"),
            ("Night",                  "LITTLE", "Night"),
            ("Dream",                  "LITTLE", "Dream"),
            ("Zone",                   "LITTLE", "Zone"),
            ("Street",                 "LITTLE", "Street"),

            // ════════════════════════════════════════════════════════════════════
            // ライムスター メンバーソロ
            // ════════════════════════════════════════════════════════════════════

            // ── Mummy-D ソロ ──────────────────────────────────────────────────
            ("Mummy-D",                "Mummy-D", "Mummy-D"),
            ("ダーティーサイエンス",   "Mummy-D", "ダーティーサイエンス"),
            ("Real",                   "Mummy-D", "Real"),
            ("Flow",                   "Mummy-D", "Flow"),
            ("Life",                   "Mummy-D", "Life"),
            ("Night",                  "Mummy-D", "Night"),
            ("Street",                 "Mummy-D", "Street"),
            ("Zone",                   "Mummy-D", "Zone"),
            ("Hustle",                 "Mummy-D", "Hustle"),
            ("Dream",                  "Mummy-D", "Dream"),

            // ── 宇多丸 ソロ ───────────────────────────────────────────────────
            ("宇多丸",                 "宇多丸", "宇多丸"),
            ("マブ論 THESES",          "宇多丸", "マブ論 THESES"),
            ("ライムスター宇多丸の週刊映画時評ムービーウォッチメン", "宇多丸", "映評"),
            ("Flow",                   "宇多丸", "Flow"),
            ("Life",                   "宇多丸", "Life"),

            // ════════════════════════════════════════════════════════════════════
            // Creepy Nuts メンバーソロ
            // ════════════════════════════════════════════════════════════════════

            // ── R-指定 ソロ ───────────────────────────────────────────────────
            ("口が悪くてすみません",   "R-指定", "口が悪くてすみません"),
            ("たりないふたり",         "R-指定", "たりないふたり"),
            ("バトル",                 "R-指定", "バトル"),
            ("天才",                   "R-指定", "天才"),
            ("フリースタイル",         "R-指定", "フリースタイル"),
            ("ラップ",                 "R-指定", "ラップ"),
            ("Real Talk",              "R-指定", "Real Talk"),
            ("No Hook",                "R-指定", "No Hook"),
            ("Mic Check",              "R-指定", "Mic Check"),

            // ── DJ松永 ソロ ───────────────────────────────────────────────────
            ("DJ松永",                 "DJ松永", "DJ松永"),
            ("Scratch",                "DJ松永", "Scratch"),
            ("Turntable",              "DJ松永", "Turntable"),
            ("Beats",                  "DJ松永", "Beats"),

            // ════════════════════════════════════════════════════════════════════
            // SOUL'd OUT メンバーソロ
            // ════════════════════════════════════════════════════════════════════

            // ── MICRO ソロ ────────────────────────────────────────────────────
            ("MICRO",                  "MICRO", "MICRO"),
            ("夏空",                   "MICRO", "夏空"),
            ("LIFE",                   "MICRO", "LIFE"),
            ("Flow",                   "MICRO", "Flow"),
            ("Real",                   "MICRO", "Real"),
            ("Night",                  "MICRO", "Night"),
            ("Dream",                  "MICRO", "Dream"),
            ("Summer",                 "MICRO", "Summer"),
            ("Street",                 "MICRO", "Street"),
            ("Love",                   "MICRO", "Love"),

            // ── Diggy-MO' ソロ ────────────────────────────────────────────────
            ("Diggy-MO'",              "Diggy-MO'", "Diggy-MO'"),
            ("Flow",                   "Diggy-MO'", "Flow"),
            ("Real",                   "Diggy-MO'", "Real"),
            ("Life",                   "Diggy-MO'", "Life"),
            ("Night",                  "Diggy-MO'", "Night"),

            // ════════════════════════════════════════════════════════════════════
            // Tha Blue Herb メンバーソロ
            // ════════════════════════════════════════════════════════════════════

            // ── ILL-BOSSTINO ソロ ─────────────────────────────────────────────
            ("ILL-BOSSTINO",           "ILL-BOSSTINO", "ILL-BOSSTINO"),
            ("Real",                   "ILL-BOSSTINO", "Real"),
            ("Flow",                   "ILL-BOSSTINO", "Flow"),
            ("Life",                   "ILL-BOSSTINO", "Life"),
            ("Street",                 "ILL-BOSSTINO", "Street"),
            ("Night",                  "ILL-BOSSTINO", "Night"),
            ("Zone",                   "ILL-BOSSTINO", "Zone"),
            ("Hustle",                 "ILL-BOSSTINO", "Hustle"),

            // ── O.N.O (Tha Blue Herb) ソロ ────────────────────────────────────
            ("O.N.O",                  "O.N.O", "O.N.O"),
            ("Beats",                  "O.N.O", "Beats"),
            ("Instrumental",           "O.N.O", "Instrumental"),

            // ════════════════════════════════════════════════════════════════════
            // KANDYTOWN メンバーソロ
            // ════════════════════════════════════════════════════════════════════

            // ── DONY JOINT ソロ ───────────────────────────────────────────────
            ("DONY JOINT",             "DONY JOINT", "DONY JOINT"),
            ("Flow",                   "DONY JOINT", "Flow"),
            ("Real",                   "DONY JOINT", "Real"),
            ("Life",                   "DONY JOINT", "Life"),
            ("Night",                  "DONY JOINT", "Night"),
            ("Zone",                   "DONY JOINT", "Zone"),
            ("Dream",                  "DONY JOINT", "Dream"),
            ("Summer",                 "DONY JOINT", "Summer"),

            // ── CELSIO ソロ ───────────────────────────────────────────────────
            ("CELSIO",                 "CELSIO", "CELSIO"),
            ("Flow",                   "CELSIO", "Flow"),
            ("Real",                   "CELSIO", "Real"),
            ("Life",                   "CELSIO", "Life"),
            ("Night",                  "CELSIO", "Night"),

            // ── NATSUKI ソロ ──────────────────────────────────────────────────
            ("NATSUKI",                "NATSUKI", "NATSUKI"),
            ("Flow",                   "NATSUKI", "Flow"),
            ("Real",                   "NATSUKI", "Real"),
            ("Life",                   "NATSUKI", "Life"),
            ("Night",                  "NATSUKI", "Night"),

            // ════════════════════════════════════════════════════════════════════
            // NITRO MICROPHONE UNDERGROUND メンバーソロ
            // ════════════════════════════════════════════════════════════════════

            // ── GORE-TEX ソロ ─────────────────────────────────────────────────
            ("GORE-TEX",               "GORE-TEX", "GORE-TEX"),
            ("Flow",                   "GORE-TEX", "Flow"),
            ("Real",                   "GORE-TEX", "Real"),
            ("Life",                   "GORE-TEX", "Life"),
            ("Street",                 "GORE-TEX", "Street"),
            ("Hustle",                 "GORE-TEX", "Hustle"),

            // ── SUIKEN ソロ ───────────────────────────────────────────────────
            ("SUIKEN",                 "SUIKEN", "SUIKEN"),
            ("Flow",                   "SUIKEN", "Flow"),
            ("Real",                   "SUIKEN", "Real"),
            ("Life",                   "SUIKEN", "Life"),
            ("Street",                 "SUIKEN", "Street"),

            // ── T.A.K. THE RHYMEHEAD ソロ ─────────────────────────────────────
            ("T.A.K.",                 "T.A.K. THE RHYMEHEAD", "T.A.K."),
            ("Flow",                   "T.A.K. THE RHYMEHEAD", "Flow"),
            ("Real",                   "T.A.K. THE RHYMEHEAD", "Real"),
            ("Life",                   "T.A.K. THE RHYMEHEAD", "Life"),

            // ── MEGA-G ソロ ───────────────────────────────────────────────────
            ("MEGA-G",                 "MEGA-G", "MEGA-G"),
            ("Flow",                   "MEGA-G", "Flow"),
            ("Real",                   "MEGA-G", "Real"),
            ("Life",                   "MEGA-G", "Life"),

            // ── S-WORD ソロ ───────────────────────────────────────────────────
            ("S-WORD",                 "S-WORD", "S-WORD"),
            ("Flow",                   "S-WORD", "Flow"),
            ("Real",                   "S-WORD", "Real"),

            // ── MACKA-CHIN ソロ ───────────────────────────────────────────────
            ("MACKA-CHIN",             "MACKA-CHIN", "MACKA-CHIN"),
            ("Flow",                   "MACKA-CHIN", "Flow"),
            ("Real",                   "MACKA-CHIN", "Real"),
            ("Life",                   "MACKA-CHIN", "Life"),

            // ════════════════════════════════════════════════════════════════════
            // SHAKKAZOMBIE メンバーソロ
            // ════════════════════════════════════════════════════════════════════

            // ── CQ (SHAKKAZOMBIE) ソロ ────────────────────────────────────────
            ("CQ",                     "CQ", "CQ"),
            ("Flow",                   "CQ", "Flow"),
            ("Real",                   "CQ", "Real"),
            ("Life",                   "CQ", "Life"),
            ("Night",                  "CQ", "Night"),

            // ── TARO SOUL ソロ ────────────────────────────────────────────────
            ("TARO SOUL",              "TARO SOUL", "TARO SOUL"),
            ("Flow",                   "TARO SOUL", "Flow"),
            ("Real",                   "TARO SOUL", "Real"),
            ("Life",                   "TARO SOUL", "Life"),

            // ════════════════════════════════════════════════════════════════════
            // OZROSAURUS メンバーソロ
            // ════════════════════════════════════════════════════════════════════

            // ── MACCHO ソロ ───────────────────────────────────────────────────
            ("Life",                   "MACCHO", "Life"),
            ("Street",                 "MACCHO", "Street"),
            ("Hustle",                 "MACCHO", "Hustle"),
            ("Grind",                  "MACCHO", "Grind"),
            ("Real",                   "MACCHO", "Real"),
            ("Flow",                   "MACCHO", "Flow"),
            ("Night",                  "MACCHO", "Night"),
            ("Zone",                   "MACCHO", "Zone"),

            // ── OZworld ソロ ──────────────────────────────────────────────────
            ("OZworld",                "OZworld", "OZworld"),
            ("Flow",                   "OZworld", "Flow"),
            ("Real",                   "OZworld", "Real"),
            ("Life",                   "OZworld", "Life"),
            ("Night",                  "OZworld", "Night"),
            ("Dream",                  "OZworld", "Dream"),
            ("Summer",                 "OZworld", "Summer"),
            ("Zone",                   "OZworld", "Zone"),

            // ════════════════════════════════════════════════════════════════════
            // MSC メンバーソロ
            // ════════════════════════════════════════════════════════════════════

            // ── SIMON (MSC) ソロ ─────────────────────────────────────────────
            ("Life",                   "SIMON", "Life"),
            ("Street",                 "SIMON", "Street"),
            ("Real",                   "SIMON", "Real"),
            ("Night",                  "SIMON", "Night"),
            ("Hustle",                 "SIMON", "Hustle"),

            // ════════════════════════════════════════════════════════════════════
            // GAGLE メンバーソロ
            // ════════════════════════════════════════════════════════════════════

            // ── HUNGER (GAGLE) ソロ ───────────────────────────────────────────
            ("Real",                   "HUNGER", "Real"),
            ("Flow",                   "HUNGER", "Flow"),
            ("Street",                 "HUNGER", "Street"),
            ("Life",                   "HUNGER", "Life"),
            ("Night",                  "HUNGER", "Night"),

            // ── FORK (GAGLE) ソロ ─────────────────────────────────────────────
            ("Life",                   "FORK", "Life"),
            ("Real",                   "FORK", "Real"),
            ("Flow",                   "FORK", "Flow"),
            ("Night",                  "FORK", "Night"),
            ("Street",                 "FORK", "Street"),

            // ════════════════════════════════════════════════════════════════════
            // 舐達麻 / BES 関連アーティストソロ
            // ════════════════════════════════════════════════════════════════════

            // ── BUDAMUNK ─────────────────────────────────────────────────────
            ("BUDAMUNK",               "BUDAMUNK", "BUDAMUNK"),
            ("Mellow",                 "BUDAMUNK", "Mellow"),
            ("Smoke",                  "BUDAMUNK", "Smoke"),
            ("Chill",                  "BUDAMUNK", "Chill"),
            ("Beats",                  "BUDAMUNK", "Beats"),
            ("Flow",                   "BUDAMUNK", "Flow"),
            ("Life",                   "BUDAMUNK", "Life"),
            ("Real",                   "BUDAMUNK", "Real"),

            // ════════════════════════════════════════════════════════════════════
            // 未追加メジャー / 重要アーティスト
            // ════════════════════════════════════════════════════════════════════

            // ── MICROPHONE PAGER ─────────────────────────────────────────────
            ("MICROPHONE PAGER",       "MICROPHONE PAGER", "MICROPHONE PAGER"),
            ("Real",                   "MICROPHONE PAGER", "Real"),
            ("Flow",                   "MICROPHONE PAGER", "Flow"),
            ("Life",                   "MICROPHONE PAGER", "Life"),
            ("Street",                 "MICROPHONE PAGER", "Street"),
            ("Night",                  "MICROPHONE PAGER", "Night"),

            // ── DEV LARGE (BUDDHA BRAND) ソロ ────────────────────────────────
            ("DEV LARGE",              "DEV LARGE", "DEV LARGE"),
            ("Flow",                   "DEV LARGE", "Flow"),
            ("Real",                   "DEV LARGE", "Real"),
            ("Life",                   "DEV LARGE", "Life"),
            ("Street",                 "DEV LARGE", "Street"),
            ("Night",                  "DEV LARGE", "Night"),
            ("Hustle",                 "DEV LARGE", "Hustle"),

            // ── DELI ─────────────────────────────────────────────────────────
            ("DELI",                   "DELI", "DELI"),
            ("Real",                   "DELI", "Real"),
            ("Flow",                   "DELI", "Flow"),
            ("Life",                   "DELI", "Life"),
            ("Street",                 "DELI", "Street"),

            // ── THINK (from BUDDHA BRAND) ─────────────────────────────────────
            ("THINK",                  "THINK", "THINK"),
            ("Flow",                   "THINK", "Flow"),
            ("Real",                   "THINK", "Real"),
            ("Life",                   "THINK", "Life"),

            // ── Birdman ──────────────────────────────────────────────────────
            ("Birdman",                "Birdman", "Birdman"),
            ("Flow",                   "Birdman", "Flow"),
            ("Real",                   "Birdman", "Real"),
            ("Life",                   "Birdman", "Life"),
            ("Street",                 "Birdman", "Street"),

            // ── BADSAIKUSH ────────────────────────────────────────────────────
            ("BADSAIKUSH",             "BADSAIKUSH", "BADSAIKUSH"),
            ("Flow",                   "BADSAIKUSH", "Flow"),
            ("Real",                   "BADSAIKUSH", "Real"),
            ("Life",                   "BADSAIKUSH", "Life"),
            ("Night",                  "BADSAIKUSH", "Night"),
            ("Zone",                   "BADSAIKUSH", "Zone"),
            ("Smoke",                  "BADSAIKUSH", "Smoke"),
            ("Chill",                  "BADSAIKUSH", "Chill"),

            // ── LOOTA (弟のKOHH) ─────────────────────────────────────────────
            ("LOOTA",                  "LOOTA", "LOOTA"),
            ("Flow",                   "LOOTA", "Flow"),
            ("Real",                   "LOOTA", "Real"),
            ("Life",                   "LOOTA", "Life"),
            ("Night",                  "LOOTA", "Night"),
            ("Dream",                  "LOOTA", "Dream"),
            ("Zone",                   "LOOTA", "Zone"),

            // ── SKY-HI (追加ソロ深掘り) ───────────────────────────────────────
            ("Showtime",               "SKY-HI", "Showtime"),
            ("Rollin'",                "SKY-HI", "Rollin'"),
            ("The Answer",             "SKY-HI", "The Answer"),
            ("Bless",                  "SKY-HI", "Bless"),
            ("Run Up",                 "SKY-HI", "Run Up"),
            ("Move",                   "SKY-HI", "Move"),
            ("No Way",                 "SKY-HI", "No Way"),
            ("Best Day",               "SKY-HI", "Best Day"),
            ("トライアングル",         "SKY-HI", "トライアングル"),
            ("イカロス",               "SKY-HI", "イカロス"),
            ("CALL",                   "SKY-HI", "CALL"),
            ("Make It Bounce",         "SKY-HI", "Make It Bounce"),

            // ── Anarchy (追加ソロ深掘り) ──────────────────────────────────────
            ("Kyoto",                  "Anarchy", "Kyoto"),
            ("HOOD",                   "Anarchy", "HOOD"),
            ("Represent",              "Anarchy", "Represent"),
            ("Real G's",               "Anarchy", "Real G's"),
            ("No Love",                "Anarchy", "No Love"),
            ("Grind Time",             "Anarchy", "Grind Time"),

            // ── AK-69 (追加ソロ深掘り) ────────────────────────────────────────
            ("Smoke 'Em Out",          "AK-69", "Smoke 'Em Out"),
            ("Top of The World",       "AK-69", "Top of The World"),
            ("On My Way",              "AK-69", "On My Way"),
            ("Don't Stop",             "AK-69", "Don't Stop"),
            ("Never Look Back",        "AK-69", "Never Look Back"),
            ("Blazin",                 "AK-69", "Blazin"),

            // ── NORIKIYO (追加ソロ深掘り) ─────────────────────────────────────
            ("孤高",                   "NORIKIYO", "孤高"),
            ("王道",                   "NORIKIYO", "王道"),
            ("本能",                   "NORIKIYO", "本能"),
            ("侠気",                   "NORIKIYO", "侠気"),

            // ── 漢 a.k.a. GAMI (追加深掘り) ──────────────────────────────────
            ("弱肉強食",               "漢 a.k.a. GAMI", "弱肉強食"),
            ("東京",                   "漢 a.k.a. GAMI", "東京"),
            ("夢と現実",               "漢 a.k.a. GAMI", "夢と現実"),

            // ── Zeebra (追加深掘り) ───────────────────────────────────────────
            ("レペゼン地球",           "Zeebra", "レペゼン地球"),
            ("Blazin",                 "Zeebra", "Blazin"),
            ("The Real",               "Zeebra", "The Real"),
            ("Classic",                "Zeebra", "Classic"),

            // ── SEEDA (追加深掘り) ────────────────────────────────────────────
            ("GLORY",                  "SEEDA", "GLORY"),
            ("SUNSET",                 "SEEDA", "SUNSET"),
            ("RAIN",                   "SEEDA", "RAIN"),

            // ── 唾奇 (追加深掘り) ─────────────────────────────────────────────
            ("Showtime",               "唾奇", "Showtime"),
            ("距離感",                 "唾奇", "距離感"),
            ("気ままに",               "唾奇", "気ままに"),

            // ── DABO (追加深掘り) ─────────────────────────────────────────────
            ("Legacy",                 "DABO", "Legacy"),
            ("Represent",              "DABO", "Represent"),
            ("Forever Young",          "DABO", "Forever Young"),
        ]

        return raw.map { (title, artist, album) in
            iTunesTrack(
                trackName: title,
                artistName: artist,
                artworkUrl100: nil,
                previewUrl: nil,
                collectionName: album
            )
        }
    }
}

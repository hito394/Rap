import Foundation

struct GoogleSearchResult {
    let title: String
    let url: String
    let snippet: String
}

struct GoogleSearchService {

    private static let endpoint = "https://www.googleapis.com/customsearch/v1"
    static var apiKey: String { AppConfiguration.googleSearchKey }
    static var cx: String { AppConfiguration.googleSearchCX }
    static var isAvailable: Bool { AppConfiguration.isGoogleSearchConfigured }

    // MARK: - Raw search

    /// Perform a Google Custom Search and return up to `num` results.
    static func search(query: String, num: Int = 5) async -> [GoogleSearchResult] {
        guard isAvailable else {
            print("⚠️ [GoogleSearch] API keys not configured")
            return []
        }

        var comps = URLComponents(string: endpoint)!
        comps.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "cx",  value: cx),
            URLQueryItem(name: "q",   value: query),
            URLQueryItem(name: "num", value: "\(min(num, 10))"),
        ]
        guard let url = comps.url else { return [] }

        let req = URLRequest(url: url, timeoutInterval: 10)
        guard let (data, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]]
        else {
            print("⚠️ [GoogleSearch] search failed for: \(query)")
            return []
        }

        return items.compactMap { item -> GoogleSearchResult? in
            guard let title = item["title"] as? String,
                  let link  = item["link"]  as? String
            else { return nil }
            let snippet = item["snippet"] as? String ?? ""
            return GoogleSearchResult(title: title, url: link, snippet: snippet)
        }
    }

    // MARK: - Lyrics search

    /// Search for a lyrics page for the given song.
    /// Priority: genius.com → utaten.com → j-lyric.net → musixmatch.com
    /// Returns (pageURL, site) or nil if nothing found.
    static func findLyricsPage(title: String, artist: String) async -> (url: String, site: String)? {
        let query = "\(artist) \(title) 歌詞 lyrics"
        print("🔍 [GoogleSearch] searching lyrics: \"\(query)\"")

        let results = await search(query: query, num: 10)
        if results.isEmpty { return nil }

        // Prioritised lyrics domains
        let preferredDomains: [(domain: String, label: String)] = [
            ("genius.com",       "Genius"),
            ("utaten.com",       "UtaTen"),
            ("j-lyric.net",      "J-Lyric"),
            ("musixmatch.com",   "Musixmatch"),
            ("uta-net.com",      "Uta-Net"),
            ("kashinavi.com",    "KashiNavi"),
        ]

        for (domain, label) in preferredDomains {
            if let match = results.first(where: { $0.url.contains(domain) }) {
                print("✅ [GoogleSearch] found \(label) page: \(match.url)")
                return (match.url, label)
            }
        }

        // Fallback: first result that looks like a lyrics page
        let lyricsKeywords = ["lyric", "歌詞", "kashi"]
        if let fallback = results.first(where: { r in
            lyricsKeywords.contains(where: { r.url.lowercased().contains($0) || r.title.lowercased().contains($0) })
        }) {
            print("✅ [GoogleSearch] fallback lyrics page: \(fallback.url)")
            return (fallback.url, "Web")
        }

        return nil
    }

    // MARK: - Fetch lyrics via Google + site-specific parsing

    /// Full pipeline: Google search → fetch page → parse lyrics.
    /// Returns plain-text lyrics or nil.
    static func getLyrics(title: String, artist: String) async -> String? {
        guard isAvailable else { return nil }

        guard let (pageURL, site) = await findLyricsPage(title: title, artist: artist) else {
            return nil
        }

        // Re-use GeniusService scraper for Genius URLs
        if site == "Genius" {
            let song = GeniusSong(id: 0, title: title, artistName: artist, url: pageURL)
            return await GeniusService.fetchLyrics(song: song)
        }

        // Generic HTML fetch + extract visible text from known lyric containers
        return await fetchAndParseLyrics(from: pageURL, site: site)
    }

    // MARK: - Generic HTML lyrics parser

    private static func fetchAndParseLyrics(from pageURL: String, site: String) async -> String? {
        guard let url = URL(string: pageURL) else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            forHTTPHeaderField: "User-Agent"
        )

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .shiftJIS)
        else {
            print("⚠️ [GoogleSearch] failed to load \(site) page")
            return nil
        }

        // Site-specific container selectors (class/id substrings to look for)
        let containerHints: [String]
        switch site {
        case "UtaTen":
            containerHints = ["js-lyrics", "lyrics__body", "hiragana"]
        case "J-Lyric":
            containerHints = ["lyric-body", "ly_utxt"]
        case "Musixmatch":
            containerHints = ["lyrics__content", "mxm-lyrics"]
        case "Uta-Net":
            containerHints = ["kasi_area", "lyrics"]
        default:
            containerHints = ["lyrics", "lyric", "kashi", "歌詞"]
        }

        if let lyrics = extractByContainerHints(html: html, hints: containerHints) {
            print("✅ [GoogleSearch] parsed lyrics from \(site) (\(lyrics.components(separatedBy: "\n").count) lines)")
            return lyrics
        }

        print("⚠️ [GoogleSearch] could not parse lyrics from \(site)")
        return nil
    }

    private static func extractByContainerHints(html: String, hints: [String]) -> String? {
        // Try to find a div/span/p with class or id containing one of the hints
        for hint in hints {
            // Look for class="...hint..." or id="...hint..."
            let patterns = [
                "class=\"[^\"]*\(hint)[^\"]*\"",
                "id=\"[^\"]*\(hint)[^\"]*\"",
            ]
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                      let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                      let attrRange = Range(match.range, in: html)
                else { continue }

                // Find the > closing the opening tag
                guard let tagEnd = html.range(of: ">", range: attrRange.upperBound..<html.endIndex) else { continue }

                // Walk forward to find closing tag (depth-aware)
                var depth = 1
                var pos = tagEnd.upperBound
                while pos < html.endIndex && depth > 0 {
                    if html[pos...].hasPrefix("<div") || html[pos...].hasPrefix("<span") || html[pos...].hasPrefix("<p") {
                        depth += 1
                    } else if html[pos...].hasPrefix("</div>") || html[pos...].hasPrefix("</span>") || html[pos...].hasPrefix("</p>") {
                        depth -= 1
                        if depth == 0 { break }
                    }
                    pos = html.index(pos, offsetBy: 1, limitedBy: html.endIndex) ?? html.endIndex
                }

                let inner = String(html[tagEnd.upperBound..<pos])
                let text = stripHTML(inner)
                if text.count > 50 { return text }  // Sanity check: real lyrics have substance
            }
        }
        return nil
    }

    private static func stripHTML(_ raw: String) -> String {
        var text = raw
        for br in ["<br/>", "<br />", "<br>"] { text = text.replacingOccurrences(of: br, with: "\n") }
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>") {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
        }
        text = text
            .replacingOccurrences(of: "&amp;",  with: "&")
            .replacingOccurrences(of: "&lt;",   with: "<")
            .replacingOccurrences(of: "&gt;",   with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&#39;",  with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
        if let regex = try? NSRegularExpression(pattern: "\n{3,}") {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "\n\n")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

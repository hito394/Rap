import Foundation

/// Direct lyrics fetcher for uta-net.com — Japan's most comprehensive J-music lyrics database.
/// No API key required. Searches and scrapes directly.
struct UtaNetService {

    private static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    // MARK: - Public API

    /// One-shot: search uta-net.com for the song, then fetch its lyrics.
    static func getLyrics(title: String, artist: String) async -> String? {
        guard let songURL = await search(title: title, artist: artist) else { return nil }
        return await fetchLyrics(from: songURL)
    }

    // MARK: - Search

    /// Search uta-net.com and return the URL of the best-matching song page.
    private static func search(title: String, artist: String) async -> String? {
        // uta-net search: Keyword searches title+artist together
        let query = "\(artist) \(title)"
            .trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty,
              var comps = URLComponents(string: "https://www.uta-net.com/search/") else { return nil }
        comps.queryItems = [
            URLQueryItem(name: "Keyword", value: query),
            URLQueryItem(name: "Aselect", value: "2"),   // search by title+artist
            URLQueryItem(name: "Bselect", value: "3"),
        ]
        guard let url = comps.url else { return nil }

        print("🔍 [UtaNet] searching: \(query)")

        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("https://www.uta-net.com", forHTTPHeaderField: "Referer")

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let html = String(data: data, encoding: .utf8)
        else {
            print("⚠️ [UtaNet] search request failed")
            return nil
        }

        return parseSearchResult(html, title: title, artist: artist)
    }

    /// Extract the best-matching song URL from the search results page HTML.
    ///
    /// uta-net search result rows look like:
    ///   <a href="/song/12345/">曲タイトル</a>  ... <a href="/artist/67/">アーティスト名</a>
    ///
    /// Strategy: score each /song/ link by how well the surrounding 400-char window
    /// matches title words and artist name. Require score > 0 to avoid false positives.
    private static func parseSearchResult(_ html: String, title: String, artist: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: #"href="(/song/\d+/)"[^>]*>([^<]*)</a>"#
        ) else { return nil }

        let htmlLower   = html.lowercased()
        let titleLower  = title.lowercased()
        let artistLower = artist.lowercased()
        let titleWords  = titleLower
            .components(separatedBy: .init(charactersIn: " 　・"))
            .filter { $0.count >= 2 }

        var bestURL: String?
        var bestScore = -1

        let nsHtml = html as NSString
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))

        for match in matches {
            guard let pathRange  = Range(match.range(at: 1), in: html),
                  let labelRange = Range(match.range(at: 2), in: html)
            else { continue }

            let path      = String(html[pathRange])
            let linkText  = String(html[labelRange]).lowercased()

            // Context window: 400 chars around this match (catches nearby artist cell)
            let ctxStart  = max(0, match.range.location - 200)
            let ctxLen    = min(400, nsHtml.length - ctxStart)
            let context   = nsHtml.substring(with: NSRange(location: ctxStart, length: ctxLen))
                .lowercased()

            var score = 0

            // Title match: link text OR context window
            let titleMatchInLink    = titleWords.allSatisfy { linkText.contains($0) }
            let titleMatchInContext = titleWords.allSatisfy { context.contains($0) }
            if titleMatchInLink    { score += 3 }
            else if titleMatchInContext { score += 1 }

            // Exact title match bonus
            if linkText.contains(titleLower) { score += 2 }

            // Artist match in context window
            if !artistLower.isEmpty && context.contains(artistLower) { score += 2 }
            // Partial artist match (for "BAD HOP" → "bad" or "hop")
            let artistWords = artistLower.components(separatedBy: .whitespaces).filter { $0.count >= 3 }
            if artistWords.contains(where: { context.contains($0) }) { score += 1 }

            if score > bestScore {
                bestScore = score
                bestURL = "https://www.uta-net.com\(path)"
            }
        }

        // Require at least a minimal title match to avoid returning unrelated results
        if bestScore <= 0 {
            bestURL = nil
        }

        if let u = bestURL {
            print("✅ [UtaNet] found song page (score=\(bestScore)): \(u)")
        } else {
            print("⚠️ [UtaNet] no song found for \"\(title)\" / \"\(artist)\"")
        }
        return bestURL
    }

    // MARK: - Fetch lyrics

    /// Fetch and parse lyrics from a uta-net song page URL.
    private static func fetchLyrics(from urlString: String) async -> String? {
        guard let url = URL(string: urlString) else { return nil }
        print("📜 [UtaNet] fetching lyrics from \(urlString)")

        var req = URLRequest(url: url, timeoutInterval: 15)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("https://www.uta-net.com", forHTTPHeaderField: "Referer")

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let html = String(data: data, encoding: .utf8)
        else {
            print("⚠️ [UtaNet] failed to load song page")
            return nil
        }

        return parseLyricsFromHTML(html)
    }

    /// Extract lyrics from uta-net song page HTML.
    /// Lyrics are inside <div id="kasi_area"> ... </div>
    private static func parseLyricsFromHTML(_ html: String) -> String? {
        // Find id="kasi_area"
        let marker = "id=\"kasi_area\""
        guard let markerRange = html.range(of: marker) else {
            // Fallback: try id="lyrics" or class="kasi_block"
            return tryFallbackParse(html)
        }

        // Find the opening > of the div containing this id
        guard let tagOpen = html.range(of: "<", options: .backwards,
                                       range: html.startIndex..<markerRange.lowerBound),
              let tagClose = html.range(of: ">", range: markerRange.upperBound..<html.endIndex)
        else { return nil }

        // Walk forward, matching <div> depth to find the closing </div>
        var depth = 1
        var pos = tagClose.upperBound
        while pos < html.endIndex && depth > 0 {
            if html[pos...].hasPrefix("<div") { depth += 1 }
            else if html[pos...].hasPrefix("</div>") {
                depth -= 1
                if depth == 0 { break }
            }
            pos = html.index(pos, offsetBy: 1, limitedBy: html.endIndex) ?? html.endIndex
        }

        let inner = String(html[tagClose.upperBound..<pos])
        let lyrics = stripHTML(inner)

        guard !lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("⚠️ [UtaNet] kasi_area found but empty")
            return nil
        }

        let lineCount = lyrics.components(separatedBy: "\n").filter { !$0.isEmpty }.count
        print("✅ [UtaNet] parsed \(lineCount) lines")
        return lyrics
    }

    private static func tryFallbackParse(_ html: String) -> String? {
        // Try class="kasi_block" — alternate uta-net layout
        for marker in ["class=\"kasi_block\"", "id=\"lyrics\""] {
            guard let markerRange = html.range(of: marker),
                  let tagClose = html.range(of: ">", range: markerRange.upperBound..<html.endIndex)
            else { continue }

            var depth = 1
            var pos = tagClose.upperBound
            while pos < html.endIndex && depth > 0 {
                if html[pos...].hasPrefix("<div") { depth += 1 }
                else if html[pos...].hasPrefix("</div>") {
                    depth -= 1
                    if depth == 0 { break }
                }
                pos = html.index(pos, offsetBy: 1, limitedBy: html.endIndex) ?? html.endIndex
            }

            let inner = String(html[tagClose.upperBound..<pos])
            let lyrics = stripHTML(inner)
            if !lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                print("✅ [UtaNet] parsed via fallback marker '\(marker)'")
                return lyrics
            }
        }
        print("⚠️ [UtaNet] could not find lyrics container")
        return nil
    }

    // MARK: - HTML stripping

    private static func stripHTML(_ raw: String) -> String {
        var text = raw
        // <br>, <br/>, <br /> → newline
        for br in ["<br/>", "<br />", "<br>"] {
            text = text.replacingOccurrences(of: br, with: "\n",
                                             options: .caseInsensitive)
        }
        // Strip all remaining tags
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>") {
            let range = NSRange(text.startIndex..., in: text)
            text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
        }
        // Decode HTML entities
        text = text
            .replacingOccurrences(of: "&amp;",  with: "&")
            .replacingOccurrences(of: "&lt;",   with: "<")
            .replacingOccurrences(of: "&gt;",   with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&#39;",  with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#xFF06;", with: "＆")
        // Collapse 3+ newlines → 2
        if let regex = try? NSRegularExpression(pattern: "\n{3,}") {
            let range = NSRange(text.startIndex..., in: text)
            text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "\n\n")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

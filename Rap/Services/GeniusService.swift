import Foundation

// MARK: - Model

struct GeniusSong {
    let id: Int
    let title: String
    let artistName: String
    let url: String
}

// MARK: - Service

struct GeniusService {

    static var accessToken: String { AppConfiguration.geniusAccessToken }
    private static let searchURL = "https://api.genius.com/search"

    // MARK: - Search

    /// Search Genius for a song. Returns the best-matching result or nil.
    static func search(title: String, artist: String) async -> GeniusSong? {
        guard !accessToken.isEmpty else {
            print("⚠️ [Genius] access token not configured")
            return nil
        }

        let query = "\(artist) \(title)"
        var comps = URLComponents(string: searchURL)!
        comps.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = comps.url else { return nil }

        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let resp = json["response"] as? [String: Any],
              let hits = resp["hits"] as? [[String: Any]]
        else {
            print("⚠️ [Genius] search failed for \"\(query)\"")
            return nil
        }

        let titleWords = title.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count >= 2 }
        let artistLower = artist.lowercased()

        for hit in hits {
            guard let result = hit["result"] as? [String: Any],
                  let hitTitle = result["title"] as? String,
                  let primaryArtist = (result["primary_artist"] as? [String: Any])?["name"] as? String,
                  let pageURL = result["url"] as? String,
                  let id = result["id"] as? Int
            else { continue }

            let hitTitleLower = hitTitle.lowercased()
            let hitArtistLower = primaryArtist.lowercased()

            // Must match title words and artist
            let titleOK = titleWords.isEmpty || titleWords.allSatisfy { hitTitleLower.contains($0) }
            let artistOK = artistLower.isEmpty
                || hitArtistLower.contains(artistLower)
                || artistLower.components(separatedBy: .whitespaces).contains(where: { hitArtistLower.contains($0) })

            if titleOK && artistOK {
                print("✅ [Genius] found: \"\(hitTitle)\" by \(primaryArtist)")
                return GeniusSong(id: id, title: hitTitle, artistName: primaryArtist, url: pageURL)
            }
        }

        print("⚠️ [Genius] no match for \"\(title)\" / \"\(artist)\"")
        return nil
    }

    // MARK: - Fetch lyrics

    /// Fetch plain-text lyrics by scraping the Genius lyrics page.
    static func fetchLyrics(song: GeniusSong) async -> String? {
        guard let url = URL(string: song.url) else { return nil }
        print("📜 [Genius] fetching lyrics from \(song.url)")

        var req = URLRequest(url: url, timeoutInterval: 15)
        // Desktop User-Agent to get full HTML (mobile may get a redirect)
        req.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let html = String(data: data, encoding: .utf8)
        else {
            print("⚠️ [Genius] failed to load lyrics page")
            return nil
        }

        let lyrics = parseLyricsFromHTML(html)
        if let l = lyrics {
            print("✅ [Genius] parsed \(l.components(separatedBy: "\n").count) lines")
        } else {
            print("⚠️ [Genius] could not parse lyrics from HTML")
        }
        return lyrics
    }

    /// One-shot convenience: search then fetch lyrics.
    static func getLyrics(title: String, artist: String) async -> String? {
        guard let song = await search(title: title, artist: artist) else { return nil }
        return await fetchLyrics(song: song)
    }

    // MARK: - HTML parsing

    private static func parseLyricsFromHTML(_ html: String) -> String? {
        var collected: [String] = []

        // Genius marks lyric containers with data-lyrics-container="true"
        let marker = "data-lyrics-container=\"true\""
        var searchStart = html.startIndex

        while let markerRange = html.range(of: marker, range: searchStart..<html.endIndex) {
            // Find the > that closes the opening tag
            guard let tagClose = html.range(of: ">", range: markerRange.upperBound..<html.endIndex) else { break }

            // Walk forward matching <div> depth to find the closing </div>
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
            let text = stripHTML(inner)
            if !text.isEmpty { collected.append(text) }

            searchStart = pos < html.endIndex ? html.index(after: pos) : html.endIndex
        }

        guard !collected.isEmpty else { return nil }
        let full = collected.joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return full.isEmpty ? nil : full
    }

    private static func stripHTML(_ raw: String) -> String {
        // Replace block-level / line breaks with newlines
        var text = raw
        for br in ["<br/>", "<br />", "<br>"] {
            text = text.replacingOccurrences(of: br, with: "\n")
        }
        // Strip remaining tags
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>") {
            let range = NSRange(text.startIndex..., in: text)
            text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
        }
        // Decode common HTML entities
        text = text
            .replacingOccurrences(of: "&amp;",  with: "&")
            .replacingOccurrences(of: "&lt;",   with: "<")
            .replacingOccurrences(of: "&gt;",   with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&#39;",  with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")

        // Collapse 3+ consecutive newlines to 2
        if let regex = try? NSRegularExpression(pattern: "\n{3,}") {
            let range = NSRange(text.startIndex..., in: text)
            text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "\n\n")
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

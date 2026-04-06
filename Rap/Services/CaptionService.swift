import Foundation

struct CaptionSegment {
    let start: Double  // seconds
    let end: Double
    let text: String
}

struct CaptionService {
    /// Fetch YouTube auto-captions. Tries Japanese then falls back.
    /// Returns empty array if no captions available.
    static func fetch(videoID: String) async -> [CaptionSegment] {
        let langs = ["ja", "ja-JP", "ja-Hira"]
        for lang in langs {
            if let segments = await fetchJSON3(videoID: videoID, lang: lang, asr: false), !segments.isEmpty {
                return segments
            }
            if let segments = await fetchJSON3(videoID: videoID, lang: lang, asr: true), !segments.isEmpty {
                return segments
            }
        }
        return []
    }

    private static func fetchJSON3(videoID: String, lang: String, asr: Bool) async -> [CaptionSegment]? {
        var comps = URLComponents(string: "https://www.youtube.com/api/timedtext")!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "v", value: videoID),
            URLQueryItem(name: "lang", value: lang),
            URLQueryItem(name: "fmt", value: "json3"),
        ]
        if asr { items.append(URLQueryItem(name: "kind", value: "asr")) }
        comps.queryItems = items
        guard let url = comps.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              !data.isEmpty,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let events = json["events"] as? [[String: Any]]
        else { return nil }

        var segments: [CaptionSegment] = []
        for event in events {
            guard let startMs = event["tStartMs"] as? Double,
                  let segs = event["segs"] as? [[String: Any]]
            else { continue }
            let durationMs = event["dDurationMs"] as? Double ?? 2000
            let text = segs
                .compactMap { $0["utf8"] as? String }
                .joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
            guard !text.isEmpty, text != " " else { continue }
            let start = startMs / 1000
            let end = (startMs + durationMs) / 1000
            segments.append(CaptionSegment(start: start, end: end, text: text))
        }
        return segments.isEmpty ? nil : segments
    }
}

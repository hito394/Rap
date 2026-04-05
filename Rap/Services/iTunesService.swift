import Foundation

struct iTunesTrack: Codable, Identifiable {
    var id: String { trackName + artistName }
    let trackName: String
    let artistName: String
    let artworkUrl100: String?
    let previewUrl: String?
    let collectionName: String?

    var artworkUrl500: String? {
        artworkUrl100?.replacingOccurrences(of: "100x100bb", with: "500x500bb")
    }
}

private struct iTunesResponse: Codable {
    let results: [iTunesTrack]
}

struct iTunesService {
    private static func fetch(_ urlString: String) async -> [iTunesTrack] {
        guard let url = URL(string: urlString),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let response = try? JSONDecoder().decode(iTunesResponse.self, from: data) else {
            return []
        }
        return response.results
    }

    // Predictive suggestions while user types title
    static func searchByTitle(query: String, limit: Int = 8) async -> [iTunesTrack] {
        guard query.count >= 2,
              let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return []
        }
        return await fetch(
            "https://itunes.apple.com/search?term=\(encoded)&country=jp&media=music&entity=song&limit=\(limit)"
        )
    }

    // Best match for known title + artist (used after decode)
    static func search(title: String, artist: String) async -> iTunesTrack? {
        let query = "\(title) \(artist)"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        let results = await fetch(
            "https://itunes.apple.com/search?term=\(encoded)&country=jp&media=music&limit=5"
        )
        let titleNorm = title.lowercased()
        let artistNorm = artist.lowercased()
        if let best = results.first(where: {
            $0.trackName.lowercased().contains(titleNorm) && $0.artistName.lowercased().contains(artistNorm)
        }) { return best }
        if let byTitle = results.first(where: { $0.trackName.lowercased().contains(titleNorm) }) {
            return byTitle
        }
        return results.first
    }
}

import Foundation

struct iTunesTrack: Codable {
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
    static func search(title: String, artist: String) async -> iTunesTrack? {
        let query = "\(title) \(artist)"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&country=jp&media=music&limit=5") else {
            return nil
        }

        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let response = try? JSONDecoder().decode(iTunesResponse.self, from: data) else {
            return nil
        }

        let titleNorm = title.lowercased()
        let artistNorm = artist.lowercased()
        // Best match: both title and artist match
        if let best = response.results.first(where: {
            $0.trackName.lowercased().contains(titleNorm) &&
            $0.artistName.lowercased().contains(artistNorm)
        }) { return best }
        // Fallback: title match only
        if let byTitle = response.results.first(where: {
            $0.trackName.lowercased().contains(titleNorm)
        }) { return byTitle }
        return response.results.first
    }
}

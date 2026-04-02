import Foundation

struct YouTubeVideo: Identifiable, Codable {
    let id: String
    let title: String
    let channelTitle: String
    let thumbnailURL: String
    let description: String
    let publishedAt: String

    var thumbnailHighURL: String {
        "https://img.youtube.com/vi/\(id)/hqdefault.jpg"
    }

    var embedURL: String {
        "https://www.youtube-nocookie.com/embed/\(id)?playsinline=1&rel=0&modestbranding=1"
    }

    var watchURL: String {
        "https://www.youtube.com/watch?v=\(id)"
    }

    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: publishedAt) else { return "" }
        let display = DateFormatter()
        display.dateFormat = "yyyy/MM"
        return display.string(from: date)
    }
}

// MARK: - Search response decoding
struct YouTubeSearchResponse: Codable {
    let items: [YouTubeSearchItem]
}

struct YouTubeSearchItem: Codable {
    let id: VideoID
    let snippet: Snippet

    struct VideoID: Codable {
        let videoId: String?
    }

    struct Snippet: Codable {
        let title: String
        let channelTitle: String
        let description: String
        let publishedAt: String
        let thumbnails: Thumbnails

        struct Thumbnails: Codable {
            let medium: Thumbnail?
            let high: Thumbnail?

            struct Thumbnail: Codable {
                let url: String
            }
        }
    }

    func toVideo() -> YouTubeVideo? {
        guard let videoId = id.videoId else { return nil }
        let thumb = snippet.thumbnails.high?.url
            ?? snippet.thumbnails.medium?.url
            ?? "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg"
        return YouTubeVideo(
            id: videoId,
            title: snippet.title,
            channelTitle: snippet.channelTitle,
            thumbnailURL: thumb,
            description: snippet.description,
            publishedAt: snippet.publishedAt
        )
    }
}

// MARK: - Video category presets
struct VideoCategory: Identifiable {
    let id = UUID()
    let label: String
    let query: String
    let emoji: String
}

extension VideoCategory {
    static let list: [VideoCategory] = [
        VideoCategory(label: "MCバトル", query: "MC battle rap Japanese", emoji: "🎤"),
        VideoCategory(label: "フリースタイル", query: "freestyle rap cypher", emoji: "🔥"),
        VideoCategory(label: "UMB", query: "UMB ultimate mc battle japan", emoji: "🏆"),
        VideoCategory(label: "KOK", query: "KOK mc battle japan", emoji: "⚔️"),
        VideoCategory(label: "高校生RAP", query: "高校生RAP選手権", emoji: "🎓"),
        VideoCategory(label: "KING OF KINGS", query: "KING OF KINGS rap battle", emoji: "👑"),
        VideoCategory(label: "サイファー", query: "hip hop cypher freestyle", emoji: "🎵"),
        VideoCategory(label: "ビーフ応酬", query: "rap beef diss track beef reaction", emoji: "💥"),
        VideoCategory(label: "BET Cypher", query: "BET hip hop awards cypher", emoji: "🇺🇸"),
        VideoCategory(label: "ドキュメンタリー", query: "hip hop documentary history", emoji: "🎬"),
    ]
}

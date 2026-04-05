import Foundation

struct MCScore: Codable {
    let name: String
    let score: Int
    let strengths: [String]
    let weaknesses: [String]
}

struct BattleJudge: Codable {
    let mc1: MCScore
    let mc2: MCScore
    let winner: String
    let decisiveMoment: String
    let battleRating: Int
    let judgeComment: String

    enum CodingKeys: String, CodingKey {
        case mc1, mc2, winner
        case decisiveMoment = "decisive_moment"
        case battleRating = "battle_rating"
        case judgeComment = "judge_comment"
    }

    static func parse(from json: String) -> BattleJudge? {
        let cleaned = json.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(BattleJudge.self, from: data)
    }
}

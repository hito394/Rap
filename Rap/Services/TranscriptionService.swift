import Foundation

struct TranscriptionService {

    // MARK: - Server URL (persisted in UserDefaults)
    static var serverURL: String {
        get { UserDefaults.standard.string(forKey: "rapServerURL") ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "rapServerURL") }
    }

    static var isConfigured: Bool { !serverURL.isEmpty }

    // MARK: - Health check (fast, 3s timeout)
    static func checkHealth() async -> Bool {
        guard !serverURL.isEmpty,
              let url = URL(string: "\(serverURL)/health")
        else { return false }
        var req = URLRequest(url: url, timeoutInterval: 3)
        req.httpMethod = "GET"
        guard let (data, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (json["status"] as? String) == "ok"
        else { return false }
        return true
    }

    // MARK: - Analyze video (long timeout for Whisper processing)
    static func analyze(
        videoID: String,
        rapper1: String = "MC1",
        rapper2: String = "MC2"
    ) async throws -> [BattleLyricEntry] {
        guard !serverURL.isEmpty, let url = URL(string: "\(serverURL)/analyze") else {
            throw TranscriptionError.notConfigured
        }

        let body: [String: Any] = [
            "url": "https://www.youtube.com/watch?v=\(videoID)",
            "rapper1": rapper1,
            "rapper2": rapper2,
        ]

        var request = URLRequest(url: url, timeoutInterval: 360) // 6min
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"] as? String
            throw TranscriptionError.serverError(http.statusCode, detail ?? "Unknown error")
        }

        let entries = try JSONDecoder().decode([BattleLyricEntry].self, from: data)
        return entries.sorted { $0.start < $1.start }
    }
}

enum TranscriptionError: LocalizedError {
    case notConfigured
    case serverError(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "サーバーURLが未設定です"
        case .serverError(let code, let msg): return "サーバーエラー (\(code)): \(msg)"
        }
    }
}

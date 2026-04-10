import Foundation
import Darwin

struct TranscriptionService {

    // MARK: - Single source of truth

    /// Fallback URL when the user has not configured anything
    static let fallbackURL = "http://10.144.156.253:8765"
    static let defaultPort = 8765

    /// The active server base URL.
    /// Priority: UserDefaults (user-entered) > fallbackURL
    /// NO simulator-specific branching — both simulator and device use the same logic.
    static var serverURL: String {
        get {
            let stored = (UserDefaults.standard.string(forKey: "rapServerURL") ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let result = stored.isEmpty ? fallbackURL : stored
            return result
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(trimmed, forKey: "rapServerURL")
            UserDefaults.standard.synchronize()
            print("🔧 [Server] URL saved → \"\(trimmed)\" (effective: \(trimmed.isEmpty ? fallbackURL : trimmed))")
        }
    }

    /// Alias kept for call-site compatibility
    static var customServerURL: String {
        get { serverURL }
        set { serverURL = newValue }
    }

    static var isConfigured: Bool { true }   // always considered configured — fallback handles it

    // MARK: - Auto-discover (real device only: scans LAN for a reachable server)

    @discardableResult
    static func autoDiscover() async -> String? {
        // If user already has a custom URL, validate it first
        let stored = (UserDefaults.standard.string(forKey: "rapServerURL") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !stored.isEmpty {
            print("🔍 [Server] autoDiscover: testing stored URL \(stored)")
            if await isReachable(stored) {
                print("✅ [Server] autoDiscover: stored URL reachable")
                return stored
            }
        }

        // Scan LAN candidates
        let candidates = buildLANCandidates()
        print("🔍 [Server] autoDiscover: scanning \(candidates.count) LAN candidates…")
        for url in candidates {
            if await isReachable(url) {
                // Do NOT overwrite user's stored URL — only log the discovery
                print("✅ [Server] autoDiscover: found reachable server at \(url)")
                return url
            }
        }
        print("⚠️ [Server] autoDiscover: no reachable server found")
        return nil
    }

    private static func buildLANCandidates() -> [String] {
        var urls: [String] = []
        if let deviceIP = deviceLANIPAddress() {
            let parts = deviceIP.components(separatedBy: ".")
            if parts.count == 4 {
                let prefix = parts.prefix(3).joined(separator: ".")
                for suffix in [1, 2, 3, 4, 5, 100, 101, 102, 103, 104, 105, 110, 150, 200] {
                    urls.append("http://\(prefix).\(suffix):\(defaultPort)")
                }
            }
        }
        for prefix in ["10.144.156", "192.168.1", "192.168.0", "10.0.0", "172.16.0"] {
            for suffix in [1, 2, 3, 100, 101, 105, 253] {
                let url = "http://\(prefix).\(suffix):\(defaultPort)"
                if !urls.contains(url) { urls.append(url) }
            }
        }
        return urls
    }

    private static func deviceLANIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(firstAddr) }
        var ptr = firstAddr
        while true {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }
        return address
    }

    // MARK: - Health check

    static func checkHealth() async -> Bool {
        let base = serverURL
        print("🏥 [Server] checkHealth → \(base)/health")
        return await isReachable(base)
    }

    private static func isReachable(_ baseURL: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else { return false }
        var req = URLRequest(url: url, timeoutInterval: 2.5)
        req.httpMethod = "GET"
        guard let (data, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (json["status"] as? String) == "ok"
        else { return false }
        return true
    }

    // MARK: - Analyze video

    static func analyze(
        videoID: String,
        rapper1: String = "MC1",
        rapper2: String = "MC2"
    ) async throws -> [BattleLyricEntry] {
        let base = serverURL
        print("🎤 [Server] analyze → \(base)/analyze  videoID=\(videoID)")
        guard let url = URL(string: "\(base)/analyze") else {
            throw TranscriptionError.notConfigured
        }

        let body: [String: Any] = [
            "url": "https://www.youtube.com/watch?v=\(videoID)",
            "rapper1": rapper1,
            "rapper2": rapper2,
        ]

        var request = URLRequest(url: url, timeoutInterval: 360)
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

    // MARK: - Transcribe

    static func transcribe(videoID: String) async -> String? {
        let base = serverURL
        print("📝 [Server] transcribe → \(base)/transcribe  videoID=\(videoID)")
        guard let url = URL(string: "\(base)/transcribe") else { return nil }
        let body: [String: Any] = ["url": "https://www.youtube.com/watch?v=\(videoID)"]
        var request = URLRequest(url: url, timeoutInterval: 180)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        guard let data = try? JSONSerialization.data(withJSONObject: body),
              _ = {request.httpBody = data; return true}() else { return nil }
        guard let (resData, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: resData) as? [String: Any],
              let text = json["transcript"] as? String else { return nil }
        return text.isEmpty ? nil : text
    }
}

enum TranscriptionError: LocalizedError {
    case notConfigured
    case serverError(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Macサーバーに接続できません\n\nMacで以下を実行してください:\ncd ~/Rap/scripts && python server.py"
        case .serverError(let code, let msg):
            return "サーバーエラー (\(code)): \(msg)"
        }
    }
}

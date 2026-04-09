import Foundation
import Darwin

struct TranscriptionService {

    // MARK: - Server URL resolution

    /// Candidate URLs tried in order during auto-detect
    static let simulatorURL = "http://127.0.0.1:8765"
    static let defaultPort  = 8765

    /// User-overridden URL (stored in UserDefaults). Empty string = use auto-detect.
    static var customServerURL: String {
        get { UserDefaults.standard.string(forKey: "rapServerURL") ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "rapServerURL") }
    }

    /// Legacy property — kept for backwards compatibility with ServerSettingsSheet.
    /// Simulator: always returns loopback (127.0.0.1:8765), no health check required.
    /// Real device: custom URL > auto-resolved URL.
    static var serverURL: String {
        get {
            if isSimulator { return customServerURL.isEmpty ? simulatorURL : customServerURL }
            let custom = customServerURL
            return custom.isEmpty ? resolvedURL : custom
        }
        set { customServerURL = newValue }
    }

    /// Simulator is always considered "configured" (loopback is implicit).
    static var isConfigured: Bool { isSimulator || !resolvedURL.isEmpty || !customServerURL.isEmpty }

    /// The last successfully reachable URL found by autoDiscover (cached in UserDefaults).
    private static var resolvedURL: String {
        get { UserDefaults.standard.string(forKey: "rapServerResolvedURL") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "rapServerResolvedURL") }
    }

    // MARK: - Auto-discover

    /// Returns true if running in the iOS Simulator
    static var isSimulator: Bool {
#if targetEnvironment(simulator)
        return true
#else
        return false
#endif
    }

    /// Try to find and cache a reachable server URL.
    /// Simulator: sets 127.0.0.1 immediately (no health check — Mac server may not be running yet).
    /// Real device: tries custom URL, then LAN subnet scan.
    @discardableResult
    static func autoDiscover() async -> String? {
        // Simulator: always loopback — set immediately without waiting for health check
        if isSimulator {
            let url = customServerURL.isEmpty ? simulatorURL : customServerURL
            resolvedURL = url   // cache so serverURL returns it right away
            // Fire-and-forget health check just to update the status indicator
            Task.detached {
                if await isReachable(url) {
                    print("✅ [TranscriptionService] Mac server is UP at \(url)")
                } else {
                    print("⚠️ [TranscriptionService] Server not reachable at \(url) — start with: python server.py")
                }
            }
            return url
        }

        // 1. If user has set a custom URL, test that first
        if !customServerURL.isEmpty {
            if await isReachable(customServerURL) {
                resolvedURL = customServerURL
                return customServerURL
            }
        }

        // 3. Real device: scan candidates
        let candidates = buildLANCandidates()
        for url in candidates {
            if await isReachable(url) {
                resolvedURL = url
                return url
            }
        }
        return nil
    }

    /// Build a list of likely Mac server URLs for common home/office LAN layouts
    private static func buildLANCandidates() -> [String] {
        var urls: [String] = []

        // Get device's own LAN IP to infer the gateway IP range
        if let deviceIP = deviceLANIPAddress() {
            // Try .1 (router) and common Mac positions on the same /24 subnet
            let parts = deviceIP.components(separatedBy: ".")
            if parts.count == 4 {
                let prefix = parts.prefix(3).joined(separator: ".")
                // Common Mac IPs on small home networks
                for suffix in [1, 2, 3, 4, 5, 100, 101, 102, 103, 104, 105, 110, 150, 200] {
                    urls.append("http://\(prefix).\(suffix):\(defaultPort)")
                }
            }
        }

        // Fallback common subnets
        for prefix in ["192.168.1", "192.168.0", "10.0.0", "172.16.0"] {
            for suffix in [1, 2, 3, 100, 101, 105] {
                let url = "http://\(prefix).\(suffix):\(defaultPort)"
                if !urls.contains(url) { urls.append(url) }
            }
        }
        return urls
    }

    /// Get the device's own IPv4 address on the local network
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
                if name == "en0" || name == "en1" {  // WiFi interface
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, 0, NI_NUMERICHOST)
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
        let url = serverURL
        guard !url.isEmpty else { return false }
        return await isReachable(url)
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

    // MARK: - Analyze video (long timeout for Whisper processing)

    static func analyze(
        videoID: String,
        rapper1: String = "MC1",
        rapper2: String = "MC2"
    ) async throws -> [BattleLyricEntry] {
        let base = serverURL
        guard !base.isEmpty, let url = URL(string: "\(base)/analyze") else {
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

    // MARK: - Transcribe lyrics via server (for track decode fallback)

    /// Ask the Mac server to transcribe a YouTube video and return plain text.
    /// Returns nil if server is unreachable or request fails.
    static func transcribe(videoID: String) async -> String? {
        let base = serverURL
        guard !base.isEmpty, let url = URL(string: "\(base)/transcribe") else { return nil }
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

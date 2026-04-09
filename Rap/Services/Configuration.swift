import Foundation

/// Centralized API key store.
/// Priority: Info.plist (xcconfig/Build Settings) → UserDefaults (entered in-app Settings)
///
/// How it works:
///   1. At build time, Secrets.xcconfig injects keys into Info.plist via $(VARIABLE_NAME)
///   2. If a key is blank (xcconfig not set up yet), the user can enter it manually
///      in the app's Settings screen — stored in UserDefaults
///   3. Services call AppConfiguration.anthropicAPIKey etc. instead of reading Bundle directly
struct AppConfiguration {

    // MARK: - Keys

    static var anthropicAPIKey: String {
        get { resolve("ANTHROPIC_API_KEY", udKey: "apiKey_anthropic") }
        set { UserDefaults.standard.set(newValue.trimmed, forKey: "apiKey_anthropic") }
    }

    static var youtubeAPIKey: String {
        get { resolve("YOUTUBE_API_KEY", udKey: "apiKey_youtube") }
        set { UserDefaults.standard.set(newValue.trimmed, forKey: "apiKey_youtube") }
    }

    static var openAIAPIKey: String {
        get { resolve("OPENAI_API_KEY", udKey: "apiKey_openai") }
        set { UserDefaults.standard.set(newValue.trimmed, forKey: "apiKey_openai") }
    }

    // MARK: - Validation helpers

    static var isAnthropicConfigured: Bool { !anthropicAPIKey.isEmpty }
    static var isYouTubeConfigured: Bool { !youtubeAPIKey.isEmpty }
    static var isOpenAIConfigured: Bool { !openAIAPIKey.isEmpty }

    // MARK: - Private

    /// Reads from Info.plist first; falls back to UserDefaults if the plist value is empty
    /// (happens when xcconfig wasn't set up at build time).
    private static func resolve(_ infoPlistKey: String, udKey: String) -> String {
        let fromPlist = (Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String ?? "").trimmed
        if !fromPlist.isEmpty && !fromPlist.hasPrefix("$(") {
            // ✅ Key loaded from xcconfig/Build Settings
            return fromPlist
        }
        let fromUD = (UserDefaults.standard.string(forKey: udKey) ?? "").trimmed
        if fromUD.isEmpty {
            // ⚠️ Key missing: neither xcconfig nor UserDefaults has a value
            print("⚠️ [Configuration] \(infoPlistKey) is not set. " +
                  "Fill Config/Secrets.xcconfig or enter in app Settings.")
        }
        return fromUD
    }

    /// Call at startup (e.g. RapApp.init) to print key status for debugging.
    static func debugPrint() {
        func source(_ plistKey: String, _ udKey: String) -> String {
            let p = (Bundle.main.object(forInfoDictionaryKey: plistKey) as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !p.isEmpty && !p.hasPrefix("$(") { return "xcconfig/plist" }
            let u = (UserDefaults.standard.string(forKey: udKey) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !u.isEmpty { return "UserDefaults" }
            return "❌ MISSING"
        }
        print("── Configuration Debug ──────────────────────────")
        print("  ANTHROPIC : \(isAnthropicConfigured ? "✅ set (\(anthropicAPIKey.prefix(12))...) [via \(source("ANTHROPIC_API_KEY","apiKey_anthropic"))]" : "❌ missing → enter in Settings screen")")
        print("  YOUTUBE   : \(isYouTubeConfigured   ? "✅ set (\(youtubeAPIKey.prefix(12))...) [via \(source("YOUTUBE_API_KEY","apiKey_youtube"))]" : "❌ missing → enter in Settings screen")")
        print("  OPENAI    : \(isOpenAIConfigured     ? "✅ set (\(openAIAPIKey.prefix(12))...) [via \(source("OPENAI_API_KEY","apiKey_openai"))]"   : "❌ missing → enter in Settings screen")")
        print("  SERVER    : \(TranscriptionService.serverURL.isEmpty ? "❌ not detected" : "✅ \(TranscriptionService.serverURL)")")
        if !isAnthropicConfigured {
            print("  ⚠️  Keys not found in xcconfig. Fix: Cmd+Shift+K → Cmd+B, or enter keys in app Settings.")
        }
        print("────────────────────────────────────────────────")
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

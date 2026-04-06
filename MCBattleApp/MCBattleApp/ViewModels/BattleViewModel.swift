import SwiftUI
import WebKit

@Observable
class BattleViewModel: NSObject {

    // MARK: - Lyric data
    var entries: [LyricEntry] = []
    var currentEntry: LyricEntry?
    var selectedEntry: LyricEntry?

    // MARK: - Playback state
    var currentTime: Double = 0
    var isPlaying: Bool = false

    // MARK: - Battle metadata
    var rapper1: String = "MC1"
    var rapper2: String = "MC2"
    var videoID: String = ""

    // MARK: - Deep dive
    var deepDiveText: String = ""
    var isDeepDiving: Bool = false
    var showDeepDive: Bool = false

    // MARK: - WKWebView reference (set by PlayerView)
    weak var webView: WKWebView?

    // MARK: - Init
    override init() {
        super.init()
        loadData()
    }

    func loadData() {
        entries = [LyricEntry].load(from: "battle")

        // Load metadata from battle_meta.json if available
        if let url = Bundle.main.url(forResource: "battle_meta", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let meta = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            rapper1 = meta["rapper1"] ?? "MC1"
            rapper2 = meta["rapper2"] ?? "MC2"
            videoID = meta["videoID"] ?? ""
        }
    }

    // MARK: - Time update from JS bridge
    func didReceiveTime(_ time: Double) {
        currentTime = time
        let matched = entries.current(at: time)
        if matched?.start != currentEntry?.start {
            currentEntry = matched
        }
    }

    // MARK: - Deep dive
    func startDeepDive(for entry: LyricEntry) {
        selectedEntry = entry
        deepDiveText = ""
        isDeepDiving = true
        showDeepDive = true

        Task { @MainActor in
            do {
                for try await chunk in OpenAIService.deepDive(
                    lyric: entry.lyric,
                    explanation: entry.explanation,
                    rapper1: rapper1,
                    rapper2: rapper2
                ) {
                    deepDiveText += chunk
                }
            } catch {
                deepDiveText = "エラー: \(error.localizedDescription)"
            }
            isDeepDiving = false
        }
    }

    func closeDeepDive() {
        showDeepDive = false
        selectedEntry = nil
        deepDiveText = ""
    }

    // MARK: - Playback control via JS
    func seekTo(_ time: Double) {
        webView?.evaluateJavaScript("player.seekTo(\(time), true);", completionHandler: nil)
    }

    func jumpToEntry(_ entry: LyricEntry) {
        seekTo(entry.start)
    }
}

// MARK: - WKScriptMessageHandler
extension BattleViewModel: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "timeUpdate":
            if let time = message.body as? Double {
                didReceiveTime(time)
            }
        case "playerReady":
            isPlaying = false
        case "playerState":
            if let state = message.body as? Int {
                // YT.PlayerState.PLAYING = 1
                isPlaying = (state == 1)
            }
        default:
            break
        }
    }
}

import SwiftUI
import WebKit

/// YouTube IFrame Player embedded in WKWebView.
/// Posts currentTime every 100ms via webkit.messageHandlers.timeUpdate
struct PlayerView: UIViewRepresentable {
    let videoID: String
    @Bindable var vm: BattleViewModel

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(vm, name: "timeUpdate")
        controller.add(vm, name: "playerReady")
        controller.add(vm, name: "playerState")

        let config = WKWebViewConfiguration()
        config.userContentController = controller
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false

        vm.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard !videoID.isEmpty else { return }
        let html = buildHTML(videoID: videoID)
        webView.loadHTMLString(html, baseURL: URL(string: "https://localhost"))
    }

    private func buildHTML(videoID: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
        <style>
        * { margin: 0; padding: 0; background: #000; box-sizing: border-box; }
        html, body { width: 100%; height: 100%; overflow: hidden; }
        #player { width: 100%; height: 100%; }
        </style>
        </head>
        <body>
        <div id="player"></div>
        <script>
        var tag = document.createElement('script');
        tag.src = "https://www.youtube.com/iframe_api";
        var firstScriptTag = document.getElementsByTagName('script')[0];
        firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

        var player;
        var ticker;

        function onYouTubeIframeAPIReady() {
          player = new YT.Player('player', {
            videoId: '\(videoID)',
            playerVars: {
              'playsinline': 1,
              'rel': 0,
              'modestbranding': 1,
              'enablejsapi': 1,
              'origin': 'https://localhost'
            },
            events: {
              'onReady': onPlayerReady,
              'onStateChange': onPlayerStateChange
            }
          });
        }

        function onPlayerReady(event) {
          window.webkit.messageHandlers.playerReady.postMessage('ready');
        }

        function onPlayerStateChange(event) {
          window.webkit.messageHandlers.playerState.postMessage(event.data);
          if (event.data == 1) { // PLAYING
            clearInterval(ticker);
            ticker = setInterval(function() {
              if (player && player.getCurrentTime) {
                var t = player.getCurrentTime();
                window.webkit.messageHandlers.timeUpdate.postMessage(t);
              }
            }, 100);
          } else {
            clearInterval(ticker);
          }
        }

        // Expose seek function callable from Swift
        function seekTo(t) {
          if (player && player.seekTo) { player.seekTo(t, true); }
        }
        </script>
        </body>
        </html>
        """
    }
}

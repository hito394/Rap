import SwiftUI
import WebKit

struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    /// Called every ~100ms with current playback time while playing.
    /// When provided, the IFrame Player API is used for full control.
    var onTimeUpdate: ((Double) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(onTimeUpdate: onTimeUpdate)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = false

        if onTimeUpdate != nil {
            let controller = WKUserContentController()
            controller.add(context.coordinator, name: "timeUpdate")
            controller.add(context.coordinator, name: "playerState")
            config.userContentController = controller
        }

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onTimeUpdate = onTimeUpdate
        let html = buildHTML(videoID: videoID, withSync: onTimeUpdate != nil)
        webView.loadHTMLString(html, baseURL: URL(string: "https://localhost"))
    }

    // MARK: - HTML builder
    private func buildHTML(videoID: String, withSync: Bool) -> String {
        let watchURL = "https://www.youtube.com/watch?v=\(videoID)"

        if withSync {
            // Full IFrame Player API with time sync
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
            document.getElementsByTagName('head')[0].appendChild(tag);
            var player, ticker;
            function onYouTubeIframeAPIReady() {
              player = new YT.Player('player', {
                videoId: '\(videoID)',
                playerVars: { playsinline: 1, rel: 0, modestbranding: 1, enablejsapi: 1, origin: 'https://localhost' },
                events: {
                  onStateChange: function(e) {
                    window.webkit.messageHandlers.playerState.postMessage(e.data);
                    if (e.data == 1) {
                      clearInterval(ticker);
                      ticker = setInterval(function() {
                        if (player && player.getCurrentTime)
                          window.webkit.messageHandlers.timeUpdate.postMessage(player.getCurrentTime());
                      }, 100);
                    } else { clearInterval(ticker); }
                  }
                }
              });
            }
            </script>
            </body>
            </html>
            """
        } else {
            // Simple embed with error detection + fallback
            let embedURL = "https://www.youtube.com/embed/\(videoID)?playsinline=1&rel=0&modestbranding=1&enablejsapi=1&origin=https://localhost"
            return """
            <!DOCTYPE html>
            <html>
            <head>
            <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
            <style>
            * { margin: 0; padding: 0; background: #000; box-sizing: border-box; }
            html, body { width: 100%; height: 100%; overflow: hidden; }
            .container { position: relative; width: 100%; padding-bottom: 56.25%; height: 0; }
            iframe { position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: 0; }
            .fallback {
              display: none; position: absolute; top: 0; left: 0; width: 100%; height: 100%;
              background: #111; flex-direction: column; align-items: center; justify-content: center;
              font-family: -apple-system, sans-serif; color: #aaa; text-align: center; padding: 20px;
            }
            .fallback a {
              display: inline-block; margin-top: 16px; padding: 12px 24px;
              background: #E8C84A; color: #000; border-radius: 20px; text-decoration: none;
              font-weight: bold; font-size: 14px;
            }
            </style>
            </head>
            <body>
            <div class="container">
              <iframe id="player" src="\(embedURL)"
                allowfullscreen allow="autoplay; encrypted-media"
                onerror="showFallback()">
              </iframe>
              <div class="fallback" id="fallback">
                <div style="font-size:32px">▶️</div>
                <p style="margin-top:12px;font-size:14px">この動画は埋め込み再生できません</p>
                <a href="\(watchURL)" target="_blank">YouTubeで開く</a>
              </div>
            </div>
            <script>
            function showFallback() {
              document.getElementById('player').style.display = 'none';
              var fb = document.getElementById('fallback');
              fb.style.display = 'flex';
            }
            window.addEventListener('message', function(e) {
              try {
                var data = JSON.parse(e.data);
                if (data.event === 'onError' && (data.info === 153 || data.info === 150 || data.info === 101)) {
                  showFallback();
                }
              } catch(err) {}
            });
            setTimeout(function() {
              try {
                var iframe = document.getElementById('player');
                if (!iframe.contentDocument || iframe.contentDocument.title === '') {}
              } catch(e) { showFallback(); }
            }, 8000);
            </script>
            </body>
            </html>
            """
        }
    }

    // MARK: - Coordinator
    class Coordinator: NSObject, WKScriptMessageHandler {
        var onTimeUpdate: ((Double) -> Void)?

        init(onTimeUpdate: ((Double) -> Void)?) {
            self.onTimeUpdate = onTimeUpdate
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "timeUpdate", let time = message.body as? Double {
                DispatchQueue.main.async { self.onTimeUpdate?(time) }
            }
        }
    }
}

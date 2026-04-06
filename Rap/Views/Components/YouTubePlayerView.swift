import SwiftUI
import WebKit

struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = false

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Use standard embed URL with origin to reduce Error 153
        let embedURL = "https://www.youtube.com/embed/\(videoID)?playsinline=1&rel=0&modestbranding=1&enablejsapi=1&origin=https://localhost"
        let watchURL = "https://www.youtube.com/watch?v=\(videoID)"
        let html = """
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
        // Detect error 153 via postMessage
        window.addEventListener('message', function(e) {
          try {
            var data = JSON.parse(e.data);
            if (data.event === 'onError' && (data.info === 153 || data.info === 150 || data.info === 101)) {
              showFallback();
            }
          } catch(err) {}
        });
        // Timeout fallback: if player doesn't load in 8s, show button
        setTimeout(function() {
          var iframe = document.getElementById('player');
          try {
            if (!iframe.contentDocument || iframe.contentDocument.title === '') {
              // player may have error, keep watching
            }
          } catch(e) {
            showFallback();
          }
        }, 8000);
        </script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: URL(string: "https://localhost"))
    }
}

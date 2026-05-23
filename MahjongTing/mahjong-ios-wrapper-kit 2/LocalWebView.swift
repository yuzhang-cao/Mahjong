import SwiftUI
import WebKit

/// 加载 App Bundle 内的静态网页资源（WebAssets/index.html）
/// 说明：这是“本地文件加载”，不依赖 http/https，也不依赖 Service Worker。
struct LocalWebView: UIViewRepresentable {

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.bounces = false
        webView.allowsBackForwardNavigationGestures = false

        loadIndexHTML(into: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 不需要在 SwiftUI 状态变化时重复加载
    }

    private func loadIndexHTML(into webView: WKWebView) {
        // 关键点：WebAssets 必须以“Folder Reference（蓝色文件夹）”方式加入工程，
        // 才能保证 Bundle 中存在真实的 WebAssets 目录结构。
        guard let indexURL = Bundle.main.url(forResource: "index",
                                             withExtension: "html",
                                             subdirectory: "WebAssets") else {
            assertionFailure("未找到 WebAssets/index.html。请确认已把 WebAssets 以 Folder Reference 方式加入工程，并勾选了目标 Target。")
            webView.loadHTMLString(Self.missingWebAssetsHTML, baseURL: nil)
            return
        }

        let dirURL = indexURL.deletingLastPathComponent()
        webView.loadFileURL(indexURL, allowingReadAccessTo: dirURL)
    }

    private static let missingWebAssetsHTML = """
    <!doctype html>
    <html lang="zh-Hans">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <style>
        body {
          margin: 0;
          min-height: 100vh;
          display: grid;
          place-items: center;
          font: -apple-system-body;
          color: #1d1d1f;
          background: #f5f5f7;
        }
        main {
          max-width: 320px;
          padding: 18px;
          border-radius: 16px;
          background: #fff;
        }
        p { margin: 8px 0 0; color: #6e6e73; }
      </style>
    </head>
    <body>
      <main>
        <strong>网页资源未找到</strong>
        <p>请确认 WebAssets/index.html 已加入 App Bundle。</p>
      </main>
    </body>
    </html>
    """
}

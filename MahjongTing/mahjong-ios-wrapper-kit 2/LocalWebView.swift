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
            return
        }

        let dirURL = indexURL.deletingLastPathComponent()
        webView.loadFileURL(indexURL, allowingReadAccessTo: dirURL)
    }
}

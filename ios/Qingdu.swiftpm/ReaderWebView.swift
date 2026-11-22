import SwiftUI
import WebKit

/// Swift 和阅读器网页之间的桥。网页准备好之前发出的调用会先排队。
@MainActor
final class ReaderBridge: NSObject, WKScriptMessageHandler {
    weak var webView: WKWebView?
    var onMessage: (([String: Any]) -> Void)?

    private var isReady = false
    private var pending: [String] = []

    func call(_ script: String) {
        if isReady, let webView {
            webView.evaluateJavaScript(script, completionHandler: nil)
        } else {
            pending.append(script)
        }
    }

    /// 把识别出的段落交给网页处理
    func load(paragraphs: [String], animate: Bool) {
        let payload: [String: Any] = ["paragraphs": paragraphs, "animate": animate]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        call("qingdu.load(\(json))")
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        if type == "ready" {
            isReady = true
            pending.forEach { webView?.evaluateJavaScript($0, completionHandler: nil) }
            pending.removeAll()
        }
        onMessage?(body)
    }
}

/// 显示 Resources/reader.html 的网页视图
struct ReaderWebView: UIViewRepresentable {
    let bridge: ReaderBridge

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(bridge, name: "qingdu")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        bridge.webView = webView
        if let url = AppResources.url("reader", "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: ()) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "qingdu")
    }
}

enum AppResources {
    /// 找打包进 App 的资源文件。Xcode 和 Swift Playgrounds 放资源的位置可能不同，两处都找。
    static func url(_ name: String, _ ext: String) -> URL? {
        if let url = Bundle.main.url(forResource: name, withExtension: ext) { return url }
        let bundles = (Bundle.main.urls(forResourcesWithExtension: "bundle", subdirectory: nil) ?? []).compactMap(Bundle.init(url:))
        for bundle in bundles {
            if let url = bundle.url(forResource: name, withExtension: ext) { return url }
        }
        return nil
    }
}

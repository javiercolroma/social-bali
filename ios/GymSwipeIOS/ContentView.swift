import SwiftUI
import WebKit

struct ContentView: View {
    var body: some View {
        WebAppView()
            .ignoresSafeArea()
            .background(Color("LaunchBackground"))
    }
}

struct WebAppView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = false

        guard let indexURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "WebDist"),
              let webDistURL = Bundle.main.url(forResource: "WebDist", withExtension: nil) else {
            webView.loadHTMLString("<html><body>Missing WebDist/index.html</body></html>", baseURL: nil)
            return webView
        }

        webView.loadFileURL(indexURL, allowingReadAccessTo: webDistURL)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}

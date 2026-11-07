import SwiftUI
import UIKit
import WebKit

@main
struct NFSMWOApp: App {
    init() {
        UIApplication.shared.isIdleTimerDisabled = true
    }

    var body: some Scene {
        WindowGroup {
            GameContainerView()
                .ignoresSafeArea()
        }
    }
}

struct GameContainerView: View {
    @State private var reloadTrigger = false
    @State private var showQuickMenu = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            NFSMWOWebView(
                url: URL(string: "https://web.nfsmwo.com")!,
                reloadTrigger: $reloadTrigger
            )
            .ignoresSafeArea()

            // Tombol menu kecil transparan di pojok kiri atas untuk opsi Reload
            Button {
                showQuickMenu = true
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(16)
            }
            .confirmationDialog("Pengaturan Game", isPresented: $showQuickMenu, titleVisibility: .visible) {
                Button("Refresh / Muat Ulang Game") {
                    reloadTrigger = true
                }
                Button("Batal", role: .cancel) {}
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
}

struct NFSMWOWebView: UIViewControllerRepresentable {
    let url: URL
    @Binding var reloadTrigger: Bool

    func makeUIViewController(context: Context) -> GameWebViewController {
        let vc = GameWebViewController(url: url)
        return vc
    }

    func updateUIViewController(_ uiViewController: GameWebViewController, context: Context) {
        if reloadTrigger {
            uiViewController.reloadGame()
            DispatchQueue.main.async {
                reloadTrigger = false
            }
        }
    }
}

class GameWebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private var webView: WKWebView!
    private let gameURL: URL

    init(url: URL) {
        self.gameURL = url
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        config.preferences = preferences

        // Skrip JS untuk memaksa viewport HTML memenuhi layar dan mencegah auto-zoom
        let jsscript = """
        var meta = document.createElement('meta');
        meta.name = 'viewport';
        meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover';
        document.getElementsByTagName('head')[0].appendChild(meta);
        
        var style = document.createElement('style');
        style.innerHTML = 'html, body { width: 100%; height: 100%; margin: 0; padding: 0; background: #000; overflow: hidden; }';
        document.getElementsByTagName('head')[0].appendChild(style);
        """
        
        let userScript = WKUserScript(source: jsscript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        config.userContentController.addUserScript(userScript)

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false

        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"

        view.addSubview(webView)
        
        let request = URLRequest(url: gameURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30.0)
        webView.load(request)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Memaksa webview menutupi seluruh layar tanpa sisa margin safe area
        webView.frame = view.bounds
    }

    func reloadGame() {
        webView.reload()
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let targetURL = navigationAction.request.url {
            webView.load(URLRequest(url: targetURL))
        }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: "NFS MW Online", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: "NFS MW Online", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ya", style: .default) { _ in completionHandler(true) })
        alert.addAction(UIAlertAction(title: "Batal", style: .cancel) { _ in completionHandler(false) })
        present(alert, animated: true)
    }
}

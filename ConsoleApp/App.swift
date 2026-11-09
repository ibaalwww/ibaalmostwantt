import SwiftUI
import UIKit
import WebKit

@main
struct NFSU2App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            GameContainerView()
                .ignoresSafeArea(.all)
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return [.landscapeLeft, .landscapeRight]
    }
}

struct GameContainerView: View {
    @State private var reloadTrigger = false
    @State private var clearStorageTrigger = false
    @State private var showQuickMenu = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            GameWebView(
                url: URL(string: "https://nfsu2.xyz")!,
                reloadTrigger: $reloadTrigger,
                clearStorageTrigger: $clearStorageTrigger
            )
            .ignoresSafeArea(.all)

            Button {
                showQuickMenu = true
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(16)
            }
            .confirmationDialog("Pengaturan Game", isPresented: $showQuickMenu, titleVisibility: .visible) {
                Button("Refresh / Muat Ulang Game") {
                    reloadTrigger = true
                }
                Button("Bersihkan Cache & Storage", role: .destructive) {
                    clearStorageTrigger = true
                }
                Button("Batal", role: .cancel) {}
            }
        }
        .background(Color.black.ignoresSafeArea(.all))
    }
}

struct GameWebView: UIViewControllerRepresentable {
    let url: URL
    @Binding var reloadTrigger: Bool
    @Binding var clearStorageTrigger: Bool

    func makeUIViewController(context: Context) -> GameWebViewController {
        return GameWebViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: GameWebViewController, context: Context) {
        if reloadTrigger {
            uiViewController.reloadGame()
            DispatchQueue.main.async {
                reloadTrigger = false
            }
        }
        if clearStorageTrigger {
            uiViewController.clearGameCache()
            DispatchQueue.main.async {
                clearStorageTrigger = false
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

    override var shouldAutorotate: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { [.landscapeLeft, .landscapeRight] }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeRight }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        UIApplication.shared.isIdleTimerDisabled = true

        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        config.preferences = preferences

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
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        loadGame()
    }

    func loadGame() {
        let request = URLRequest(url: gameURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30.0)
        webView.load(request)
    }

    func reloadGame() {
        webView.reload()
    }

    func clearGameCache() {
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let dateFrom = Date(timeIntervalSince1970: 0)
        
        dataStore.removeData(ofTypes: dataTypes, modifiedSince: dateFrom) { [weak self] in
            DispatchQueue.main.async {
                self?.reloadGame()
            }
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let targetURL = navigationAction.request.url {
            webView.load(URLRequest(url: targetURL))
        }
        return nil
    }
}

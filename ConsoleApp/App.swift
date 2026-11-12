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

// MARK: - Layar Utama Game + Dylib-Style Pop-Up Overlay
struct GameContainerView: View {
    @AppStorage("is_game_activated_v1") private var isActivated: Bool = false
    @AppStorage("saved_license_key") private var savedKey: String = ""

    @State private var reloadTrigger = false
    @State private var clearStorageTrigger = false
    @State private var showQuickMenu = false
    @State private var showFPS = true
    @StateObject private var fpsCounter = FPSCounter()

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 1. Layer Background: Game NFSU2 Langsung Tampil
            GameWebView(
                url: URL(string: "https://nfsu2.xyz")!,
                reloadTrigger: $reloadTrigger,
                clearStorageTrigger: $clearStorageTrigger
            )
            .ignoresSafeArea(.all)
            .blur(radius: isActivated ? 0 : 8) // Blur halus saat pop-up key aktif
            .allowsHitTesting(isActivated)     // Blokir sentuhan ke game sebelum key valid

            // 2. Tombol Menu Pojok Kiri Atas (Hanya aktif jika sudah unlock)
            if isActivated {
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
                    Button(showFPS ? "Sembunyikan FPS Counter" : "Tampilkan FPS Counter") {
                        showFPS.toggle()
                    }
                    Button("Bersihkan Cache & Storage", role: .destructive) {
                        clearStorageTrigger = true
                    }
                    Button("Kunci Ulang / Ganti Key", role: .destructive) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isActivated = false
                            savedKey = ""
                        }
                    }
                    Button("Batal", role: .cancel) {}
                }
            }

            // 3. FPS Overlay Pojok Kanan Atas
            if showFPS && isActivated {
                HStack {
                    Spacer()
                    Text("\(fpsCounter.fps) FPS")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.65))
                        .cornerRadius(8)
                        .padding(.top, 16)
                        .padding(.trailing, 20)
                }
                .allowsHitTesting(false)
            }

            // 4. Dylib-Style Pop-Up Dialog Overlay
            if !isActivated {
                ZStack {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea(.all)

                    DylibActivationPopup(onSuccess: { validKey in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            savedKey = validKey
                            isActivated = true
                        }
                    })
                }
                .transition(.opacity)
            }
        }
        .background(Color.black.ignoresSafeArea(.all))
        .onAppear {
            fpsCounter.start()
        }
        .onDisappear {
            fpsCounter.stop()
        }
    }
}

// MARK: - Pop-Up Bergaya Dylib / Mod Menu iOS
struct DylibActivationPopup: View {
    @Environment(\.openURL) private var openURL
    @State private var inputKey: String = ""
    @State private var errorMessage: String = ""
    @State private var isChecking: Bool = false

    let onSuccess: (String) -> Void

    // Daftar Key Offline (Bisa ditambah dari 1.000 kode tadi)
    private let localValidKeys: Set<String> = [
        "IBAAL-NFSU2-VIP",
        "IBAAL-8K9M-2P4X",
        "IBAAL-7N3V-9Q6W",
        "IBAAL-4R8T-5Z2Y",
        "IBAAL2026"
    ]

    // Opsional: Link Raw GitHub berisi daftar key (1 key per baris)
    private let remoteKeysURL: String = ""

    var body: some View {
        VStack(spacing: 14) {
            // Header Pop-up
            HStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.green)

                Text("iBaaL CERT STORE • VIP ACCESS")
                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
            }

            Text("Masukkan Access Key untuk membuka game.\nBelum punya key? Hubungi Admin di bawah:")
                .font(.system(size: 11.5))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            // Kolom Input + Tombol Unlock
            HStack(spacing: 8) {
                TextField("IBAAL-XXXX-XXXX", text: $inputKey)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .disableAutocorrection(true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(0.12))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )

                Button(action: verifyKey) {
                    if isChecking {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .frame(width: 72, height: 36)
                    } else {
                        Text("UNLOCK")
                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(width: 72, height: 36)
                    }
                }
                .background(Color.green)
                .cornerRadius(8)
                .disabled(isChecking || inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.red)
            }

            Divider()
                .background(Color.white.opacity(0.15))

            // Tombol Direct Klik WhatsApp & Telegram
            HStack(spacing: 10) {
                // Tombol WhatsApp (Otomatis isi pesan order)
                Button {
                    let text = "Halo Admin iBaaL, saya mau beli Access Key game NFS Underground 2 iOS."
                    if let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                       let url = URL(string: "https://wa.me/6285359220642?text=\(encoded)") {
                        openURL(url)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 12))
                        Text("WA: 085359220642")
                            .font(.system(size: 11.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color(red: 0.14, green: 0.65, blue: 0.35))
                    .cornerRadius(8)
                }

                // Tombol Telegram (@meugom)
                Button {
                    if let url = URL(string: "https://t.me/meugom") {
                        openURL(url)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 12))
                        Text("Tele: @meugom")
                            .font(.system(size: 11.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color(red: 0.15, green: 0.52, blue: 0.85))
                    .cornerRadius(8)
                }
            }
        }
        .padding(18)
        .frame(width: 390)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.75))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.6), radius: 20, x: 0, y: 10)
    }

    private func verifyKey() {
        let cleaned = inputKey.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        errorMessage = ""

        if localValidKeys.contains(cleaned) {
            onSuccess(cleaned)
            return
        }

        guard !remoteKeysURL.isEmpty, let url = URL(string: remoteKeysURL) else {
            errorMessage = "Key tidak valid! Silakan hubungi WA / Tele di bawah."
            return
        }

        isChecking = true
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.httpMethod = "GET"

        URLSession.shared.dataTask(with: request) { data, _, _ in
            DispatchQueue.main.async {
                isChecking = false
                if let data = data, let content = String(data: data, encoding: .utf8) {
                    let remoteKeys = content
                        .components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
                        .filter { !$0.isEmpty }

                    if remoteKeys.contains(cleaned) {
                        onSuccess(cleaned)
                    } else {
                        errorMessage = "Key salah atau sudah tidak aktif."
                    }
                } else {
                    errorMessage = "Gagal cek server. Periksa koneksi internet."
                }
            }
        }.resume()
    }
}

// MARK: - Pengukur FPS Real-Time
class FPSCounter: ObservableObject {
    @Published var fps: Int = 60
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0

    func start() {
        stop()
        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.add(to: .main, forMode: .common)
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = 0
        frameCount = 0
    }

    @objc private func update(link: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            return
        }

        frameCount += 1
        let delta = link.timestamp - lastTimestamp

        if delta >= 1.0 {
            let currentFPS = Int(round(Double(frameCount) / delta))
            DispatchQueue.main.async {
                self.fps = currentFPS
            }
            frameCount = 0
            lastTimestamp = link.timestamp
        }
    }
}

// MARK: - WebView Container & Anti-Crash Delegate
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
        config.suppressesIncrementalRendering = false

        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        config.preferences = preferences

        let webpagePrefs = WKWebpagePreferences()
        webpagePrefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = webpagePrefs

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

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.loadGame()
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let targetURL = navigationAction.request.url {
            webView.load(URLRequest(url: targetURL))
        }
        return nil
    }
}

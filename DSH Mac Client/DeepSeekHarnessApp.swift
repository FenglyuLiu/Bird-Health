import Cocoa
import WebKit

private let appName = "DeepSeek Harness"
private let serverURL = URL(string: "http://127.0.0.1:3080")!
private let workspacePath = "/Users/liufenglyu/Downloads/09 创业实践/01 笼养动物健康管理"
private let dshExecutable = "/Users/liufenglyu/.npm/_npx/1e7f6d9597241db0/node_modules/.bin/dsh"

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate {
    private var window: NSWindow!
    private var webView: WKWebView!
    private var statusLabel: NSTextField!
    private var retryButton: NSButton!
    private var serverProcess: Process?
    private var launchedServer = false
    private var retryWorkItem: DispatchWorkItem?
    private var attempts = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        buildWindow()
        window.makeKeyAndOrderFront(nil)
        connectOrLaunch()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        retryWorkItem?.cancel()
        if launchedServer, let process = serverProcess, process.isRunning {
            process.terminate()
        }
    }

    private func buildMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "退出 \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "粘贴并匹配样式", action: Selector(("pasteAsPlainText:")), keyEquivalent: "V")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu

        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "显示")
        viewMenu.addItem(withTitle: "重新载入", action: #selector(reloadPage), keyEquivalent: "r")
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(withTitle: "放大", action: #selector(zoomIn), keyEquivalent: "+")
        viewMenu.addItem(withTitle: "缩小", action: #selector(zoomOut), keyEquivalent: "-")
        viewMenu.addItem(withTitle: "实际大小", action: #selector(zoomReset), keyEquivalent: "0")
        viewMenuItem.submenu = viewMenu

        NSApp.mainMenu = mainMenu
    }

    private func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 840),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = appName
        window.titlebarAppearsTransparent = true
        window.center()
        window.setFrameAutosaveName("DeepSeekHarnessMainWindow")
        window.minSize = NSSize(width: 760, height: 560)

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsMagnification = true
        webView.autoresizingMask = [.width, .height]

        let loadingView = NSView()
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.wantsLayer = true
        loadingView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .large
        spinner.startAnimation(nil)
        spinner.translatesAutoresizingMaskIntoConstraints = false

        statusLabel = NSTextField(labelWithString: "正在连接本地 DeepSeek Harness…")
        statusLabel.font = .systemFont(ofSize: 15, weight: .medium)
        statusLabel.alignment = .center
        statusLabel.maximumNumberOfLines = 3
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        retryButton = NSButton(title: "重试", target: self, action: #selector(retryNow))
        retryButton.bezelStyle = .rounded
        retryButton.isHidden = true
        retryButton.translatesAutoresizingMaskIntoConstraints = false

        loadingView.addSubview(spinner)
        loadingView.addSubview(statusLabel)
        loadingView.addSubview(retryButton)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor, constant: -35),
            statusLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 18),
            statusLabel.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            statusLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 560),
            retryButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 18),
            retryButton.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor)
        ])

        let container = NSView()
        webView.frame = container.bounds
        container.addSubview(webView)
        container.addSubview(loadingView)
        NSLayoutConstraint.activate([
            loadingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            loadingView.topAnchor.constraint(equalTo: container.topAnchor),
            loadingView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        loadingView.identifier = NSUserInterfaceItemIdentifier("loadingView")
        window.contentView = container
    }

    private func loadingView() -> NSView? {
        window.contentView?.subviews.first(where: { $0.identifier?.rawValue == "loadingView" })
    }

    private func connectOrLaunch() {
        attempts = 0
        retryButton.isHidden = true
        statusLabel.stringValue = "正在连接本地 DeepSeek Harness…"
        loadingView()?.isHidden = false
        probeServer { [weak self] available in
            guard let self else { return }
            if available {
                self.loadApp()
            } else {
                self.launchServer()
            }
        }
    }

    private func probeServer(completion: @escaping (Bool) -> Void) {
        var request = URLRequest(url: serverURL)
        request.timeoutInterval = 1.2
        URLSession.shared.dataTask(with: request) { _, response, _ in
            let ok = (response as? HTTPURLResponse).map { (200..<500).contains($0.statusCode) } ?? false
            DispatchQueue.main.async { completion(ok) }
        }.resume()
    }

    private func launchServer() {
        guard FileManager.default.isExecutableFile(atPath: dshExecutable) else {
            showFailure("找不到 DSH。请先重新安装 DeepSeek Harness。")
            return
        }

        statusLabel.stringValue = "正在启动本地服务…"
        let logs = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/DeepSeek Harness", isDirectory: true)
        try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        let logFile = logs.appendingPathComponent("server.log")
        if !FileManager.default.fileExists(atPath: logFile.path) {
            FileManager.default.createFile(atPath: logFile.path, contents: nil)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: dshExecutable)
        process.arguments = ["web", "--host", "127.0.0.1", "--port", "3080"]
        process.currentDirectoryURL = URL(fileURLWithPath: workspacePath, isDirectory: true)
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = environment
        if let handle = try? FileHandle(forWritingTo: logFile) {
            try? handle.seekToEnd()
            process.standardOutput = handle
            process.standardError = handle
        }
        process.terminationHandler = { [weak self] task in
            guard task.terminationStatus != 0 else { return }
            DispatchQueue.main.async {
                self?.showFailure("本地服务未能启动。可查看日志：~/Library/Logs/DeepSeek Harness/server.log")
            }
        }

        do {
            try process.run()
            serverProcess = process
            launchedServer = true
            waitForServer()
        } catch {
            showFailure("无法启动本地服务：\(error.localizedDescription)")
        }
    }

    private func waitForServer() {
        attempts += 1
        probeServer { [weak self] available in
            guard let self else { return }
            if available {
                self.loadApp()
                return
            }
            if self.attempts >= 40 {
                self.showFailure("本地服务启动超时。请点“重试”，或查看服务日志。")
                return
            }
            self.statusLabel.stringValue = "正在启动本地服务…（\(self.attempts)/40）"
            let item = DispatchWorkItem { [weak self] in self?.waitForServer() }
            self.retryWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
        }
    }

    private func loadApp() {
        retryWorkItem?.cancel()
        statusLabel.stringValue = "正在载入对话界面…"
        webView.load(URLRequest(url: serverURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15))
    }

    private func showFailure(_ message: String) {
        retryWorkItem?.cancel()
        loadingView()?.isHidden = false
        statusLabel.stringValue = message
        retryButton.isHidden = false
    }

    @objc private func retryNow() {
        if serverProcess?.isRunning == true {
            attempts = 0
            retryButton.isHidden = true
            waitForServer()
        } else {
            connectOrLaunch()
        }
    }

    @objc private func reloadPage() {
        if webView.url == nil { connectOrLaunch() } else { webView.reload() }
    }

    @objc private func zoomIn() { webView.pageZoom = min(webView.pageZoom + 0.1, 2.0) }
    @objc private func zoomOut() { webView.pageZoom = max(webView.pageZoom - 0.1, 0.5) }
    @objc private func zoomReset() { webView.pageZoom = 1.0 }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadingView()?.isHidden = true
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showFailure("页面载入失败：\(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showFailure("无法连接本地服务：\(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        if url.host == "127.0.0.1" || url.host == "localhost" || url.scheme == "about" || url.scheme == "blob" {
            decisionHandler(.allow)
        } else if navigationAction.navigationType == .linkActivated {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.beginSheetModal(for: window) { response in
            completionHandler(response == .OK ? panel.urls : nil)
        }
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.activate(ignoringOtherApps: true)
application.run()

import AppKit
import WebKit

/// Full-screen window at “desktop” level: below the Finder icons, above the system wallpaper.
final class WallpaperWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class WallpaperController: NSObject, WKScriptMessageHandler {
    let window: WallpaperWindow
    let web: WKWebView
    var settingsJSON: () -> String = { "{}" }
    var onRecordProgress: ((String) -> Void)?
    private(set) var lastIconsJSON = ""
    private var paused = false
    private var currentPage = ""
    private var snapshotDone: ((String?, String?, String?) -> Void)?
    private var recordDone: ((String?, String?, String?, String?) -> Void)?
    private var timeouts: [String: Timer] = [:]
    private let holder = Holder()          // keeps the relay alive: WKUserContentController does not retain it

    init(screen: NSScreen, roots: [String: URL]) {
        window = WallpaperWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        web = WebBridge.makeWebView(handler: holder, roots: roots)
        super.init()
        holder.target = self
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.isOpaque = true
        window.backgroundColor = .black
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        web.frame = NSRect(origin: .zero, size: screen.frame.size)
        web.autoresizingMask = [.width, .height]
        window.contentView = web
        window.setFrame(screen.frame, display: false)
    }

    final class Holder: NSObject, WKScriptMessageHandler {
        weak var target: WallpaperController?
        func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) { target?.userContentController(c, didReceive: m) }
    }

    func show() { window.orderFrontRegardless() }
    func close() { web.stopLoading(); window.orderOut(nil) }

    func updateFrame(_ screen: NSScreen) { window.setFrame(screen.frame, display: true) }

    func load(page: String) {
        currentPage = page
        web.load(URLRequest(url: URL(string: "deskscape://app.local/\(page)?wallpaper=1" + (Store.ecoQuality ? "&q=1" : ""))!))
    }

    func reload() { if !currentPage.isEmpty { load(page: currentPage) } }

    func post(_ s: String) { WebBridge.post(web, s) }

    func setPaused(_ p: Bool) {
        guard p != paused else { return }
        paused = p
        post("{\"t\":\"pause\",\"v\":\(p)}")
    }

    func setIcons(_ snap: IconSnapshot) {
        let k = Double(window.screen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2)
        let rects = snap.rects.map { "[\(Int($0.l * k)),\(Int($0.t * k)),\(Int($0.r * k)),\(Int($0.b * k))]" }.joined(separator: ",")
        let json = "{\"t\":\"icons\",\"vis\":\(snap.visible),\"r\":[\(rects)]}"
        guard json != lastIconsJSON else { return }
        lastIconsJSON = json
        post(json)
    }

    // MARK: - Messages from the page

    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        guard let msg = m.body as? String else { return }
        if CommandLine.arguments.contains("--debug-messages") { NSLog("MSG page→host: %@ (%d chars)", String(msg.prefix(48)), msg.count) }
        if msg.hasPrefix("snapshot|") {
            let p = msg.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
            if p.count < 3 { finishSnapshot(nil, nil, I18n.t("errBadData")) }
            else if p[1] == "error" { finishSnapshot(nil, nil, p[2]) }
            else { finishSnapshot(p[1], p[2], nil) }
            return
        }
        if msg.hasPrefix("recprogress|") { onRecordProgress?(String(msg.dropFirst(12))); return }
        if msg.hasPrefix("record|") {
            let p = msg.split(separator: "|", maxSplits: 3, omittingEmptySubsequences: false).map(String.init)
            if p.count >= 3 && p[1] == "error" { finishRecord(nil, nil, nil, String(msg.dropFirst(13))) }
            else if p.count < 4 { finishRecord(nil, nil, nil, I18n.t("errBadData")) }
            else { finishRecord(p[1], p[2], p[3], nil) }
            return
        }
        // “ready”: settings, then icons and pause state
        post(settingsJSON())
        if !lastIconsJSON.isEmpty { post(lastIconsJSON) }
        post("{\"t\":\"pause\",\"v\":\(paused)}")
    }

    // MARK: - Partage (image / animation)

    func requestSnapshot(_ done: @escaping (String?, String?, String?) -> Void) {
        guard snapshotDone == nil else { return done(nil, nil, I18n.t("errBusyImage")) }
        snapshotDone = done
        arm("snap", 20) { [weak self] in self?.finishSnapshot(nil, nil, I18n.t("errImageTimeout")) }
        post("{\"t\":\"snapshot\"}")
    }

    func requestRecording(_ done: @escaping (String?, String?, String?, String?) -> Void) {
        guard recordDone == nil else { return done(nil, nil, nil, I18n.t("errBusyVideo")) }
        recordDone = done
        arm("rec", 45) { [weak self] in self?.finishRecord(nil, nil, nil, I18n.t("errVideoTimeout")) }
        post("{\"t\":\"record\"}")
    }

    private func arm(_ key: String, _ sec: TimeInterval, _ f: @escaping () -> Void) {
        timeouts[key]?.invalidate()
        timeouts[key] = Timer.scheduledTimer(withTimeInterval: sec, repeats: false) { _ in f() }
    }

    private func finishSnapshot(_ thumb: String?, _ png: String?, _ err: String?) {
        timeouts["snap"]?.invalidate()
        let d = snapshotDone; snapshotDone = nil
        d?(thumb, png, err)
    }

    private func finishRecord(_ mime: String?, _ poster: String?, _ video: String?, _ err: String?) {
        timeouts["rec"]?.invalidate()
        let d = recordDone; recordDone = nil
        d?(mime, poster, video, err)
    }
}

/// Semi-transparent overlay that draws the detected rectangles (calibration).
final class DebugOverlay: NSWindow {
    private let canvas = Canvas()

    final class Canvas: NSView {
        var rects: [IconRect] = []
        override var isFlipped: Bool { true }
        override func draw(_ dirtyRect: NSRect) {
            NSColor.systemRed.withAlphaComponent(0.18).setFill()
            NSColor.systemRed.setStroke()
            for r in rects {
                let p = NSBezierPath(rect: NSRect(x: r.l, y: r.t, width: r.r - r.l, height: r.b - r.t))
                p.fill(); p.lineWidth = 1; p.stroke()
            }
        }
    }

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque = false; backgroundColor = .clear; hasShadow = false; ignoresMouseEvents = true
        isReleasedWhenClosed = false
        contentView = canvas
    }

    func update(_ snap: IconSnapshot?) {
        canvas.rects = snap?.rects ?? []
        canvas.needsDisplay = true
    }
}

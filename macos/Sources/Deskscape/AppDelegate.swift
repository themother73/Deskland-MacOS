import AppKit
import ServiceManagement
import WebKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate, WKScriptMessageHandler {
    var webDir: URL!
    var wallpaper: WallpaperController?
    var settingsWindow: NSWindow?
    var settingsWeb: WKWebView?
    var overlay: DebugOverlay?
    let reader = IconReader()
    var lastSnapshot: IconSnapshot?
    var statusItem: NSStatusItem!
    var pauseItem, autostartItem, iconsItem, settingsItem, reloadItem, quitItem: NSMenuItem!
    var manualPause = false
    var snapshotRun = false
    let power = PowerMonitor()
    let metrics = Metrics()
    var themeMenu, usageMenu, powerMenu, qualityMenu: NSMenu!
    var qualityRoot, nativeItem, ecoItem: NSMenuItem!
    var themeItem, powerRoot, usageRoot, batteryItem, lowPowerItem, statusLine, cpuLine, memLine, gpuLine: NSMenuItem!
    var usageTimer: Timer?
    var pauseReason: String?
    var iconTimer: Timer?
    var saveTimer: Timer?
    var warnedPermission = false
    var lastShare: URL?
    var shareDir: URL { FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0].appendingPathComponent("Deskscape") }
    lazy var roots: [String: URL] = ["app.local": webDir, "share.local": shareDir]

    // MARK: - Launch

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)
        guard let dir = locateWebDir() else {
            let a = NSAlert(); a.messageText = "Deskscape"; a.informativeText = (Locale.preferredLanguages.first ?? "en").hasPrefix("zh") ? "找不到 web 文件夹。" : "The “web” folder could not be found."; a.runModal()
            return NSApp.terminate(nil)
        }
        webDir = dir
        let snapshotThemes = CommandLine.arguments.first { $0.hasPrefix("--snapshot=") }.map { $0.dropFirst(11).split(separator: ",").map(String.init) }
        if snapshotThemes == nil { Store.load() }       // snapshot mode: default settings, nothing is read or written
        if CommandLine.arguments.contains("--quality=eco") { Store.ecoQuality = true }
        I18n.load(webDir: webDir, setting: Store.lang)
        if let themes = snapshotThemes {
            snapshotRun = true
            let out = CommandLine.arguments.first { $0.hasPrefix("--out=") }.map { URL(fileURLWithPath: String($0.dropFirst(6))) }
                ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            startWallpaper()
            runSnapshots(themes: themes, out: out)
            return
        }
        buildStatusItem()
        startWallpaper()
        iconTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in self?.pollIcons() }
        pollIcons()
        // Dragging an icon ends with a mouse-up: re-read the positions right after (without waiting for the slow poll).
        NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self?.pollIcons() }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        if CommandLine.arguments.contains("--benchmark") { runBenchmark() }
        if CommandLine.arguments.contains("--settings") || !CommandLine.arguments.contains("--autostart") { openSettings() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings(); return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func locateWebDir() -> URL? {
        var candidates: [URL] = []
        if let env = ProcessInfo.processInfo.environment["DESKSCAPE_WEB"] { candidates.append(URL(fileURLWithPath: env)) }
        if let r = Bundle.main.resourceURL { candidates.append(r.appendingPathComponent("web")) }
        candidates.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("web"))
        let exe = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        candidates.append(exe.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("web"))
        return candidates.first { FileManager.default.fileExists(atPath: $0.appendingPathComponent("themes.json").path) }
    }

    // MARK: - Wallpaper

    func startWallpaper() {
        guard let screen = NSScreen.screens.first else { return }
        let w = WallpaperController(screen: screen, roots: roots)
        w.settingsJSON = { jsonString(["t": "settings", "v": Store.forTheme(Store.theme)]) }
        w.onRecordProgress = { [weak self] p in self?.postSettings("{\"t\":\"recProgress\",\"p\":\(p)}") }
        wallpaper = w
        w.show()
        let page = Themes.page(webDir: webDir, id: Store.theme) ?? "flat.html"
        w.load(page: page)
        NotificationCenter.default.addObserver(self, selector: #selector(occlusionChanged), name: NSWindow.didChangeOcclusionStateNotification, object: w.window)
        NotificationCenter.default.addObserver(self, selector: #selector(occlusionChanged), name: NSWorkspace.didWakeNotification, object: nil)
        power.onChange = { [weak self] in self?.updatePause() }
        updatePause()
    }

    @objc func screensChanged() {
        if let s = NSScreen.screens.first { wallpaper?.updateFrame(s); overlay?.setFrame(s.frame, display: true) }
        pollIcons()
    }

    @objc func occlusionChanged() { updatePause() }

    /// Pause: manual, desktop fully hidden (full-screen app, other Space, sleep), battery or Low Power Mode (user's choice).
    func updatePause() {
        guard let w = wallpaper else { return }
        var reason: String?
        if manualPause { reason = "reasonManual" }
        else if !w.window.occlusionState.contains(.visible) { reason = "reasonHidden" }
        else if Store.pauseOnLowPower && power.lowPowerMode { reason = "reasonLowPower" }
        else if Store.pauseOnBattery && power.onBattery { reason = "reasonBattery" }
        let wasPaused = pauseReason != nil
        pauseReason = reason
        w.setPaused(reason != nil)
        if wasPaused && reason == nil { pollIcons() }       // no polling while paused: catch up on resume
        pauseItem?.state = manualPause ? .on : .off
        let name = reason == nil ? "beach.umbrella" : "pause.circle"
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "Deskscape")
        img?.isTemplate = true
        statusItem?.button?.image = img
        refreshStatusLine()
    }

    func pollIcons() {
        if pauseReason != nil || snapshotRun { return }
        reader.read { [weak self] snap in
            guard let self = self else { return }
            if snap == nil && self.reader.permissionDenied && !self.warnedPermission {
                self.warnedPermission = true
                let a = NSAlert(); a.messageText = "Deskscape"; a.informativeText = I18n.t("errPermission"); a.runModal()
            }
            guard let snap = snap, snap != self.lastSnapshot else { return }
            self.lastSnapshot = snap
            self.wallpaper?.setIcons(snap)
            self.overlay?.update(snap)
            NSLog("Deskscape: %d icons (%@, visible=%d)", snap.rects.count, snap.mode, snap.visible ? 1 : 0)
            if let j = self.wallpaper?.lastIconsJSON { self.postSettings(j) }
        }
    }

    // MARK: - Menu bar

    func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let img = NSImage(systemSymbolName: "beach.umbrella", accessibilityDescription: "Deskscape")
            ?? NSImage(systemSymbolName: "photo", accessibilityDescription: "Deskscape")
        img?.isTemplate = true
        statusItem.button?.image = img
        let menu = NSMenu()
        settingsItem = item("", #selector(openSettingsAction))
        pauseItem = item("", #selector(togglePause))
        reloadItem = item("", #selector(reloadWallpaper))
        autostartItem = item("", #selector(toggleAutostart))
        iconsItem = item("", #selector(toggleOverlay))
        quitItem = item("", #selector(quit))

        themeItem = NSMenuItem(); themeMenu = NSMenu(); themeItem.submenu = themeMenu
        powerRoot = NSMenuItem(); powerMenu = NSMenu(); powerRoot.submenu = powerMenu
        batteryItem = item("", #selector(toggleBatteryPause)); lowPowerItem = item("", #selector(toggleLowPowerPause))
        powerMenu.addItem(batteryItem); powerMenu.addItem(lowPowerItem)
        qualityRoot = NSMenuItem(); qualityMenu = NSMenu(); qualityRoot.submenu = qualityMenu
        nativeItem = item("", #selector(setQualityNative)); ecoItem = item("", #selector(setQualityEco))
        qualityMenu.addItem(nativeItem); qualityMenu.addItem(ecoItem)
        usageRoot = NSMenuItem(); usageMenu = NSMenu(); usageRoot.submenu = usageMenu
        usageMenu.delegate = self
        statusLine = NSMenuItem(); cpuLine = NSMenuItem(); memLine = NSMenuItem(); gpuLine = NSMenuItem()
        [statusLine, cpuLine, memLine, gpuLine].forEach { $0!.isEnabled = false; usageMenu.addItem($0!) }

        [themeItem, qualityRoot, NSMenuItem.separator(), pauseItem, powerRoot, usageRoot, NSMenuItem.separator(),
         settingsItem, reloadItem, autostartItem, iconsItem, NSMenuItem.separator(), quitItem].forEach { menu.addItem($0!) }
        statusItem.menu = menu
        applyMenuTexts()
    }

    func item(_ title: String, _ sel: Selector) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: sel, keyEquivalent: ""); i.target = self; return i
    }

    func applyMenuTexts() {
        settingsItem.title = I18n.t("traySettings")
        pauseItem.title = I18n.t("trayPause")
        reloadItem.title = I18n.t("trayReload")
        autostartItem.title = I18n.t("trayAutostart")
        iconsItem.title = I18n.t("trayIcons")
        quitItem.title = I18n.t("trayExit")
        autostartItem.state = isAutostart ? .on : .off
        themeItem.title = I18n.t("menuTheme")
        powerRoot.title = I18n.t("menuPower")
        usageRoot.title = I18n.t("menuUsage")
        batteryItem.title = I18n.t("pauseBattery"); batteryItem.state = Store.pauseOnBattery ? .on : .off
        lowPowerItem.title = I18n.t("pauseLowPower"); lowPowerItem.state = Store.pauseOnLowPower ? .on : .off
        qualityRoot.title = I18n.t("menuQuality")
        nativeItem.title = I18n.t("qualityNative"); nativeItem.state = Store.ecoQuality ? .off : .on
        ecoItem.title = I18n.t("qualityEco"); ecoItem.state = Store.ecoQuality ? .on : .off
        rebuildThemeMenu()
        refreshStatusLine()
    }

    @objc func setQualityNative() { setQuality(eco: false) }
    @objc func setQualityEco() { setQuality(eco: true) }
    func setQuality(eco: Bool) {
        guard Store.ecoQuality != eco else { return }
        Store.ecoQuality = eco; Store.save(); applyMenuTexts(); wallpaper?.reload()
    }

    /// `Deskscape --benchmark`: measures CPU / memory / GPU while animating then paused, logs the result and quits.
    func runBenchmark() {
        func phase(_ label: String, seconds: Int, done: @escaping () -> Void) {
            metrics.reset(); _ = metrics.sample(pids: measuredPids())
            var cpu: [Double] = [], gpu: [Int] = [], mem: UInt64 = 0, n = 0, per: [pid_t: Double] = [:]
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
                let smp = self.metrics.sample(pids: self.measuredPids())
                if let c = smp.cpu { cpu.append(c) }; if let g = smp.gpu { gpu.append(g) }; mem = smp.memory; n += 1; for (k, v) in smp.perPid { per[k, default: 0] += v / Double(seconds) }
                if n >= seconds {
                    t.invalidate()
                    let avg = cpu.isEmpty ? 0 : cpu.reduce(0, +) / Double(cpu.count)
                    let gavg = gpu.isEmpty ? -1 : gpu.reduce(0, +) / gpu.count
                    NSLog("BENCH %@: average CPU %.1f %% (max %.1f), memory %@, average system GPU %d %%", label, avg, cpu.max() ?? 0,
                          ByteCountFormatter.string(fromByteCount: Int64(mem), countStyle: .memory), gavg)
                    NSLog("BENCH   per process (pid=avg CPU %%): %@", per.map { "\($0.key)=\(String(format: "%.1f", $0.value))" }.joined(separator: " "))
                    done()
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            phase("ANIMATION", seconds: 10) {
                self.manualPause = true; self.updatePause()
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    phase("PAUSE", seconds: 10) { NSApp.terminate(nil) }
                }
            }
        }
    }

    /// `Deskscape --snapshot=beach,meadow --out=folder`: captures, for each theme, the share image
    /// (sample icons, no real data) using a fake Mac desktop icon layout.
    func runSnapshots(themes: [String], out: URL) {
        guard let w = wallpaper, let scr = NSScreen.screens.first else { return }
        let size = scr.frame.size
        var fake: [IconRect] = []
        let cols = [7, 6, 5, 3]
        for (c, n) in cols.enumerated() {
            for r in 0..<n {
                let right = Double(size.width) - 14 - 92 * Double(c), top = 40 + 108 * Double(r)
                fake.append(IconRect(l: right - 80, t: top, r: right, b: top + 92))
            }
        }
        for (x, y) in [(430.0, 300.0), (660.0, 520.0), (300.0, 650.0), (170.0, 190.0)] {
            fake.append(IconRect(l: x, t: y, r: x + 80, b: y + 92))
        }
        var queue = themes
        func next() {
            guard !queue.isEmpty else { return NSApp.terminate(nil) }
            let id = queue.removeFirst()
            guard let page = Themes.page(webDir: webDir, id: id) else { return next() }
            Store.theme = id
            w.load(page: page)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                w.setIcons(IconSnapshot(visible: true, rects: fake, mode: "fake"))
                DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
                    w.requestSnapshot { [self] _, png, err in
                        if let png = png, let d = decodeDataURL(png) {
                            try? d.write(to: out.appendingPathComponent("macos-\(id).png"))
                            NSLog("SNAP ok %@", id)
                        } else { NSLog("SNAP erreur %@ : %@", id, err ?? "?") }
                        next()
                    }
                }
            }
        }
        next()
    }

    // MARK: - Themes, power saving, resource usage

    func themeList() -> [(id: String, name: String)] {
        guard let d = try? Data(contentsOf: webDir.appendingPathComponent("themes.json")),
              let root = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
              let list = root["themes"] as? [[String: Any]] else { return [] }
        var en: [String: Any] = [:]
        if let e = try? Data(contentsOf: webDir.appendingPathComponent("i18n/en.json")),
           let j = (try? JSONSerialization.jsonObject(with: e)) as? [String: Any] { en = (j["themes"] as? [String: Any]) ?? [:] }
        return list.compactMap { t in
            guard (t["status"] as? String) == "ready", (t["product"] as? String) == "free", let id = t["id"] as? String else { return nil }
            let enName = (en[id] as? [String: Any])?["name"] as? String
            return (id, I18n.code == "zh-CN" ? (t["name"] as? String ?? id) : (enName ?? id))
        }
    }

    func rebuildThemeMenu() {
        themeMenu.removeAllItems()
        for t in themeList() {
            let i = NSMenuItem(title: t.name, action: #selector(pickTheme(_:)), keyEquivalent: "")
            i.target = self; i.representedObject = t.id
            i.state = t.id == Store.theme ? .on : .off
            themeMenu.addItem(i)
        }
    }

    @objc func pickTheme(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        switchTheme(id)
    }

    /// Switches theme from the menu or the settings window.
    func switchTheme(_ id: String) {
        guard let page = Themes.page(webDir: webDir, id: id) else { return }
        if id != Store.theme {
            Store.theme = id; scheduleSave(); wallpaper?.load(page: page)
        }
        rebuildThemeMenu()
        postSettings(jsonString(["t": "themeChanged", "id": id]))
    }

    @objc func toggleBatteryPause() {
        Store.pauseOnBattery.toggle(); Store.save(); applyMenuTexts(); updatePause()
    }
    @objc func toggleLowPowerPause() {
        Store.pauseOnLowPower.toggle(); Store.save(); applyMenuTexts(); updatePause()
    }

    func refreshStatusLine() {
        guard statusLine != nil else { return }
        if let r = pauseReason {
            statusLine.title = "⏸ " + I18n.t("statusPaused") + " (" + I18n.t(r) + ")"
        } else {
            statusLine.title = "▶︎ " + I18n.t("statusRunning")
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === usageMenu else { return }
        metrics.reset()
        _ = metrics.sample(pids: measuredPids())       // first sample: used as the baseline
        cpuLine.title = I18n.t("usageCpu") + " : …"; memLine.title = I18n.t("usageMem") + " : …"; gpuLine.title = I18n.t("usageGpu") + " : …"
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.updateUsage() }
        RunLoop.main.add(t, forMode: .common)             // open menus run in another run loop mode
        usageTimer = t
    }

    func menuDidClose(_ menu: NSMenu) {
        guard menu === usageMenu else { return }
        usageTimer?.invalidate(); usageTimer = nil
    }

    func measuredPids() -> [pid_t] {
        var pids = [ProcessInfo.processInfo.processIdentifier]
        if let w = wallpaper?.web, let n = w.value(forKey: "_webProcessIdentifier") as? NSNumber { pids.append(n.int32Value) }
        return pids
    }

    func updateUsage() {
        let smp = metrics.sample(pids: measuredPids())
        refreshStatusLine()
        cpuLine.title = I18n.t("usageCpu") + " : " + (smp.cpu.map { String(format: "%.1f %%", $0) } ?? "…")
        memLine.title = I18n.t("usageMem") + " : " + ByteCountFormatter.string(fromByteCount: Int64(smp.memory), countStyle: .memory)
        gpuLine.title = I18n.t("usageGpu") + " : " + (smp.gpu.map { "\($0) %" } ?? "n/a")
    }

    @objc func openSettingsAction() { openSettings() }
    @objc func togglePause() { manualPause.toggle(); updatePause() }
    @objc func reloadWallpaper() { wallpaper?.reload() }
    @objc func toggleAutostart() { setAutostart(!isAutostart); applyMenuTexts() }
    @objc func quit() { wallpaper?.close(); NSApp.terminate(nil) }
    @objc func toggleOverlay() {
        if let o = overlay { o.orderOut(nil); overlay = nil; iconsItem.state = .off; return }
        guard let s = NSScreen.screens.first else { return }
        let o = DebugOverlay(screen: s)
        o.update(lastSnapshot); o.orderFrontRegardless()
        overlay = o; iconsItem.state = .on
    }

    // MARK: - Start at login

    var isAutostart: Bool { SMAppService.mainApp.status == .enabled }
    func setAutostart(_ on: Bool) {
        do { if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
        catch { NSLog("Deskscape: could not change start at login: %@", "\(error)") }
    }

    // MARK: - Settings window

    func openSettings() {
        if let w = settingsWindow { w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let web = WebBridge.makeWebView(handler: self, roots: roots)
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 800),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        w.title = "Deskscape"
        w.minSize = NSSize(width: 940, height: 680)
        w.contentView = web
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.center()
        settingsWindow = w; settingsWeb = web
        web.load(URLRequest(url: URL(string: "deskscape://app.local/settings.html?v=0.1.0")!))
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ n: Notification) {
        guard (n.object as? NSWindow) === settingsWindow else { return }
        settingsWeb?.stopLoading(); settingsWeb = nil; settingsWindow = nil
    }

    func postSettings(_ s: String) { if let w = settingsWeb { WebBridge.post(w, s) } }

    func scheduleSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { _ in Store.save() }
    }

    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        guard let s = m.body as? String, let msg = parseJSON(s), let t = msg["t"] as? String else { return }
        switch t {
        case "hello":
            let scr = NSScreen.screens.first
            let k = scr?.backingScaleFactor ?? 2
            let size = scr?.frame.size ?? CGSize(width: 1440, height: 900)
            postSettings(jsonString([
                "t": "init", "theme": Store.theme, "params": Store.params,
                "screen": ["w": Int(size.width * k), "h": Int(size.height * k)],
                "autostart": isAutostart, "autostartWarn": false, "autostartSw": "",
                "lang": Store.lang, "langEff": I18n.code, "langSys": I18n.sys,
            ]))
            if let j = wallpaper?.lastIconsJSON, !j.isEmpty { postSettings(j) }
        case "set":
            guard let theme = msg["theme"] as? String, let key = msg["key"] as? String, let value = msg["value"] else { return }
            var p = Store.forTheme(theme); p[key] = value; Store.params[theme] = p
            if theme == Store.theme { wallpaper?.post(jsonString(["t": "settings", "v": [key: value]])) }
            scheduleSave()
        case "reset":
            guard let theme = msg["theme"] as? String else { return }
            Store.params.removeValue(forKey: theme)
            if theme == Store.theme { wallpaper?.post("{\"t\":\"reset\"}") }
            scheduleSave()
        case "theme":
            guard let id = msg["id"] as? String, let page = Themes.page(webDir: webDir, id: id) else {
                postSettings(jsonString(["t": "themeChanged", "id": Store.theme])); return
            }
            _ = page
            switchTheme(id)
        case "lang":
            guard let v = msg["v"] as? String else { return }
            Store.lang = v; scheduleSave()
            I18n.load(webDir: webDir, setting: v); applyMenuTexts()
            postSettings(jsonString(["t": "lang", "v": Store.lang, "eff": I18n.code, "sys": I18n.sys]))
        case "autostart":
            setAutostart((msg["v"] as? Bool) ?? false); applyMenuTexts()
            postSettings(jsonString(["t": "autostart", "v": isAutostart]))
        case "share":
            guard let w = wallpaper else { return shareFail(I18n.t("errNotReady")) }
            w.requestSnapshot { [weak self] thumb, png, err in self?.onShareImage(thumb, png, err) }
        case "shareVideo":
            guard let w = wallpaper else { return shareFail(I18n.t("errNotReady")) }
            w.requestRecording { [weak self] mime, poster, video, err in self?.onShareVideo(mime, poster, video, err) }
        case "openShare": if let u = lastShare { NSWorkspace.shared.open(u) }
        case "revealShare": if let u = lastShare { NSWorkspace.shared.activateFileViewerSelecting([u]) }
        case "openWebsite": NSWorkspace.shared.open(URL(string: "https://github.com/BLEZZ0102/Deskland")!)
        default: break
        }
    }

    // MARK: - Partage

    func shareFail(_ msg: String) { postSettings(jsonString(["t": "shareResult", "ok": false, "msg": msg])) }

    func decodeDataURL(_ s: String) -> Data? {
        let b64 = s.firstIndex(of: ",").map { String(s[s.index(after: $0)...]) } ?? s
        return Data(base64Encoded: b64)
    }

    func stamp() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HHmmss"; return "Deskscape " + f.string(from: Date())
    }

    func onShareImage(_ thumb: String?, _ png: String?, _ err: String?) {
        guard err == nil, let png = png, let data = decodeDataURL(png) else { return shareFail(err ?? I18n.t("errNoImage")) }
        do {
            try FileManager.default.createDirectory(at: shareDir, withIntermediateDirectories: true)
            let url = shareDir.appendingPathComponent(stamp() + ".png")
            try data.write(to: url)
            lastShare = url
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setData(data, forType: .png)
            postSettings(jsonString(["t": "shareResult", "ok": true, "thumb": thumb ?? "", "path": url.path]))
        } catch { shareFail(error.localizedDescription) }
    }

    func onShareVideo(_ mime: String?, _ poster: String?, _ video: String?, _ err: String?) {
        guard err == nil, let video = video, let data = decodeDataURL(video) else { return shareFail(err ?? I18n.t("errNoVideo")) }
        do {
            try FileManager.default.createDirectory(at: shareDir, withIntermediateDirectories: true)
            let name = stamp() + (mime == "video/webm" ? ".webm" : ".mp4")
            let url = shareDir.appendingPathComponent(name)
            try data.write(to: url)
            lastShare = url
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([url as NSURL])
            let enc = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
            postSettings(jsonString(["t": "shareResult", "ok": true, "kind": "video", "thumb": poster ?? "", "path": url.path,
                                     "url": "deskscape://share.local/\(enc)", "ext": mime == "video/webm" ? "webm" : "mp4"]))
        } catch { shareFail(error.localizedDescription) }
    }
}

import Foundation

func jsonString(_ o: Any) -> String {
    guard let d = try? JSONSerialization.data(withJSONObject: o, options: [.fragmentsAllowed]),
          let s = String(data: d, encoding: .utf8) else { return "null" }
    return s
}

func parseJSON(_ s: String) -> [String: Any]? {
    guard let d = s.data(using: .utf8) else { return nil }
    return (try? JSONSerialization.jsonObject(with: d)) as? [String: Any]
}

/// User settings: current theme + parameters changed per theme (same format as Deskland).
enum Store {
    static let dir: URL = {
        let u = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Deskscape")
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }()
    static var file: URL { dir.appendingPathComponent("settings.json") }

    static var theme = "beach"
    static var lang = "auto"
    static var ecoQuality = false          // render at 1x instead of native Retina resolution
    static var pauseOnBattery = false
    static var pauseOnLowPower = true
    static var params: [String: [String: Any]] = [:]

    static func load() {
        guard let s = try? String(contentsOf: file, encoding: .utf8), let root = parseJSON(s) else { return }
        if let t = root["theme"] as? String { theme = t }
        if let l = root["lang"] as? String { lang = l }
        if let b = root["ecoQuality"] as? Bool { ecoQuality = b }
        if let b = root["pauseOnBattery"] as? Bool { pauseOnBattery = b }
        if let b = root["pauseOnLowPower"] as? Bool { pauseOnLowPower = b }
        if let p = root["params"] as? [String: [String: Any]] { params = p }
    }

    static func save() {
        let root: [String: Any] = ["version": 1, "theme": theme, "lang": lang, "params": params,
                                    "ecoQuality": ecoQuality, "pauseOnBattery": pauseOnBattery, "pauseOnLowPower": pauseOnLowPower]
        try? jsonString(root).write(to: file, atomically: true, encoding: .utf8)
    }

    static func forTheme(_ id: String) -> [String: Any] { params[id] ?? [:] }
}

/// Theme list (web/themes.json): only `ready` + `free` themes can be loaded.
enum Themes {
    static func page(webDir: URL, id: String) -> String? {
        guard let d = try? Data(contentsOf: webDir.appendingPathComponent("themes.json")),
              let root = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
              let list = root["themes"] as? [[String: Any]] else { return nil }
        guard let t = list.first(where: { ($0["id"] as? String) == id && ($0["status"] as? String) == "ready" }),
              (t["product"] as? String) == "free" else { return nil }
        return t["page"] as? String
    }
}

/// Menu texts (web/i18n/<language>.json → "host"); language: setting or system language.
enum I18n {
    static let supported = ["zh-CN", "en"]
    static var code = "en", sys = "en"
    private static var cur: [String: String] = [:], en: [String: String] = [:]

    // macOS-specific strings (the original file talks about Windows / the taskbar).
    private static let overrides: [String: [String: String]] = [
        "en": ["trayAutostart": "Start at login", "trayExit": "Quit Deskscape", "trayIcons": "Show detected icons",
               "menuTheme": "Theme", "menuQuality": "Rendering quality", "qualityNative": "Native (sharpest)", "qualityEco": "Economy (lighter on GPU)", "menuPower": "Power saving", "pauseBattery": "Pause on battery", "pauseLowPower": "Pause in Low Power Mode",
               "menuUsage": "Resource usage", "usageCpu": "CPU (Deskscape)", "usageMem": "Memory (Deskscape)", "usageGpu": "GPU (whole system)",
               "statusRunning": "Animating", "statusPaused": "Paused", "reasonManual": "manual", "reasonHidden": "desktop hidden",
               "reasonBattery": "on battery", "reasonLowPower": "Low Power Mode",
               "errPermission": "Deskscape needs permission to read your desktop icon positions.\nOpen System Settings › Privacy & Security › Automation and allow Deskscape to control Finder."],
        "zh-CN": ["trayAutostart": "登录时启动", "trayExit": "退出 Deskscape", "trayIcons": "显示检测到的图标",
                  "menuTheme": "主题", "menuQuality": "渲染质量", "qualityNative": "原生（最清晰）", "qualityEco": "节能（更省 GPU）", "menuPower": "节能", "pauseBattery": "使用电池时暂停", "pauseLowPower": "低电量模式时暂停",
                  "menuUsage": "资源占用", "usageCpu": "CPU（Deskscape）", "usageMem": "内存（Deskscape）", "usageGpu": "GPU（整个系统）",
                  "statusRunning": "动画运行中", "statusPaused": "已暂停", "reasonManual": "手动", "reasonHidden": "桌面被遮挡",
                  "reasonBattery": "使用电池", "reasonLowPower": "低电量模式",
                  "errPermission": "Deskscape 需要权限读取桌面图标位置。\n请在 系统设置 › 隐私与安全性 › 自动化 中允许 Deskscape 控制 Finder。"],
    ]

    static func load(webDir: URL, setting: String) {
        let pref = Locale.preferredLanguages.first?.lowercased() ?? "en"
        sys = pref.hasPrefix("zh") ? "zh-CN" : "en"
        code = supported.contains(setting) ? setting : sys
        en = read(webDir, "en"); cur = read(webDir, code)
    }

    private static func read(_ dir: URL, _ c: String) -> [String: String] {
        guard let d = try? Data(contentsOf: dir.appendingPathComponent("i18n/\(c).json")),
              let root = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
              let h = root["host"] as? [String: String] else { return [:] }
        return h
    }

    static func t(_ key: String, _ kv: [String: String] = [:]) -> String {
        var s = overrides[code]?[key] ?? cur[key] ?? overrides["en"]?[key] ?? en[key] ?? key
        for (k, v) in kv { s = s.replacingOccurrences(of: "{\(k)}", with: v) }
        return s
    }
}

import AppKit

/// Rectangle d'une icône du bureau, en points, origine en haut à gauche de l'écran principal.
struct IconRect: Equatable { var l, t, r, b: Double }

struct IconSnapshot: Equatable {
    var visible: Bool
    var rects: [IconRect]
    var mode: String        // "finder" (positions réelles) ou "grid" (disposition simulée)
}

/// Lit les positions des icônes du bureau via le Finder (AppleScript).
///
/// - Bureau en placement libre / « Aligner sur la grille » : le Finder donne les positions exactes.
/// - Bureau « Trié par… » : le Finder répond (-1, -1) ; on simule alors la grille
///   (colonnes remplies de haut en bas, en partant de la droite).
final class IconReader {
    // Réglages de calibration de la grille simulée (points). À ajuster avec « Afficher les icônes détectées ».
    static var pitchAdjust: Double = -16     // pitch = taille icône + espacement + pitchAdjust
    static var margin: Double = 12

    private let queue = DispatchQueue(label: "deskscape.icons")
    private var busy = false
    private(set) var permissionDenied = false
    private let script: NSAppleScript? = NSAppleScript(source: """
        tell application "Finder"
          set ps to desktop position of every item of desktop
          set ns to name of every item of desktop
          set o to icon view options of window of desktop
          return {ps, ns, icon size of o, text size of o}
        end tell
        """)

    func read(completion: @escaping (IconSnapshot?) -> Void) {
        guard !busy else { return }
        busy = true
        queue.async { [self] in
            let result = fetch()
            DispatchQueue.main.async { self.busy = false; completion(result) }
        }
    }

    private func fetch() -> IconSnapshot? {
        let prefs = UserDefaults(suiteName: "com.apple.finder")
        if prefs?.object(forKey: "CreateDesktop") as? Bool == false {
            return IconSnapshot(visible: false, rects: [], mode: "hidden")     // icônes masquées → toute la mer
        }
        var err: NSDictionary?
        guard let script = script, let desc = Optional(script.executeAndReturnError(&err)), err == nil,
              desc.numberOfItems >= 4 else {
            if let e = err, (e[NSAppleScript.errorNumber] as? Int) == -1743 { permissionDenied = true }
            else if let e = err { NSLog("Deskscape: AppleScript: \(e)") }
            return nil
        }
        permissionDenied = false
        let psDesc = desc.atIndex(1)!, nsDesc = desc.atIndex(2)!
        let iconSize = Double(desc.atIndex(3)?.int32Value ?? 48)
        let textSize = Double(desc.atIndex(4)?.int32Value ?? 11)
        let count = psDesc.numberOfItems

        var names: [String] = []
        var pos: [(Double, Double)] = []
        if count > 0 {
            for i in 1...count {
                names.append(nsDesc.atIndex(i)?.stringValue ?? "")
                let p = psDesc.atIndex(i)
                pos.append((Double(p?.atIndex(1)?.int32Value ?? -1), Double(p?.atIndex(2)?.int32Value ?? -1)))
            }
        }

        let view = (prefs?.dictionary(forKey: "DesktopViewSettings")?["IconViewSettings"] as? [String: Any]) ?? [:]
        let spacing = (view["gridSpacing"] as? Double) ?? 54
        let pitch = max(40, iconSize + spacing + Self.pitchAdjust)
        let labelH = 2 * (textSize + 3) + 4
        let halfW = (pitch - 6) / 2

        // Bureau trié (par nom, type, date…) : le Finder range lui-même les icônes et ignore les positions stockées.
        let arrange = (view["arrangeBy"] as? String) ?? "none"
        let sorted = arrange != "none" && arrange != "grid"
        var centers = pos
        var mode = "finder"
        if sorted && count > 0 {
            mode = "grid"
            let order = names.indices.sorted { names[$0].localizedStandardCompare(names[$1]) == .orderedAscending }
            let (area, menuBar) = DispatchQueue.main.sync { () -> (CGRect, Double) in
                let s = NSScreen.screens.first ?? NSScreen.main!
                return (s.visibleFrame, Double(s.frame.maxY - s.visibleFrame.maxY))
            }
            let top = max(menuBar, 0) + Self.margin
            let rows = max(1, Int((Double(area.height) - Self.margin) / pitch))
            let right = Double(area.maxX) - Self.margin
            for (slot, idx) in order.enumerated() {
                let col = slot / rows, row = slot % rows
                centers[idx] = (right - pitch * (Double(col) + 0.5), top + pitch * Double(row) + 4 + iconSize / 2)
            }
        }

        var rects: [IconRect] = []
        for (cx, cy) in centers where cx >= 0 && cy >= 0 {
            rects.append(IconRect(l: cx - halfW, t: cy - iconSize / 2 - 4, r: cx + halfW, b: cy + iconSize / 2 + 4 + labelH))
        }
        return IconSnapshot(visible: true, rects: rects, mode: mode)
    }
}

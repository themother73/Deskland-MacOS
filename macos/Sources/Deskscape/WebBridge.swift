import AppKit
import WebKit

/// Recrée `window.chrome.webview` (API WebView2) au-dessus de WKWebView,
/// pour que les pages de `web/` (issues de Deskland) tournent sans modification.
enum WebBridge {
    static let shim = """
    (function () {
      if (window.chrome && window.chrome.webview) return;
      var listeners = [];
      window.chrome = window.chrome || {};
      window.chrome.webview = {
        postMessage: function (m) { window.webkit.messageHandlers.host.postMessage(typeof m === 'string' ? m : JSON.stringify(m)); },
        addEventListener: function (t, f) { if (t === 'message') listeners.push(f); },
        removeEventListener: function (t, f) { listeners = listeners.filter(function (x) { return x !== f; }); }
      };
      window.__hostDispatch = function (s) { listeners.slice().forEach(function (f) { f({ data: s }); }); };
    })();
    """

    static func makeWebView(handler: WKScriptMessageHandler, roots: [String: URL]) -> WKWebView {
        let conf = WKWebViewConfiguration()
        let ucc = WKUserContentController()
        ucc.addUserScript(WKUserScript(source: shim, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        ucc.add(WeakHandler(handler), name: "host")
        conf.userContentController = ucc
        conf.setURLSchemeHandler(LocalSchemeHandler(roots: roots), forURLScheme: "deskscape")
        conf.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let web = WKWebView(frame: .zero, configuration: conf)
        web.setValue(false, forKey: "drawsBackground")
        return web
    }

    /// Envoie une chaîne à la page (équivalent de PostWebMessageAsString).
    static func post(_ web: WKWebView?, _ message: String) {
        guard let web = web,
              let data = try? JSONEncoder().encode(message),
              let literal = String(data: data, encoding: .utf8) else { return }
        web.evaluateJavaScript("window.__hostDispatch && window.__hostDispatch(\(literal))", completionHandler: nil)
    }
}

/// Évite le cycle de rétention WKUserContentController → handler.
final class WeakHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ t: WKScriptMessageHandler) { target = t }
    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        target?.userContentController(c, didReceive: m)
    }
}

/// Sert `deskscape://app.local/...` (dossier web) et `deskscape://share.local/...` (exports),
/// avec support des requêtes Range (lecture vidéo).
final class LocalSchemeHandler: NSObject, WKURLSchemeHandler {
    var roots: [String: URL]
    init(roots: [String: URL]) { self.roots = roots }

    private static let types = [
        "html": "text/html; charset=utf-8", "js": "text/javascript", "mjs": "text/javascript",
        "json": "application/json", "css": "text/css", "png": "image/png", "webp": "image/webp",
        "jpg": "image/jpeg", "svg": "image/svg+xml", "mp4": "video/mp4", "webm": "video/webm", "ico": "image/x-icon",
    ]

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url, let host = url.host, let root = roots[host] else { return fail(task, 404) }
        let rel = url.path.removingPercentEncoding ?? url.path
        let file = root.appendingPathComponent(rel == "/" ? "settings.html" : rel).standardizedFileURL
        guard file.path.hasPrefix(root.standardizedFileURL.path),
              let data = try? Data(contentsOf: file, options: .mappedIfSafe) else { return fail(task, 404) }
        let mime = Self.types[file.pathExtension.lowercased()] ?? "application/octet-stream"
        var status = 200
        var body = data
        var headers = ["Content-Type": mime, "Cache-Control": "no-store", "Accept-Ranges": "bytes"]
        if let range = task.request.value(forHTTPHeaderField: "Range"), range.hasPrefix("bytes="), !data.isEmpty {
            let parts = range.dropFirst(6).split(separator: "-", omittingEmptySubsequences: false)
            let start = Int(parts.first ?? "") ?? 0
            let end = parts.count > 1 ? (Int(parts[1]) ?? data.count - 1) : data.count - 1
            if start < data.count {
                let e = min(end, data.count - 1)
                body = data.subdata(in: start..<(e + 1))
                status = 206
                headers["Content-Range"] = "bytes \(start)-\(e)/\(data.count)"
            }
        }
        headers["Content-Length"] = String(body.count)
        task.didReceive(HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!)
        task.didReceive(body)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}

    private func fail(_ task: WKURLSchemeTask, _ code: Int) {
        let url = task.request.url ?? URL(string: "deskscape://app.local/")!
        task.didReceive(HTTPURLResponse(url: url, statusCode: code, httpVersion: "HTTP/1.1", headerFields: nil)!)
        task.didFinish()
    }
}

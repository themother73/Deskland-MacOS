# Deskland for macOS (unofficial port, "Deskscape")

**English** · [简体中文](README.zh-CN.md)

An unofficial, community-made macOS host for Deskland Preview. It reuses the Deskland themes and settings UI from `../prototype/` and replaces the Windows C# / WebView2 host with a native Swift (AppKit + WebKit) application. The Deskland name and icon are not used: the port ships as **Deskscape** (see [TRADEMARKS.md](../TRADEMARKS.md)).

## What it does

- Puts a full-screen window at desktop level, below the Finder icons.
- Recreates `window.chrome.webview` on `WKWebView`, so the original pages run with only a few small adaptations (`web-overlay/`).
- Reads desktop icon positions through the Finder (AppleScript). On a sorted desktop the Finder does not report positions, so the grid is simulated.
- Menu bar menu: theme, rendering quality, pause (manual, on battery, Low Power Mode), live CPU / memory / GPU usage, settings.
- Pauses by itself when the desktop is fully hidden; stops the animation loop while paused.
- Start at login (`SMAppService`), share image / video, English and Simplified Chinese.

## Install

Requires macOS 13 or later (Apple Silicon or Intel).

1. Download the `.dmg` from the Releases page and drag **Deskscape** to Applications.
2. The app is only ad hoc signed (no Apple Developer ID). If macOS blocks it, open **System Settings → Privacy & Security** and click **Open Anyway**, or run `xattr -dr com.apple.quarantine /Applications/Deskscape.app`.
3. Allow Deskscape to control the Finder when asked (**System Settings → Privacy & Security → Automation**). This is how icon positions are read.

For exact positions set the desktop to *Sort By: None* or *Snap to Grid*. Stacks are not supported. Use **Show detected icons** in the menu bar menu to check alignment.

## Build

Requirements: macOS 13+, Xcode or Command Line Tools (Swift 5.9+).

```bash
cd macos
./build.sh        # build/Deskscape.app (universal arm64 + x86_64)
./make-dmg.sh     # dist/Deskscape-<version>.dmg + SHA-256
```

`prepare-web.sh` (called by `build.sh`) generates `macos/web/` from `../prototype/` plus the files in `web-overlay/`:

| File | Change |
| --- | --- |
| `flat.html`, `meadow.html` | the animation loop stops while paused; `?q=1` renders at 1x (economy mode) |
| `i18n/en.json`, `i18n/zh-CN.json` | macOS wording (no Windows / taskbar / Microsoft Store text) |

For development: `./prepare-web.sh && swift run Deskscape`. Developer flags: `--benchmark`, `--snapshot=beach,meadow --out=DIR`, `--debug-messages`.

## Known limitations

- Main display only; Beach and Meadow only.
- Stacks unsupported; a sorted desktop uses a simulated grid (calibration constants in `IconReader.swift`).
- Not notarized; no application icon of its own.
- Measured on a single Apple Silicon Mac: about 23% of one CPU core and 54% system GPU in native quality, about 22% GPU in economy quality, about 1% CPU and 0% GPU when paused.

## License

GPL-3.0, like the rest of this repository. See [LICENSE](../LICENSE), [NOTICE](../NOTICE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

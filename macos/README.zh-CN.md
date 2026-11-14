# Deskland for macOS（非官方移植，名称 "Deskscape"）

[English](README.md) · **简体中文**

这是社区贡献的、非官方的 Deskland Preview macOS 宿主。它复用 `../prototype/` 中的 Deskland 主题与设置界面，并用原生 Swift（AppKit + WebKit）应用替换 Windows 的 C# / WebView2 宿主。移植版不使用 Deskland 名称和图标，而以 **Deskscape** 的名称发布（见 [TRADEMARKS.md](../TRADEMARKS.md)）。

## 功能

- 在桌面层创建全屏窗口，位于 Finder 图标下方。
- 在 `WKWebView` 上重建 `window.chrome.webview`，原有页面只需少量调整（`web-overlay/`）即可运行。
- 通过 Finder（AppleScript）读取桌面图标位置。桌面设置了排序时 Finder 不会返回位置，此时会模拟图标网格。
- 菜单栏菜单：主题、渲染质量、暂停（手动、使用电池、低电量模式）、实时 CPU / 内存 / GPU 占用、设置。
- 桌面被完全遮住时自动暂停，暂停期间停止动画循环。
- 登录时启动（`SMAppService`）、分享图片 / 视频、支持英文和简体中文。

## 安装

需要 macOS 13 或更高版本（Apple Silicon 或 Intel）。

1. 从 Releases 页面下载 `.dmg`，将 **Deskscape** 拖到“应用程序”。
2. 应用仅做了临时（ad hoc）签名，没有 Apple Developer ID。如果 macOS 拦截，请打开 **系统设置 → 隐私与安全性**，点击 **仍要打开**，或运行 `xattr -dr com.apple.quarantine /Applications/Deskscape.app`。
3. 出现提示时，允许 Deskscape 控制“访达”（**系统设置 → 隐私与安全性 → 自动化**）。图标位置就是这样读取的。

要获得精确位置，请把桌面设为“排序方式：无”或“对齐网格”。不支持“使用叠放”。可在菜单栏菜单中使用“显示检测到的图标”检查对齐情况。

## 构建

要求：macOS 13+，Xcode 或命令行工具（Swift 5.9+）。

```bash
cd macos
./build.sh        # build/Deskscape.app（通用二进制 arm64 + x86_64）
./make-dmg.sh     # dist/Deskscape-<version>.dmg 及 SHA-256
```

`prepare-web.sh`（由 `build.sh` 调用）会用 `../prototype/` 加上 `web-overlay/` 中的文件生成 `macos/web/`：

| 文件 | 改动 |
| --- | --- |
| `flat.html`、`meadow.html` | 暂停时停止动画循环；`?q=1` 以 1x 渲染（节能模式） |
| `i18n/en.json`、`i18n/zh-CN.json` | macOS 文案（不再出现 Windows / 任务栏 / 微软商店） |

开发时：`./prepare-web.sh && swift run Deskscape`。开发参数：`--benchmark`、`--snapshot=beach,meadow --out=DIR`、`--debug-messages`。

## 已知限制

- 仅支持主显示器，仅含沙滩和草地主题。
- 不支持“叠放”；桌面有排序时使用模拟网格（校准常量在 `IconReader.swift`）。
- 未经公证，也没有独立的应用图标。
- 仅在一台 Apple Silicon Mac 上测得：原生画质约占一个 CPU 核心的 23% 和 54% 的系统 GPU，节能画质 GPU 约 22%，暂停时 CPU 约 1%、GPU 为 0%。

## 许可

与本仓库其余部分一样采用 GPL-3.0。见 [LICENSE](../LICENSE)、[NOTICE](../NOTICE) 和 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

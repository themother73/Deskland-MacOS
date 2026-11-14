# Deskscape — an adaptive wallpaper for macOS

**English** · [Français](README.fr.md) · [Windows version (original README)](README.windows.md)

Deskscape is an **unofficial macOS adaptation** of [Deskland Preview](https://github.com/BLEZZ0102/Deskland), a Windows wallpaper that turns the space around your desktop icons into a living landscape. Move, add or remove an icon and the beach, the meadow, the clouds and their shadows quietly reshape around it, in real time. No account, no AI, no internet connection.

![Meadow](docs/images/meadow.webp)

![Beach](docs/images/beach.webp)

*Images from the original Deskland Preview.*

This project is **not affiliated with or endorsed by the Deskland authors**. The artwork and the theme code are theirs (GPL-3.0); the Mac host application is new work. See [Credits and license](#credits-and-license).

Two free themes are included: **Beach** (turquoise waves, kayaks, seabirds, palm trees) and **Meadow** (drifting clouds and shadows, a boy flying a kite, a little black cat). The other themes of the original paid edition are not part of the open-source code and are not included.

---

## Install (no technical knowledge needed)

**You need:** a Mac running macOS 13 (Ventura) or later, Apple Silicon or Intel.

1. **Download** `Deskscape-x.y.z.dmg` from the [Releases page](https://github.com/themother73/Deskland-MacOS/releases).
2. **Open** the `.dmg` and **drag Deskscape onto the Applications folder**.
3. **Open Deskscape** from Applications. The first time, macOS may say it cannot verify the app, because Deskscape is not signed with a paid Apple Developer certificate. This is expected. To allow it:
   - open **System Settings → Privacy & Security**, scroll down and click **Open Anyway** next to Deskscape, then confirm;
   - or, on older macOS versions: right-click the app, choose **Open**, then **Open** again;
   - or, in Terminal: `xattr -dr com.apple.quarantine /Applications/Deskscape.app`
4. **Allow access to the Finder.** Deskscape asks for permission to control the Finder. Click **OK**. This is how it learns where your desktop icons are. If you clicked “Don’t Allow” by mistake, enable it in **System Settings → Privacy & Security → Automation → Deskscape → Finder**.
5. The landscape appears behind your icons, and a **parasol icon** appears in the menu bar. The settings window opens each time you launch the app yourself (not when it starts at login).

**Make it start with your Mac:** menu bar icon → *Start at login*.

**Quit:** menu bar icon → *Quit Deskscape*. Your normal wallpaper comes back.

**Uninstall:** quit Deskscape, then move it from Applications to the Bin. Your settings live in `~/Library/Application Support/Deskscape` and can be deleted too.

---

## The menu bar icon

| Item | What it does |
|---|---|
| **Theme** | Switch between Beach and Meadow. |
| **Rendering quality** | *Native* is the sharpest. *Economy* draws at half resolution on Retina screens and uses far less GPU. |
| **Pause animation** | Freezes the animation (almost no CPU or GPU used while paused). |
| **Power saving** | Optionally pause when running on battery, and/or in Low Power Mode (on by default). |
| **Resource usage** | Live CPU, memory and GPU figures. |
| **Settings…** | Open the settings window: every parameter of each theme (shoreline distance, clouds, kayaks, kitten…) is saved automatically. It also creates privacy-friendly share images and videos (your real icons and file names are replaced by samples). |
| **Reload / Show detected icons** | Troubleshooting tools, see below. |

Deskscape pauses by itself when the desktop is fully hidden (full-screen app, another Space, screen asleep).

---

## Getting the best result

Deskscape reads your icon positions from the Finder. How exact that is depends on how your desktop is arranged:

- **Best:** right-click the desktop → *Sort By → None* (or *Snap to Grid*). Deskscape then gets the exact position of every icon.
- **If your desktop is sorted** (by name, kind, date…), the Finder does not reveal positions, so Deskscape **simulates the grid** in which the Finder lays icons out. This works well on most setups but can be a few pixels off.
- **Stacks** (*View → Use Stacks*) are not supported. Turn them off for accurate results.

If the landscape does not line up with your icons, use menu bar icon → **Show detected icons**: red rectangles show what Deskscape believes your icons occupy. If they are off, please [open an issue](https://github.com/themother73/Deskland-MacOS/issues) with a screenshot, your icon size (*View → Show View Options*) and your macOS version.

---

## Troubleshooting

| Problem | What to try |
|---|---|
| The landscape does not react to my icons | Check **System Settings → Privacy & Security → Automation → Deskscape → Finder**. Then menu bar icon → *Reload*. |
| Nothing appears at all | Quit and relaunch Deskscape. Make sure the animation is not paused (menu bar icon). |
| The Mac gets warm / battery drains | Menu bar icon → *Rendering quality → Economy*, and enable *Pause on battery*. |
| Only one screen is covered | Expected: only the main display is supported for now. |
| macOS refuses to open the app | See step 3 of the installation above. |

---

## Build from source

Requirements: macOS 13+, Xcode or the Command Line Tools (Swift 5.9+).

```bash
git clone https://github.com/themother73/Deskland-MacOS.git
cd Deskland-MacOS/macos
./build.sh        # builds build/Deskscape.app (universal arm64 + x86_64)
./make-dmg.sh     # builds dist/Deskscape-<version>.dmg and its SHA-256
```

More details for developers are in [macos/README.md](macos/README.md).

---

## How this repository is organized (macOS and Windows)

This is a **fork** of Deskland Preview. The original Windows code is kept untouched on purpose, so that the macOS port can keep receiving upstream updates and shares the very same themes.

| Folder | Contents |
|---|---|
| [`macos/`](macos/) | **The macOS app** (Swift): everything that is new in this fork. |
| `prototype/` | Themes, settings page and artwork from Deskland, **shared by both platforms and unmodified**. The macOS build copies it and applies a few adaptations from `macos/web-overlay/`. |
| `host/`, `tools/` | The original **Windows** host (C# / WebView2) and installer tooling. Not used by the Mac app. |
| `docs/` | Images used in the READMEs. |

**On Windows?** Use the official Deskland Preview: [latest release](https://github.com/BLEZZ0102/Deskland/releases/latest). The original README is in [README.windows.md](README.windows.md).

---

## Known limitations

- Main display only.
- Beach and Meadow only.
- Stacks are not supported, and a sorted desktop uses a simulated grid (see above).
- Signed ad hoc only (no Apple Developer ID, not notarized): macOS shows a warning at first launch.
- No application icon of its own yet.
- Performance was measured on a single Apple Silicon Mac: about 23% of one CPU core and 54% GPU (whole system) in native quality, about 22% GPU in Economy quality, and about 1% CPU and 0% GPU when paused.

---

## Credits and license

- Original project, themes, artwork and settings interface: **Deskland Preview** by the Deskland authors, [github.com/BLEZZ0102/Deskland](https://github.com/BLEZZ0102/Deskland) (v0.1.3).
- macOS host application and adaptations: this fork.
- License: **GPL-3.0**, same as the original. See [LICENSE](LICENSE), [NOTICE](NOTICE) and [macos/THIRD_PARTY_NOTICES.md](macos/THIRD_PARTY_NOTICES.md).
- The Deskland name and icon are not licensed as trademarks ([TRADEMARKS.md](TRADEMARKS.md)). This port therefore ships under its own name, *Deskscape*, and makes clear that it is an independent adaptation.

#!/bin/zsh
# Construit Deskscape.app (binaire universel arm64 + x86_64, dossier web/ embarqué) dans ./build
set -euo pipefail
cd "$(dirname "$0")"
VERSION=$(cat VERSION)
./prepare-web.sh
swift build -c release --arch arm64 --arch x86_64
BIN=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Deskscape
APP=build/Deskscape.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Deskscape"
cp -R web "$APP/Contents/Resources/web"
cp ../LICENSE ../NOTICE ../TRADEMARKS.md THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>app.deskscape.mac</string>
  <key>CFBundleName</key><string>Deskscape</string>
  <key>CFBundleDisplayName</key><string>Deskscape</string>
  <key>CFBundleExecutable</key><string>Deskscape</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>GPL-3.0. Dérivé de Deskland Preview.</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>Deskscape lit la position des icônes du bureau via le Finder pour adapter le paysage.</string>
</dict></plist>
PLIST
# Signature ad hoc (usage local / partage sans compte développeur Apple)
codesign --force --deep --sign - "$APP"
echo "OK → $APP ($VERSION, $(lipo -archs "$APP/Contents/MacOS/Deskscape"))"

#!/bin/zsh
# Builds dist/Deskscape-<version>.dmg from build/Deskscape.app
set -euo pipefail
cd "$(dirname "$0")"
VERSION=$(cat VERSION)
[ -d build/Deskscape.app ] || ./build.sh
STAGE=$(mktemp -d)
cp -R build/Deskscape.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
mkdir -p dist
OUT="dist/Deskscape-$VERSION.dmg"
rm -f "$OUT"
hdiutil create -volname "Deskscape" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$OUT"
rm -rf "$STAGE"
( cd dist && shasum -a 256 "Deskscape-$VERSION.dmg" > "Deskscape-$VERSION.dmg.sha256" )
echo "OK → $OUT"; cat "dist/Deskscape-$VERSION.dmg.sha256"

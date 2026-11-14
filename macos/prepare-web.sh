#!/bin/zsh
# Generates macos/web = prototype/ (original Deskland themes, unmodified) + web-overlay/ (macOS adaptations)
set -euo pipefail
cd "$(dirname "$0")"
rm -rf web
cp -R ../prototype web
rm -f web/serve.mjs
cp -R web-overlay/. web/
echo "OK → macos/web"

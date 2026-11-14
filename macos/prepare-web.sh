#!/bin/zsh
# Génère macos/web = prototype/ (thèmes Deskland d'origine, non modifiés) + web-overlay/ (adaptations macOS)
set -euo pipefail
cd "$(dirname "$0")"
rm -rf web
cp -R ../prototype web
rm -f web/serve.mjs
cp -R web-overlay/. web/
echo "OK → macos/web"

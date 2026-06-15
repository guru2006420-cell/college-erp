#!/usr/bin/env bash
#
# Build + deploy the Flutter web bundle for hosting at
# https://app.iceberglc.com/app/
#
# IMPORTANT: --base-href MUST be /app/. The Django route only serves the bundle
# under /app/ (see college_management_system/urls.py: ^app(?P<path>/.*)$), so a
# default build (base href "/") makes every asset request hit the site root and
# 404 — the app then shows a blank screen with no splash and no login. Forgetting
# this flag has broken the web app twice; always build through this script.
#
set -euo pipefail

cd "$(dirname "$0")"

flutter build web --release --base-href /app/

DEST="../../web/flutter_web"
rm -rf "$DEST"
mkdir -p "$DEST"
cp -r build/web/. "$DEST/"

echo "✓ Flutter web built with base href /app/ and deployed to web/flutter_web/"

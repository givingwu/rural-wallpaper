#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

rural_wallpaper_tag="${1:?Usage: bash scripts/package-release.sh vX.Y.Z}"
python3 scripts/check-version.py "$rural_wallpaper_tag"
test "$(git rev-parse HEAD)" = "$(git rev-parse "refs/tags/$rural_wallpaper_tag^{commit}")"
git diff --quiet
git diff --cached --quiet

swift test --quiet
bash scripts/build-app.sh
git archive --format=zip --prefix=RuralWallpaper/ --output=dist/RuralWallpaper-source.zip HEAD
cd dist
shasum -a 256 RuralWallpaper-macOS-arm64.zip RuralWallpaper-source.zip > SHA256SUMS.txt
shasum -a 256 -c SHA256SUMS.txt

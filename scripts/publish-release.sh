#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

rural_wallpaper_tag="${1:?Usage: bash scripts/publish-release.sh vX.Y.Z}"
python3 scripts/check-version.py "$rural_wallpaper_tag"
test "$(git rev-parse HEAD)" = "$(git rev-parse "refs/tags/$rural_wallpaper_tag^{commit}")"
# Reruns may replace draft assets, but must never overwrite a published release.
test "$(gh release view "$rural_wallpaper_tag" --json isDraft --jq .isDraft)" = true
cd dist
shasum -a 256 -c SHA256SUMS.txt
gh release upload "$rural_wallpaper_tag" RuralWallpaper-macOS-arm64.zip RuralWallpaper-source.zip SHA256SUMS.txt --clobber
gh release view "$rural_wallpaper_tag" --json body --jq .body > release-notes.md
python3 - <<'PY'
from pathlib import Path

path = Path("release-notes.md")
body = path.read_text()
marker = "<!-- rural-wallpaper-installation -->"
if marker not in body:
    path.write_text(
        body
        + "\n\n"
        + marker
        + "\n"
        + "Download `RuralWallpaper-macOS-arm64.zip` for macOS 14+ on Apple Silicon. "
        + "This build is ad-hoc signed and is **not Apple-notarized**. "
        + "`SHA256SUMS.txt` verifies the app and source archives.\n"
    )
PY
rural_wallpaper_prerelease=false
[[ "$rural_wallpaper_tag" != v0.* ]] || rural_wallpaper_prerelease=true
gh release edit "$rural_wallpaper_tag" --draft=false --prerelease="$rural_wallpaper_prerelease" --notes-file release-notes.md

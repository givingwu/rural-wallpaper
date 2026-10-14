#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

python3 scripts/check-version.py
swift build -c release --arch arm64
rural_wallpaper_bin_dir="$(swift build -c release --arch arm64 --show-bin-path)"
rural_wallpaper_app="dist/RuralWallpaper.app"
mkdir -p "$rural_wallpaper_app/Contents/MacOS" "$rural_wallpaper_app/Contents/Resources"
cp "$rural_wallpaper_bin_dir/RuralWallpaperApp" "$rural_wallpaper_app/Contents/MacOS/RuralWallpaperApp"
cp Resources/Info.plist "$rural_wallpaper_app/Contents/Info.plist"
if [[ -n "${RURAL_WALLPAPER_BUILD_NUMBER:-}" ]]; then
    [[ "$RURAL_WALLPAPER_BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || { echo "Invalid build number" >&2; exit 1; }
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $RURAL_WALLPAPER_BUILD_NUMBER" "$rural_wallpaper_app/Contents/Info.plist"
fi
swift scripts/make-app-icon.swift .build/AppIcon.iconset
iconutil -c icns .build/AppIcon.iconset -o "$rural_wallpaper_app/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$rural_wallpaper_app"
codesign --verify --deep --strict --verbose=2 "$rural_wallpaper_app"
ditto -c -k --sequesterRsrc --keepParent "$rural_wallpaper_app" dist/RuralWallpaper-macOS-arm64.zip
echo "Built dist/RuralWallpaper.app and dist/RuralWallpaper-macOS-arm64.zip"

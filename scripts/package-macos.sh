#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_ID="${1:-$(date +%Y%m%d-%H%M%S)}"
APP_NAME="RuralWallpaper-${PACKAGE_ID}"
DIST_DIR="${ROOT_DIR}/dist"
APP_PATH="${DIST_DIR}/${APP_NAME}.app"
ZIP_PATH="${DIST_DIR}/${APP_NAME}.zip"
ICONSET_PATH="${DIST_DIR}/${APP_NAME}.iconset"
ICON_PATH="${APP_PATH}/Contents/Resources/AppIcon.icns"

if [[ "${PACKAGE_ID}" == v* ]]; then
  VERSION="${PACKAGE_ID#v}"
else
  VERSION="0.1.0"
fi

BINARY_PATH="${BINARY_PATH:-$(find "${ROOT_DIR}/.build" -path "*/release/RuralWallpaperApp" -type f -print -quit)}"
if [[ -z "${BINARY_PATH}" ]]; then
  echo "Release binary not found. Run: swift build -c release" >&2
  exit 1
fi

rm -rf "${APP_PATH}" "${ZIP_PATH}" "${ICONSET_PATH}"
mkdir -p "${APP_PATH}/Contents/MacOS" "${APP_PATH}/Contents/Resources"
cp "${BINARY_PATH}" "${APP_PATH}/Contents/MacOS/RuralWallpaperApp"
chmod +x "${APP_PATH}/Contents/MacOS/RuralWallpaperApp"

swift "${ROOT_DIR}/scripts/make-app-icon.swift" "${ICONSET_PATH}"
iconutil -c icns "${ICONSET_PATH}" -o "${ICON_PATH}"

cat > "${APP_PATH}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>RuralWallpaperApp</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>com.ruralwallpaper.app</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>Rural Wallpaper</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>${VERSION}</string>
	<key>CFBundleVersion</key>
	<string>$(date +%Y%m%d.%H%M%S)</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
</dict>
</plist>
PLIST

plutil -lint "${APP_PATH}/Contents/Info.plist"
codesign --force --deep --sign - "${APP_PATH}"
codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"
rm -rf "${ICONSET_PATH}"

echo "${APP_PATH}"
echo "${ZIP_PATH}"

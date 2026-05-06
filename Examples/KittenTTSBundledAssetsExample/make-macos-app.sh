#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

swift build

bin_path="$(swift build --show-bin-path)"
app_path="$PWD/build/KittenTTSBundledAssetsExample.app"
contents_path="$app_path/Contents"
macos_path="$contents_path/MacOS"
resources_path="$contents_path/Resources"
executable_name="KittenTTSBundledAssetsExample"

rm -rf "$app_path"
mkdir -p "$macos_path" "$resources_path"
cp "$bin_path/$executable_name" "$macos_path/$executable_name"

cat > "$contents_path/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>KittenTTSBundledAssetsExample</string>
    <key>CFBundleIdentifier</key>
    <string>com.kittenml.KittenTTSBundledAssetsExample</string>
    <key>CFBundleName</key>
    <string>KittenTTS Bundled Assets</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
PLIST

if [ -d "assets/kittentts" ]; then
    cp -R "assets/kittentts" "$resources_path/kittentts"
fi

echo "$app_path"

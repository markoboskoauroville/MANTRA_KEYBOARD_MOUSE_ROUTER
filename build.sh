#!/bin/sh
# build.sh: Keyboard and Mouse Router (Mantra).app - swiftc straight, no Xcode, signed "Mantra Apps"
set -e
cd "$(dirname "$0")"
V=$(sed -n 's/^let VERSION = \([0-9]*\)/\1/p' app/App.swift)
NAME="Keyboard and Mouse Router (Mantra)"
APP="build/$NAME.app"
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -swift-version 5 -parse-as-library -target arm64-apple-macos14.0 -o build/KMRouter-arm64 app/*.swift
swiftc -O -swift-version 5 -parse-as-library -target x86_64-apple-macos14.0 -o build/KMRouter-x86_64 app/*.swift
lipo -create build/KMRouter-arm64 build/KMRouter-x86_64 -output "$APP/Contents/MacOS/KMRouter"
# the icon: six letters over a cursor on black (icon/README.md)
if [ -f icon/six_1024.png ]; then
  I=build/AppIcon.iconset; rm -rf $I; mkdir -p $I
  for sz in 16 32 128 256 512; do
    sips -z $sz $sz icon/six_1024.png --out $I/icon_${sz}x${sz}.png >/dev/null
    sips -z $((sz*2)) $((sz*2)) icon/six_1024.png --out $I/icon_${sz}x${sz}@2x.png >/dev/null
  done
  iconutil -c icns $I -o "$APP/Contents/Resources/AppIcon.icns"
fi
cat > "$APP/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleName</key><string>$NAME</string>
<key>CFBundleDisplayName</key><string>$NAME</string>
<key>CFBundleIdentifier</key><string>community.auroville.keyboardmouserouter</string>
<key>CFBundleExecutable</key><string>KMRouter</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$V</string>
<key>CFBundleVersion</key><string>$V</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PL
codesign --force --deep -s "${SIGN:-Mantra Apps}" "$APP" 2>/dev/null || codesign --force --deep -s - "$APP"
echo "built $APP (v$V)"
[ -n "$NO_INSTALL" ] || { rm -rf "/Applications/$NAME.app"; cp -R "$APP" /Applications/; echo "installed"; }

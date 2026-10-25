#!/bin/zsh
set -eu

cd "${0:A:h}"
BUILD="$PWD/.build-tests"
mkdir -p "$BUILD"

/usr/bin/xcrun swiftc -O \
    -module-cache-path "$BUILD/module-cache" \
    Sources/Localization.swift Sources/TimezoneCatalog.swift Tests/TimezoneCatalogTests.swift \
    -o "$BUILD/timezone-tests"
"$BUILD/timezone-tests"

./build.sh arm64 >/dev/null
/usr/bin/codesign --verify --deep --strict "dist/Time Traveler.app"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "dist/Time Traveler.app/Contents/Info.plist" | /usr/bin/grep -qx 'TimeTraveler.icns'
test -s "dist/Time Traveler.app/Contents/Resources/TimeTraveler.icns"
print 'PASS Time Traveler 构建、时区目录和应用图标'

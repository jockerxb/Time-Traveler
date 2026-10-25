#!/bin/zsh
set -eu

cd "${0:A:h}"
ARCH="${1:-universal}"
case "$ARCH" in
    universal) ARCHS=(arm64 x86_64) ;;
    arm64|x86_64) ARCHS=("$ARCH") ;;
    *) print -u2 'Usage: ./build.sh [universal|arm64|x86_64]'; exit 2 ;;
esac

BUILD="$PWD/.build"
APP="$PWD/dist/Time Traveler.app"
mkdir -p "$BUILD" "$APP/Contents/MacOS" "$APP/Contents/Resources"

for CPU in "${ARCHS[@]}"; do
    /usr/bin/xcrun swiftc -O -parse-as-library \
        -module-cache-path "$BUILD/module-cache-$CPU" \
        -target "$CPU-apple-macosx13.0" \
        Sources/Localization.swift Sources/TimezoneCatalog.swift Sources/AppModel.swift Sources/main.swift \
        -o "$BUILD/TimeTraveler-$CPU" \
        -framework SwiftUI -framework AppKit
done

if [[ "$ARCH" == universal ]]; then
    /usr/bin/lipo -create "$BUILD/TimeTraveler-arm64" "$BUILD/TimeTraveler-x86_64" -output "$APP/Contents/MacOS/TimeTraveler"
else
    /bin/cp "$BUILD/TimeTraveler-$ARCH" "$APP/Contents/MacOS/TimeTraveler"
fi

/usr/bin/python3 build-icon.py >/dev/null

/bin/cp Info.plist "$APP/Contents/Info.plist"
/bin/cp "$BUILD/TimeTraveler.icns" "$APP/Contents/Resources/TimeTraveler.icns"
/usr/bin/codesign --force --deep --sign - "$APP"
/usr/bin/codesign --verify --deep --strict "$APP"
/usr/bin/touch "$APP"
print "$APP"

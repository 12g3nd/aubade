#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Run this script on macOS with full Xcode installed." >&2
    exit 1
fi

if ! xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1; then
    echo "Open Xcode, complete first launch, and install the iOS platform." >&2
    echo "If needed, select Xcode in Xcode > Settings > Locations > Command Line Tools." >&2
    exit 1
fi

mkdir -p build
BUILD_DIR="$(mktemp -d "$PWD/build/run.XXXXXX")"
exec > >(tee "$BUILD_DIR/build.log") 2>&1
echo "Building unsigned iPhone app in $BUILD_DIR"
xcodebuild -version
xcodebuild \
    -project AubadeTrial.xcodeproj \
    -target AubadeTrial \
    -configuration Release \
    -sdk iphoneos \
    "SYMROOT=$BUILD_DIR/products" \
    "OBJROOT=$BUILD_DIR/intermediates" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    'CODE_SIGN_IDENTITY=' \
    build

APP="$BUILD_DIR/products/Release-iphoneos/AubadeTrial.app"
test -d "$APP"
plutil -lint "$APP/Info.plist"
test -x "$APP/AubadeTrial"
mkdir -p "$BUILD_DIR/package/Payload"
ditto "$APP" "$BUILD_DIR/package/Payload/AubadeTrial.app"
(
    cd "$BUILD_DIR/package"
    /usr/bin/zip -q -r "$BUILD_DIR/AubadeTrial-unsigned.ipa" Payload
)
/usr/bin/unzip -t "$BUILD_DIR/AubadeTrial-unsigned.ipa"
echo ""
echo "Send this file back: $BUILD_DIR/AubadeTrial-unsigned.ipa"
echo "It is unsigned. The recipient signs and installs it with Sideloadly."
open -R "$BUILD_DIR/AubadeTrial-unsigned.ipa"

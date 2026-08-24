#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/ParaBear.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
RESOURCE_BUNDLE="ParaBear_ParaBear.bundle"

# Built fresh. SwiftPM copies resources into the bundle but never removes ones that have gone from
# the source tree, so an incremental build keeps shipping deleted artwork — three files that no
# longer exist were still riding along in the .app before this line.
rm -rf "$ROOT_DIR/.build/release/$RESOURCE_BUNDLE"

swift build -c release --package-path "$ROOT_DIR"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/.build/release/ParaBear" "$MACOS_DIR/ParaBear"
cp "$ROOT_DIR/Packaging/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Sources/ParaBear/Resources/PrivacyInfo.xcprivacy" "$RESOURCES_DIR/PrivacyInfo.xcprivacy"
# The icon is generated, not stored: `Assets/AppIcon.png` is the picture, and the .icns is built
# from the same code that drew it. Each size is rendered at its own scale rather than resampled
# down from 1024 — the paw's toes are small enough at 16pt that resampling turns them to mush.
ICONSET="$ROOT_DIR/.build/AppIcon.iconset"
rm -rf "$ICONSET"
swift "$ROOT_DIR/Scripts/make_icon.swift" "$ICONSET" "$ROOT_DIR/Sources/ParaBear/Assets/AppIcon.png"
iconutil -c icns "$ICONSET" -o "$RESOURCES_DIR/AppIcon.icns"

# The SVG art lives in a bundle SwiftPM builds separately, and without this the packaged app has
# no artwork at all — its only other candidate is an absolute path into *this* machine's .build
# directory, so it would run here and trap with "could not load resource bundle" anywhere else.
#
# It goes in Contents/Resources, where a bundle belongs. Not the .app root, which is where
# `Bundle.module` would look: a loose bundle there is "unsealed contents present in the bundle
# root" and the signature stops verifying. `Bundle.packagedResources` is what looks here instead.
cp -R "$ROOT_DIR/.build/release/$RESOURCE_BUNDLE" "$RESOURCES_DIR/$RESOURCE_BUNDLE"

# Anything the art was downloaded with rides along into the bundle otherwise; a quarantined file
# inside a signed app is untidy at best and refuses to open at worst.
xattr -cr "$APP_DIR"

codesign --force --sign - --entitlements "$ROOT_DIR/Packaging/ParaBear.entitlements" "$APP_DIR"

echo "$APP_DIR"

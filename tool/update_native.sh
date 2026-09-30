#!/usr/bin/env bash
# Replaces native/ with the libraries of an offline_first_core release.
#
#   tool/update_native.sh 0.6.2
#
# Downloads the assets of the GitHub release v<version>, checks them against
# the release's SHA256SUMS and lays them out as hook/build.dart expects:
# native/<os>/<architecture>/<library>, one architecture per file (the Apple
# binaries are split with lipo). Requires curl, unzip, shasum and lipo (macOS).
set -euo pipefail

VERSION="${1:?usage: tool/update_native.sh <offline_first_core version>}"
URL="https://github.com/JhonaCodes/offline_first_core/releases/download/v$VERSION"
LIB=liboffline_first_core
cd "$(dirname "$0")/.."

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
ASSETS=(
  SHA256SUMS
  OfflineFirstCore.xcframework.zip
  "$LIB-android-jniLibs.zip"
  "$LIB-macos-universal.dylib"
  "$LIB-linux-x86_64.so"
  "$LIB-linux-aarch64.so"
  offline_first_core-windows-x86_64.dll
  offline_first_core-windows-arm64.dll
)
for asset in "${ASSETS[@]}"; do
  curl -fsSL -o "$WORK/$asset" "$URL/$asset"
done
(cd "$WORK" && shasum -a 256 -c SHA256SUMS)

rm -rf native
place() { # <file> <destination under native/>
  mkdir -p "native/$(dirname "$2")"
  cp "$1" "native/$2"
}
thin() { # <universal binary> <architecture> <destination under native/>
  mkdir -p "native/$(dirname "$3")"
  lipo "$1" -thin "$2" -output "native/$3"
}

unzip -q "$WORK/$LIB-android-jniLibs.zip" -d "$WORK/android"
place "$WORK/android/arm64-v8a/$LIB.so" "android/arm64/$LIB.so"
place "$WORK/android/armeabi-v7a/$LIB.so" "android/arm/$LIB.so"
place "$WORK/android/x86/$LIB.so" "android/ia32/$LIB.so"
place "$WORK/android/x86_64/$LIB.so" "android/x64/$LIB.so"

unzip -q "$WORK/OfflineFirstCore.xcframework.zip" -d "$WORK"
FRAMEWORKS="$WORK/OfflineFirstCore.xcframework"
SIMULATOR="$FRAMEWORKS/ios-arm64_x86_64-simulator/OfflineFirstCore.framework/OfflineFirstCore"
place "$FRAMEWORKS/ios-arm64/OfflineFirstCore.framework/OfflineFirstCore" "ios/iphoneos-arm64/$LIB.dylib"
thin "$SIMULATOR" arm64 "ios/iphonesimulator-arm64/$LIB.dylib"
thin "$SIMULATOR" x86_64 "ios/iphonesimulator-x64/$LIB.dylib"
thin "$WORK/$LIB-macos-universal.dylib" arm64 "macos/arm64/$LIB.dylib"
thin "$WORK/$LIB-macos-universal.dylib" x86_64 "macos/x64/$LIB.dylib"

place "$WORK/$LIB-linux-x86_64.so" "linux/x64/$LIB.so"
place "$WORK/$LIB-linux-aarch64.so" "linux/arm64/$LIB.so"
place "$WORK/offline_first_core-windows-x86_64.dll" "windows/x64/offline_first_core.dll"
place "$WORK/offline_first_core-windows-arm64.dll" "windows/arm64/offline_first_core.dll"

echo "$VERSION" > native/VERSION
(cd native && find . -type f ! -name SHA256SUMS ! -name VERSION -print0 | sort -z | xargs -0 shasum -a 256 > SHA256SUMS)
echo "native/ holds offline_first_core $VERSION"

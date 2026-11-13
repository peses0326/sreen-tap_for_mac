#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-module-cache"
swift build -c release --product ScreenTap --disable-sandbox
bin_dir=$(swift build -c release --show-bin-path --disable-sandbox)
app_path="$PWD/dist/ScreenTap.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$bin_dir/ScreenTap" "$app_path/Contents/MacOS/ScreenTap"
cp Resources/AppIcon.icns "$app_path/Contents/Resources/AppIcon.icns"
cp LICENSE NOTICE.md "$app_path/Contents/Resources/"
cp Resources/Info.plist "$app_path/Contents/Info.plist"
cp -R Resources/en.lproj Resources/ko.lproj "$app_path/Contents/Resources/"
# Use SIGN_IDENTITY for a stable local signing certificate; default is ad-hoc personal use.
codesign --force --sign "${SIGN_IDENTITY:--}" --identifier local.espark.screentap "$app_path"
codesign --verify --strict "$app_path"
echo "$app_path"

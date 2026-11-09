#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-module-cache"
swift build -c release --disable-sandbox
bin_dir=$(swift build -c release --show-bin-path --disable-sandbox)
app_path="$PWD/dist/LeanTab.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$bin_dir/LeanTab" "$app_path/Contents/MacOS/LeanTab"
cp Resources/Info.plist "$app_path/Contents/Info.plist"
cp -R Resources/en.lproj Resources/ko.lproj "$app_path/Contents/Resources/"
# Use SIGN_IDENTITY for a stable local signing certificate; default is ad-hoc personal use.
codesign --force --sign "${SIGN_IDENTITY:--}" --identifier local.espark.LeanTab "$app_path"
codesign --verify --strict "$app_path"
echo "$app_path"

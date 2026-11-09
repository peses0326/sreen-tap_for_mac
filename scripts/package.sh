#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
./scripts/build.sh
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
arch_name=$(uname -m)
if [[ "$arch_name" != arm64 ]]; then
  echo "This release is currently validated for Apple Silicon (arm64)." >&2
  exit 1
fi
zip_path="$PWD/dist/ScreenTap-macOS-arm64.zip"
if [[ -f "$zip_path" ]]; then rm "$zip_path"; fi
ditto -c -k --sequesterRsrc --keepParent dist/ScreenTap.app "$zip_path"
(
  cd dist
  shasum -a 256 ScreenTap-macOS-arm64.zip > SHA256SUMS
)
echo "Packaged ScreenTap $version: $zip_path"
if [[ "${1:-}" == --dmg ]]; then
  stage_dir=$(mktemp -d "$PWD/.build/dmg.XXXXXX")
  trap 'rm -rf "$stage_dir"' EXIT
  ditto dist/ScreenTap.app "$stage_dir/ScreenTap.app"
  ln -s /Applications "$stage_dir/Applications"
  cp LICENSE NOTICE.md "$stage_dir/"
  hdiutil create -volname ScreenTap -srcfolder "$stage_dir" -ov -format UDZO "dist/ScreenTap-$version-arm64.dmg"
  ( cd dist; shasum -a 256 "ScreenTap-$version-arm64.dmg" >> SHA256SUMS )
fi

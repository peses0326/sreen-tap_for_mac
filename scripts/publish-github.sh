#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
repo=peses0326/sreen-tap_for_mac
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Commit the source changes before publishing." >&2; exit 1
fi
login=$(gh api user --jq .login)
if [[ "$login" != peses0326 ]]; then
  echo "Expected GitHub account peses0326; current account is $login." >&2; exit 1
fi
./scripts/test.sh
python3 scripts/check-site.py
./scripts/package.sh
if ! gh repo view "$repo" --json nameWithOwner --jq .nameWithOwner; then
  gh repo create "$repo" --public --description 'A native macOS window switcher with thumbnail previews and bounded memory.'
fi
visibility=$(gh repo view "$repo" --json visibility --jq .visibility)
if [[ "$visibility" != PUBLIC ]]; then
  echo "The existing repository is not public. Review its contents before making it public." >&2; exit 1
fi
if git remote get-url origin >/dev/null 2>&1; then
  remote=$(git remote get-url origin)
  if [[ "$remote" != "https://github.com/$repo.git" && "$remote" != "git@github.com:$repo.git" ]]; then
    echo "Origin points to a different repository: $remote" >&2; exit 1
  fi
else
  git remote add origin "https://github.com/$repo.git"
fi
git push -u origin main
if gh api "repos/$repo/pages" >/dev/null 2>&1; then
  gh api --method PUT "repos/$repo/pages" -f build_type=workflow >/dev/null
else
  gh api --method POST "repos/$repo/pages" -f build_type=workflow >/dev/null
fi
if git rev-parse "v$version" >/dev/null 2>&1; then
  [[ "$(git rev-list -n 1 "v$version")" == "$(git rev-parse HEAD)" ]] || { echo "Release tag points to another commit." >&2; exit 1; }
else
  git tag -a "v$version" -m "ScreenTap $version"
fi
git push origin "v$version"
gh release create "v$version" dist/ScreenTap-macOS-arm64.zip dist/SHA256SUMS --verify-tag --title "ScreenTap $version" --notes-file "docs/release-$version.md" --latest
gh workflow run pages.yml --ref main
gh repo view "$repo" --json url --jq .url
gh release view "v$version" --json url --jq .url
echo "Pages deployment requested; check Actions for the final deployment URL."

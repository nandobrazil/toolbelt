#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"

version="$(tr -d '[:space:]' < VERSION)"
releases_repo="${TOOLBELT_RELEASES_REPO:-nandobrazil/toolbelt}"
site_url="${TOOLBELT_SITE_URL:-https://toolbelt.oconde.dev/}"
disk_image="dist/Toolbelt-$version.dmg"
archive="dist/Toolbelt-$version.zip"
manifest="dist/latest.json"

for file in "$disk_image" "$archive" "$manifest"; do
  [ -f "$file" ] || { echo "missing $file, run scripts/release.sh first" >&2; exit 1; }
done
xcrun stapler validate "$disk_image"
if gh release view "v$version" --repo "$releases_repo" >/dev/null 2>&1; then
  echo "v$version already exists in $releases_repo" >&2
  exit 1
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
cp "$disk_image" "$work_dir/Toolbelt.dmg"
awk -v version="$version" '
  /^## / { inside = ($2 == version); next }
  inside { print }
' CHANGELOG.md > "$work_dir/notes.md"

if ! git rev-parse "v$version" >/dev/null 2>&1; then
  git tag -a "v$version" -m "Toolbelt $version"
fi
git push origin "v$version"

gh release create "v$version" \
  --repo "$releases_repo" \
  --verify-tag \
  --title "Toolbelt $version" \
  --notes-file "$work_dir/notes.md" \
  --latest \
  "$disk_image" "$archive" "$work_dir/Toolbelt.dmg" "$manifest"

published="$(curl -fsSL "${site_url%/}/updates/latest.json" | plutil -extract version raw -o - -)"
echo "feed now announces $published"
[ "$published" = "$version" ]

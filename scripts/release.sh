#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"

version="$(tr -d '[:space:]' < VERSION)"
notary_profile="${TOOLBELT_NOTARY_PROFILE:-toolbelt-notary}"
releases_repo="${TOOLBELT_RELEASES_REPO:-nandobrazil/toolbelt}"
download_base_url="${TOOLBELT_DOWNLOAD_BASE_URL:-https://github.com/${releases_repo}/releases/download/v${version}}"
site_url="${TOOLBELT_SITE_URL:-https://toolbelt.oconde.dev/}"
build_memory_limit_mb="${TOOLBELT_BUILD_MEMORY_MB:-4096}"
dist_dir="$project_dir/dist"
app="$dist_dir/Toolbelt.app"
archive="$dist_dir/Toolbelt-$version.zip"
disk_image="$dist_dir/Toolbelt-$version.dmg"

identity="${TOOLBELT_RELEASE_IDENTITY:-$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)}"
if [ -z "$identity" ]; then
  echo "no 'Developer ID Application' identity in the keychain (see docs/releasing.md)" >&2
  exit 1
fi
if [ -n "${TOOLBELT_NOTARY_APPLE_ID:-}" ]; then
  notary_auth=(--apple-id "$TOOLBELT_NOTARY_APPLE_ID" --team-id "$TOOLBELT_NOTARY_TEAM_ID" --password "$TOOLBELT_NOTARY_PASSWORD")
else
  notary_auth=(--keychain-profile "$notary_profile")
fi
if ! xcrun notarytool history "${notary_auth[@]}" >/dev/null 2>&1; then
  echo "notarization credentials rejected (profile '$notary_profile' or TOOLBELT_NOTARY_* variables, see docs/releasing.md)" >&2
  exit 1
fi
radar_key="${TOOLBELT_RADAR_KEY:-$(security find-generic-password -s "Toolbelt Radar key" -w 2>/dev/null || true)}"
if [[ ! "$radar_key" =~ ^rk_[A-Za-z0-9]{40}$ ]]; then
  echo "no Radar ingest key in the keychain item 'Toolbelt Radar key' (see docs/releasing.md)" >&2
  exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
  echo "commit or stash your changes before releasing" >&2
  exit 1
fi
if ! grep -q "^## $version" CHANGELOG.md; then
  echo "CHANGELOG.md has no '## $version' section" >&2
  exit 1
fi

notarize() {
  local file="$1"
  local result
  result="$(xcrun notarytool submit "$file" "${notary_auth[@]}" --wait --output-format json)"
  local status
  status="$(printf '%s' "$result" | plutil -extract status raw -o - -)"
  if [ "$status" != "Accepted" ]; then
    local submission
    submission="$(printf '%s' "$result" | plutil -extract id raw -o - -)"
    echo "notarization of $(basename "$file") ended as '$status'" >&2
    xcrun notarytool log "$submission" "${notary_auth[@]}" >&2 || true
    exit 1
  fi
  echo "notarized $(basename "$file")"
}

if command -v memcap >/dev/null 2>&1; then
  memcap "$build_memory_limit_mb" -- swift build -c release --arch arm64 --arch x86_64
else
  swift build -c release --arch arm64 --arch x86_64
fi
binary="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Toolbelt"

rm -rf "$dist_dir"
mkdir -p "$dist_dir"
TOOLBELT_UPDATE_FEED_URL="${site_url%/}/updates/latest.json" TOOLBELT_RADAR_KEY="$radar_key" TOOLBELT_RADAR_ENVIRONMENT=production scripts/assemble-app.sh "$binary" "$app"
codesign --force --options runtime --timestamp --entitlements Resources/Toolbelt.entitlements --sign "$identity" "$app"
codesign --verify --deep --strict --verbose=2 "$app"

ditto -c -k --keepParent "$app" "$dist_dir/notarization.zip"
notarize "$dist_dir/notarization.zip"
rm "$dist_dir/notarization.zip"
xcrun stapler staple "$app"
spctl --assess --type execute --verbose "$app"

ditto -c -k --keepParent "$app" "$archive"

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
cp -R "$app" "$staging/"
ln -s /Applications "$staging/Applications"
hdiutil create -volname "Toolbelt $version" -srcfolder "$staging" -ov -format UDZO -fs HFS+ "$disk_image" >/dev/null
codesign --force --timestamp --sign "$identity" "$disk_image"
notarize "$disk_image"
xcrun stapler staple "$disk_image"
spctl --assess --type open --context context:primary-signature --verbose "$disk_image"

python3 -I - "$version" "$(git rev-list --count HEAD)" "$download_base_url" "$site_url" "$archive" CHANGELOG.md "$dist_dir/latest.json" <<'PYTHON'
import hashlib
import json
import pathlib
import sys

version, build, base_url, site_url, archive, changelog, output = sys.argv[1:]
notes = []
inside = False
for line in pathlib.Path(changelog).read_text().splitlines():
    if line.startswith("## "):
        inside = line[3:].split()[0] == version
        continue
    if inside and line.startswith("- "):
        notes.append(line[2:].strip())
manifest = {
    "version": version,
    "build": int(build),
    "minimumSystemVersion": "14.0",
    "archiveURL": f"{base_url.rstrip('/')}/{pathlib.Path(archive).name}",
    "archiveSHA256": hashlib.sha256(pathlib.Path(archive).read_bytes()).hexdigest(),
    "downloadPageURL": site_url,
    "notes": notes,
}
pathlib.Path(output).write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
PYTHON

echo
echo "release $version ready in $dist_dir:"
ls -lh "$dist_dir"
echo "next: scripts/publish-release.sh"

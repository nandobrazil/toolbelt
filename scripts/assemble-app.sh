#!/bin/bash
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "usage: $0 <executable> <app-dir>" >&2
  exit 64
fi

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
executable="$1"
app_dir="$2"
version="$(tr -d '[:space:]' < "$project_dir/VERSION")"
build_number="$(git -C "$project_dir" rev-list --count HEAD)"
feed_url="${TOOLBELT_UPDATE_FEED_URL:-https://toolbelt.oconde.dev/updates/latest.json}"
radar_key="${TOOLBELT_RADAR_KEY:-}"
radar_environment="${TOOLBELT_RADAR_ENVIRONMENT:-development}"
radar_url="${TOOLBELT_RADAR_URL:-https://radar-ingest.oconde.dev/api/v1/events}"
year="$(date +%Y)"

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources/bin"
cp "$executable" "$app_dir/Contents/MacOS/Toolbelt"
cp "$project_dir/Resources/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"
cp "$project_dir/bin/cca" "$project_dir/bin/macscan" "$app_dir/Contents/Resources/bin/"
chmod 755 "$app_dir/Contents/Resources/bin/"*

cat > "$app_dir/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>dev.oconde.toolbelt</string>
  <key>CFBundleName</key><string>Toolbelt</string>
  <key>CFBundleDisplayName</key><string>Toolbelt</string>
  <key>CFBundleExecutable</key><string>Toolbelt</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleShortVersionString</key><string>$version</string>
  <key>CFBundleVersion</key><string>$build_number</string>
  <key>CFBundleDevelopmentRegion</key><string>pt-BR</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHumanReadableCopyright</key><string>© $year Fernando Conde</string>
  <key>NSAppleEventsUsageDescription</key><string>Abrir o Terminal para retomar conversas e fazer login nas contas do Claude.</string>
  <key>ToolbeltUpdateFeedURL</key><string>$feed_url</string>
  <key>RadarIngestURL</key><string>$radar_url</string>
  <key>RadarEnvironment</key><string>$radar_environment</string>
  <key>RadarKey</key><string>$radar_key</string>
</dict>
</plist>
PLIST
plutil -lint -s "$app_dir/Contents/Info.plist"
echo "assembled $app_dir ($version build $build_number)"

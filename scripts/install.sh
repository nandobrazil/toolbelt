#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
app_dir="$HOME/Applications/Toolbelt.app"
label="dev.oconde.toolbelt"
launch_agent="$HOME/Library/LaunchAgents/$label.plist"
signing_identity="${TOOLBELT_SIGNING_IDENTITY:-Toolbelt Local Signing}"

cd "$project_dir"
build_memory_limit_mb="${TOOLBELT_BUILD_MEMORY_MB:-2048}"
if command -v memcap >/dev/null 2>&1; then
  memcap "$build_memory_limit_mb" -- swift build -c release
else
  swift build -c release
fi

launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
pkill -x Toolbelt 2>/dev/null || true

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/Toolbelt" "$app_dir/Contents/MacOS/Toolbelt"

cat > "$app_dir/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>$label</string>
  <key>CFBundleName</key><string>Toolbelt</string>
  <key>CFBundleExecutable</key><string>Toolbelt</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>Abrir o Terminal para retomar conversas e fazer login nas contas do Claude.</string>
</dict>
</plist>
PLIST

codesign --force --sign "$signing_identity" "$app_dir"

support_dir="$HOME/Library/Application Support/Toolbelt"
if [ -f "$launch_agent" ] || [ ! -d "$support_dir" ]; then
  mkdir -p "$(dirname "$launch_agent")"
  cat > "$launch_agent" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key>
  <array><string>$app_dir/Contents/MacOS/Toolbelt</string></array>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/Toolbelt.log</string>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><false/>
</dict>
</plist>
PLIST
  launchctl bootstrap "gui/$(id -u)" "$launch_agent"
else
  open "$app_dir"
fi
echo "installed $app_dir"

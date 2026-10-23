#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
legacy_label="dev.oconde.toolbelt"
developer_identity="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)"
if [ -n "$developer_identity" ]; then
  default_identity="$developer_identity"
  default_app_dir="/Applications/Toolbelt.app"
else
  default_identity="Toolbelt Local Signing"
  default_app_dir="$HOME/Applications/Toolbelt.app"
fi
signing_identity="${TOOLBELT_SIGNING_IDENTITY:-$default_identity}"
app_dir="${TOOLBELT_APP_DIR:-$default_app_dir}"

cd "$project_dir"
build_memory_limit_mb="${TOOLBELT_BUILD_MEMORY_MB:-2048}"
if command -v memcap >/dev/null 2>&1; then
  memcap "$build_memory_limit_mb" -- swift build -c release
else
  swift build -c release
fi

launchctl bootout "gui/$(id -u)/$legacy_label" 2>/dev/null || true
pkill -x Toolbelt 2>/dev/null || true
for _ in $(seq 50); do
  pgrep -x Toolbelt >/dev/null || break
  sleep 0.1
done

radar_key="$(security find-generic-password -s "Toolbelt Radar key" -w 2>/dev/null || true)"
TOOLBELT_RADAR_KEY="$radar_key" TOOLBELT_RADAR_ENVIRONMENT=development scripts/assemble-app.sh "$(swift build -c release --show-bin-path)/Toolbelt" "$app_dir"
codesign --force --options runtime --timestamp=none --entitlements Resources/Toolbelt.entitlements --sign "$signing_identity" "$app_dir"

if [ "$app_dir" = "/Applications/Toolbelt.app" ] && [ -d "$HOME/Applications/Toolbelt.app" ]; then
  rm -rf "$HOME/Applications/Toolbelt.app"
  echo "removed the old copy in ~/Applications"
fi

open "$app_dir"
echo "installed $app_dir (signed by $signing_identity)"

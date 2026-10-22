#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
app_dir="$HOME/Applications/Toolbelt.app"
legacy_label="dev.oconde.toolbelt"
signing_identity="${TOOLBELT_SIGNING_IDENTITY:-Toolbelt Local Signing}"

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

scripts/assemble-app.sh "$(swift build -c release --show-bin-path)/Toolbelt" "$app_dir"
codesign --force --options runtime --entitlements Resources/Toolbelt.entitlements --sign "$signing_identity" "$app_dir"

open "$app_dir"
echo "installed $app_dir"

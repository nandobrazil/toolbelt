#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"

if ! command -v cwebp >/dev/null 2>&1; then
  echo "cwebp not found: brew install webp" >&2
  exit 1
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

if command -v memcap >/dev/null 2>&1; then
  memcap 2048 -- swift build -c release
else
  swift build -c release
fi
scripts/assemble-app.sh "$(swift build -c release --show-bin-path)/Toolbelt" "$work_dir/Toolbelt.app" >/dev/null

for language in pt en; do
  case "$language" in
    pt) apple_language="pt-BR" ;;
    en) apple_language="en" ;;
  esac
  "$work_dir/Toolbelt.app/Contents/MacOS/Toolbelt" --landing-screenshots "$work_dir/$language" -AppleLanguages "($apple_language)"
  mkdir -p "site/assets/shots/$language"
  for png in "$work_dir/$language"/*.png; do
    name="$(basename "$png" .png)"
    cwebp -quiet -q 90 -m 6 -sharp_yuv "$png" -o "site/assets/shots/$language/$name.webp"
    printf '%s %s\n' "$language/$name.webp" "$(sips -g pixelWidth -g pixelHeight "$png" | awk '/pixel/ {printf "%s ", $2}')"
  done
done

#!/usr/bin/env bash
set -euo pipefail
EXPECTED="${1:?uso: smoke.sh <sha7>}"
BASE=https://toolbelt.oconde.dev

RUNNING=$(bash "$(dirname "${BASH_SOURCE[0]}")/running-release.sh")
echo "release no ar: $RUNNING"
[ "$RUNNING" = "$EXPECTED" ]
kubectl rollout status deploy/app -n toolbelt --timeout=120s

for ATTEMPT in 1 2 3 4 5 6; do
  CODE=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 "$BASE/healthz" || echo 000)
  [ "$CODE" = "200" ] && break
  sleep 5
done
echo "/healthz -> $CODE (tentativa $ATTEMPT)"
[ "$CODE" = "200" ]

fail=0
check() {
  for ATTEMPT in 1 2 3; do
    CODE=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 "$BASE$1" || echo 000)
    [ "$CODE" = "$2" ] && break
    sleep 3
  done
  if [ "$CODE" = "$2" ]; then
    echo "  $1 -> $CODE"
  else
    echo "  $1 -> $CODE (esperado $2)"
    fail=1
  fi
}
check / 200
check /assets/site.css 200
check /assets/app-icon.png 200
check /download 302
check /updates/latest.json 302
check /changelog 302

LOCATION=$(curl -sS -o /dev/null -D - --max-time 20 "$BASE/updates/latest.json" | tr -d '\r' | sed -n 's/^[Ll]ocation: //p')
if [ "$LOCATION" = "https://github.com/nandobrazil/toolbelt-releases/releases/latest/download/latest.json" ]; then
  echo "  feed de atualização -> $LOCATION"
else
  echo "  feed de atualização -> ${LOCATION:-sem location} (esperado o latest.json do toolbelt-releases)"
  fail=1
fi
exit $fail

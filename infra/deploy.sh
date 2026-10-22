#!/usr/bin/env bash
set -euo pipefail
NAMESPACE="toolbelt"
IMAGE="${NAMESPACE}/app:latest"
cd "/opt/${NAMESPACE}/src"
GIT_SHA="${GIT_SHA:-$(git rev-parse --short HEAD 2>/dev/null || echo unknown)}"
IMPORT=(k3s ctr images import -)
CTR=(k3s ctr -n k8s.io)
CRICTL=(k3s crictl)
if [ "$(id -u)" -ne 0 ]; then
  IMPORT=(sudo -n /usr/local/bin/k3s ctr images import -)
  CTR=(sudo -n /usr/local/bin/k3s ctr -n k8s.io)
  CRICTL=(sudo -n /usr/local/bin/k3s crictl)
fi
docker build --build-arg GIT_SHA="$GIT_SHA" -t "$IMAGE" .
docker save "$IMAGE" | "${IMPORT[@]}"
if kubectl get deploy/app -n "$NAMESPACE" >/dev/null 2>&1; then
  kubectl apply -f "infra/${NAMESPACE}.yaml"
  kubectl rollout restart deploy/app -n "$NAMESPACE"
else
  kubectl apply -f "infra/${NAMESPACE}.yaml"
fi
kubectl rollout status deploy/app -n "$NAMESPACE" --timeout=300s
docker image prune -f >/dev/null
docker builder prune -af --keep-storage 10GB >/dev/null
CURRENT=$("${CRICTL[@]}" inspecti --output go-template --template '{{.status.id}}' "$IMAGE" 2>/dev/null || true)
"${CTR[@]}" images ls -q | grep -F "${NAMESPACE}/app" | while read -r ref; do
  [ "$("${CRICTL[@]}" inspecti --output go-template --template '{{.status.id}}' "$ref" 2>/dev/null)" = "$CURRENT" ] || "${CTR[@]}" images rm "$ref" >/dev/null 2>&1 || true
done

#!/usr/bin/env bash
set -euo pipefail
IMAGE="${1:?uso: deploy.sh ghcr.io/nandobrazil/toolbelt-site:<sha7>}"
NAMESPACE=toolbelt
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ "$IMAGE" =~ ^ghcr\.io/nandobrazil/toolbelt-site:[0-9a-f]{7}$ ]] || { echo "imagem inválida: $IMAGE" >&2; exit 1; }
kubectl get secret ghcr-pull -n "$NAMESPACE" >/dev/null 2>&1 || { echo "secret ghcr-pull ausente em ${NAMESPACE}: o k3s não consegue puxar do GHCR" >&2; exit 1; }
echo "publicando ${IMAGE}"
sed "s|__IMAGE__|${IMAGE}|" "${ROOT}/infra/toolbelt.yaml" | kubectl apply -f -
kubectl rollout status deploy/app -n "$NAMESPACE" --timeout=300s

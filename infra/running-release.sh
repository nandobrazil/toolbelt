#!/usr/bin/env bash
set -euo pipefail
kubectl get deploy app -n toolbelt -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null | sed -n 's|.*:\([0-9a-f]\{7\}\)$|\1|p'

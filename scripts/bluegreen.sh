#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Blue-green traffic switch (SIMULATION on one kind cluster).
# Blue  = technova-web-23bcs070:1.0.0
# Green = technova-web-23bcs070:1.1.0
# The Service selector decides which colour receives traffic.
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

log() { printf '\n=== %s ===\n' "$*"; }
version_now() { curl -fsS http://localhost:8082/version; echo; }

log "1. Deploy both colours and the blue-green Service"
kubectl apply -f k8s/bluegreen/blue-deployment.yaml \
              -f k8s/bluegreen/green-deployment.yaml \
              -f k8s/bluegreen/bg-service.yaml
kubectl -n technova rollout status deployment/technova-web-blue --timeout=180s
kubectl -n technova rollout status deployment/technova-web-green --timeout=180s
kubectl -n technova get deployments -l app=technova-web-bg
kubectl -n technova get pods -l app=technova-web-bg -o wide
kubectl -n technova get service technova-web-bg

log "2. Service currently selects blue; verify the live version"
kubectl -n technova get service technova-web-bg -o jsonpath='{.spec.selector}{"\n"}'
version_now

log "3. Switch traffic to green with a selector patch"
kubectl -n technova patch service technova-web-bg \
  -p '{"spec":{"selector":{"app":"technova-web-bg","version":"green"}}}'
sleep 3
kubectl -n technova get service technova-web-bg -o jsonpath='{.spec.selector}{"\n"}'
kubectl -n technova get endpoints technova-web-bg
for _ in 1 2 3; do version_now; done

log "4. Roll back to blue (selector patch, no Pod restart)"
kubectl -n technova patch service technova-web-bg \
  -p '{"spec":{"selector":{"app":"technova-web-bg","version":"blue"}}}'
sleep 3
kubectl -n technova get endpoints technova-web-bg
for _ in 1 2 3; do version_now; done

log "5. Resulting objects"
kubectl -n technova get deployments,pods,service -l app=technova-web-bg

#!/usr/bin/env bash
# Collect application/container log evidence, including one induced failure.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

log() { printf '\n=== %s ===\n' "$*"; }

POD="$(kubectl -n technova get pods -l app=technova-web \
        -o jsonpath='{.items[0].metadata.name}')"
echo "Sample web Pod: $POD"

log "1. Normal application events (gunicorn access log + app log)"
curl -fsS http://localhost:8081/ >/dev/null
curl -fsS http://localhost:8081/health >/dev/null
curl -fsS http://localhost:8081/metrics >/dev/null
sleep 1
kubectl -n technova logs "$POD" --tail=25

log "2. Client error: request to a route that does not exist"
curl -s -o /dev/null -w 'HTTP %{http_code} for /does-not-exist\n' http://localhost:8081/does-not-exist

log "3. Induced failure: scale PostgreSQL to zero and probe readiness"
kubectl -n technova scale deployment technova-db --replicas=0
kubectl -n technova wait --for=delete pod -l app=technova-db --timeout=90s || true
sleep 3
curl -s -o /dev/null -w 'HTTP %{http_code} from /ready while the database is down\n' \
  http://localhost:8081/ready || true
sleep 1
kubectl -n technova logs "$POD" --tail=12

log "4. Recover the database and confirm readiness"
kubectl -n technova scale deployment technova-db --replicas=1
kubectl -n technova rollout status deployment/technova-db --timeout=180s
for _ in $(seq 1 20); do
  if curl -fsS http://localhost:8081/ready >/dev/null 2>&1; then
    curl -fsS http://localhost:8081/ready; echo
    break
  fi
  sleep 3
done
kubectl -n technova get pods

log "5. Kubernetes events show the restart/recovery trail"
kubectl -n technova get events --sort-by=.lastTimestamp | tail -12

#!/usr/bin/env bash
# Screen 06b: dependency failure visible in logs and readiness, then recovery.
set -uo pipefail
cd "$HOME/devops-assignment5"
POD="$(kubectl -n technova get pods -l app=technova-web -o jsonpath='{.items[0].metadata.name}')"

echo "Induced failure: PostgreSQL scaled to 0 (Pod $POD keeps running)"
kubectl -n technova scale deployment technova-db --replicas=0 >/dev/null
kubectl -n technova wait --for=delete pod -l app=technova-db --timeout=90s >/dev/null 2>&1 || true
sleep 2
echo -n "GET /ready -> HTTP "; curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8081/ready
kubectl -n technova logs -l app=technova-web --since=120s --prefix | grep -E 'readiness check failed|"GET /ready HTTP/1.1" 503' | tail -3
echo
echo "Recovery: PostgreSQL restored, readiness green again"
kubectl -n technova scale deployment technova-db --replicas=1 >/dev/null
kubectl -n technova rollout status deployment/technova-db --timeout=180s
for _ in $(seq 1 20); do
  curl -fsS http://localhost:8081/ready >/dev/null 2>&1 && break
  sleep 3
done
curl -s http://localhost:8081/ready; echo
kubectl -n technova get pods -l app=technova-db

#!/usr/bin/env bash
# Screen 06: application log evidence - normal traffic and an induced failure.
set -uo pipefail
cd "$HOME/devops-assignment5"
POD="$(kubectl -n technova get pods -l app=technova-web -o jsonpath='{.items[0].metadata.name}')"

echo "Pod logs: $POD"
echo
echo "--- normal requests (gunicorn access log + application log) ---"
curl -s http://localhost:8081/ >/dev/null
curl -s http://localhost:8081/health >/dev/null
sleep 1
kubectl -n technova logs "$POD" --tail=8
echo
echo "--- client error: HTTP $(curl -s -o /dev/null -w '%{http_code}' http://localhost:8081/does-not-exist) for /does-not-exist ---"
kubectl -n technova logs "$POD" --tail=2
echo
echo "--- induced startup/dependency failure: PostgreSQL scaled to 0 ---"
kubectl -n technova scale deployment technova-db --replicas=0 >/dev/null
kubectl -n technova wait --for=delete pod -l app=technova-db --timeout=90s >/dev/null 2>&1 || true
sleep 2
echo -n "GET /ready -> HTTP "; curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8081/ready
kubectl -n technova logs "$POD" --tail=4
echo
echo "--- recovery: PostgreSQL restored, readiness green again ---"
kubectl -n technova scale deployment technova-db --replicas=1 >/dev/null
kubectl -n technova rollout status deployment/technova-db --timeout=180s
for _ in $(seq 1 20); do
  curl -fsS http://localhost:8081/ready >/dev/null 2>&1 && break
  sleep 3
done
curl -s http://localhost:8081/ready; echo
kubectl -n technova get pods

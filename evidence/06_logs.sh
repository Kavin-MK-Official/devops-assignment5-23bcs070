#!/usr/bin/env bash
# Screen 06: application log evidence for normal traffic and a client error.
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
kubectl -n technova logs "$POD" --tail=6 | grep 'does-not-exist'

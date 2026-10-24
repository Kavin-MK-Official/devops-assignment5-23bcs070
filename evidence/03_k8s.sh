#!/usr/bin/env bash
# Screen 03: Kubernetes deployment, rollout and Service access.
set -uo pipefail
cd "$HOME/devops-assignment5"

echo "Namespace technova - application Pods:"
kubectl -n technova get pods -l app=technova-web
echo
echo "Deployment:"
kubectl -n technova get deployment technova-web \
  -o custom-columns='NAME:.metadata.name,DESIRED:.spec.replicas,READY:.status.readyReplicas,AVAILABLE:.status.availableReplicas,IMAGE:.spec.template.spec.containers[0].image'
echo
echo "Service exposed on NodePort 30080:"
kubectl -n technova get service technova-web
echo
echo "Rollout status:"
kubectl -n technova rollout status deployment/technova-web --timeout=60s
echo
echo "Application through NodePort 30080 (host 8081):"
curl -s -o /dev/null -w 'GET /        HTTP %{http_code} in %{time_total}s\n' http://localhost:8081/
curl -s http://localhost:8081/version; echo
curl -s http://localhost:8081/metrics | grep -E '^(technova_db_up|technova_app_info)' | head -4

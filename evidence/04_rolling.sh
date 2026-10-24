#!/usr/bin/env bash
# Screen 04: rolling update evidence - two ReplicaSets, one old one new.
set -uo pipefail
cd "$HOME/devops-assignment5"

echo "Rollout history of deployment/technova-web:"
kubectl -n technova rollout history deployment/technova-web
echo
echo "ReplicaSets (old revision scaled to zero, new revision serving):"
kubectl -n technova get replicasets -l app=technova-web \
  -o custom-columns='NAME:.metadata.name,DESIRED:.spec.replicas,READY:.status.readyReplicas,IMAGE:.spec.template.spec.containers[0].image'
echo
echo "Pods currently serving:"
kubectl -n technova get pods -l app=technova-web \
  -o custom-columns='POD:.metadata.name,READY:.status.containerStatuses[0].ready,VERSION:.spec.containers[0].image'
echo
echo "Version observed through the Service:"
for _ in 1 2 3; do curl -s http://localhost:8081/version; echo; done
echo
echo "Rollback command available if the new version is bad:"
echo "  kubectl -n technova rollout undo deployment/technova-web"

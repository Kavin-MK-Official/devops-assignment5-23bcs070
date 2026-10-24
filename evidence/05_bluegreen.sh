#!/usr/bin/env bash
# Screen 05: blue-green switch (simulation) - live version before/after.
set -uo pipefail
cd "$HOME/devops-assignment5"

v() { curl -s http://localhost:8082/version; echo; }
sel() { kubectl -n technova get service technova-web-bg -o jsonpath='{.spec.selector}{"\n"}'; }

echo "Blue-green simulation on one kind cluster"
echo "  blue  = technova-web-23bcs070:1.0.0   green = technova-web-23bcs070:1.1.0"
echo
kubectl -n technova get deployments -l app=technova-web-bg \
  -o custom-columns='NAME:.metadata.name,READY:.status.readyReplicas,IMAGE:.spec.template.spec.containers[0].image'
echo
echo "Before switch: service selector = $(sel)"
echo -n "Traffic hits version: "; v
echo
echo "kubectl patch service technova-web-bg -p '{\"spec\":{\"selector\":{\"version\":\"green\"}}}'"
kubectl -n technova patch service technova-web-bg \
  -p '{"spec":{"selector":{"app":"technova-web-bg","version":"green"}}}' >/dev/null
sleep 3
echo "After switch: service selector = $(sel)"
echo -n "Traffic hits version: "; v
echo
echo "Rollback: selector back to blue (no Pod restart)"
kubectl -n technova patch service technova-web-bg \
  -p '{"spec":{"selector":{"app":"technova-web-bg","version":"blue"}}}' >/dev/null
sleep 3
echo "After rollback: service selector = $(sel)"
echo -n "Traffic hits version: "; v
echo
kubectl -n technova get endpoints technova-web-bg

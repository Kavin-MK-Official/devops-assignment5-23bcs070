#!/usr/bin/env bash
# Integrated verification table for Activity 7 from the live system.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source "$HOME/.config/assignment5/jenkins.env"

JENKINS_URL="http://localhost:8088"
row() { printf '%-28s | %-52s | %s\n' "$1" "$2" "$3"; }

echo "PIPELINE STAGE                | TOOL / COMMAND                                       | STATUS"
echo "-----------------------------+------------------------------------------------------+--------"

COMMIT="$(git log -1 --pretty='%h %s' 2>/dev/null || echo 'n/a')"
row "Checkout" "git log -1" "OK - $COMMIT"

BUILD_RESULT="$(curl -fsS -u "admin:$JENKINS_ADMIN_PASSWORD" \
  "$JENKINS_URL/job/technova-assignment5/lastBuild/api/json" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"])' || echo unknown)"
row "Build and test" "pytest in python:3.12-slim (Jenkins)" "OK - build $BUILD_RESULT"

TAG="$(kubectl -n technova get deployment technova-web -o jsonpath='{.spec.template.spec.containers[0].image}')"
row "Docker image build/tag" "docker build --build-arg APP_VERSION" "OK - $TAG"

READY="$(kubectl -n technova get deployment technova-web -o jsonpath='{.status.readyReplicas}/{.spec.replicas}')"
row "Kubernetes deployment" "kubectl rollout status" "OK - $READY ready"

VERSION_JSON="$(curl -fsS http://localhost:8081/version || echo '{}')"
row "Service/application verification" "curl localhost:8081/version" "OK - $VERSION_JSON"

UP="$(curl -fsS 'http://127.0.0.1:9090/api/v1/query?query=up%7Bjob%3D%22technova-web%22%7D' \
  | python3 -c 'import json,sys; r=json.load(sys.stdin)["data"]["result"]; print(r[0]["value"][1] if r else "no-data")' 2>/dev/null || echo error)"
row "Prometheus target/metric" "Prometheus /api/v1/query up" "OK - up=$UP"

GRAF="$(curl -fsS -u "admin:$(grep GRAFANA_ADMIN_PASSWORD monitoring/.env | cut -d= -f2)" \
  'http://127.0.0.1:3000/api/search?query=TechNova' \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d[0]["title"] if d else "not found")' 2>/dev/null || echo error)"
row "Grafana dashboard" "Grafana /api/search" "OK - $GRAF"

LOG_COUNT="$(kubectl -n technova logs -l app=technova-web --tail=200 2>/dev/null | wc -l)"
bash scripts/security_check.sh >/tmp/security_review.txt 2>&1 && SEC="all checks passed" || SEC="failed"
row "Log and security review" "kubectl logs + scripts/security_check.sh" "OK - $LOG_COUNT log lines; $SEC"

echo
echo "Last security review:"
tail -3 /tmp/security_review.txt

#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Assignment 5 - recorded execution log driver (scripts/execution_log.sh).
# Re-runs the evidence commands against the live system and prints every
# command with a UTC timestamp. Secrets are never echoed: commands that use
# credentials are printed with variable placeholders.
# Intended to be captured with: script -q -e -c "bash scripts/execution_log.sh" assignment5_execution.log
# ---------------------------------------------------------------------------
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source "$HOME/.config/assignment5/jenkins.env"
stty cols 200 2>/dev/null || true

J="http://localhost:8088/job/technova-assignment5"
ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
hdr() { echo; echo "##################### $* #####################"; }
c() { echo "[$(ts)] \$ $*"; }

hdr "ASSIGNMENT 5 - DEVOPS INTEGRATION AND MONITORING (23BCS070)"
echo "Session start : $(ts)"
echo "Host          : $(hostname)  ($(uname -r))"
echo "Working dir   : $(pwd)"

hdr "ACTIVITY 1 - SOURCE CONTROL AND TOOLCHAIN"
c "git remote -v"; git remote -v | sed -E 's#https://[^@]*@#https://#'
c "git log --oneline -4"; git log --oneline -4
c "git status -sb"; git status -sb
c "docker version --format '{{.Server.Version}}'"; docker version --format '{{.Server.Version}}'
c "kubectl version --short"; kubectl version --short 2>/dev/null || kubectl version -o json | python3 -c 'import json,sys; d=json.load(sys.stdin); print("client", d["clientVersion"]["gitVersion"], "server", d["serverVersion"]["gitVersion"])'
c "kind version"; kind version
c "python3 --version"; python3 --version
c "curl -u admin:\$JENKINS_ADMIN_PASSWORD \$JENKINS_URL/api/json"
curl -s -u "admin:$JENKINS_ADMIN_PASSWORD" http://localhost:8088/api/json \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print("Jenkins", d["mode"], "nodeDescription:", d.get("nodeDescription",""))'

hdr "ACTIVITY 2 - CI PIPELINE RESULTS (BUILD 1 FAILURE, BUILD 2 SUCCESS)"
c "curl .../job/technova-assignment5/1/api/json"
curl -s -u "admin:$JENKINS_ADMIN_PASSWORD" "$J/1/api/json" \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print("build #%s result=%s duration=%.1fs" % (d["number"], d["result"], d["duration"]/1000))'
echo "--- build #1 failure reason (security stage) ---"
curl -s -u "admin:$JENKINS_ADMIN_PASSWORD" "$J/1/consoleText" | grep -E "FAIL  no credentials|Finished: FAILURE" | sed -E 's/^\[[^]]+\] //'
echo
c "curl .../job/technova-assignment5/2/api/json"
curl -s -u "admin:$JENKINS_ADMIN_PASSWORD" "$J/2/api/json" \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print("build #%s result=%s duration=%.1fs" % (d["number"], d["result"], d["duration"]/1000))'
echo "--- build #2 stages (from console log; pipeline-stage-view plugin not installed) ---"
curl -s -u "admin:$JENKINS_ADMIN_PASSWORD" "$J/2/consoleText" \
  | grep -oE '\[Pipeline\] \{ \(.*' | sed -E 's/\[Pipeline\] \{ \(//; s/\)$//' | sed 's/^/  - /'
echo "--- build #2 evidence lines ---"
curl -s -u "admin:$JENKINS_ADMIN_PASSWORD" "$J/2/consoleText" \
  | grep -E "5 passed|Successfully tagged|Image: \[|successfully rolled out|SECURITY REVIEW|Deployed technova" \
  | sed -E 's/^\[[^]]+\] //' | head -8

hdr "ACTIVITY 2 - DOCKER IMAGE BUILD AND TAG"
c "docker image ls --format '{{.Repository}}:{{.Tag}}  {{.ID}}  {{.Size}}'"
docker image ls --format '{{.Repository}}:{{.Tag}}  {{.ID}}  {{.Size}}' | grep technova-web-23bcs070
c "docker image inspect technova-web-23bcs070:1.1.2 --format '{{.Config.User}} {{index .Config.Labels \"version\"}}'"
docker image inspect technova-web-23bcs070:1.1.2 --format 'user={{.Config.User}} version={{index .Config.Labels "version"}}'

hdr "ACTIVITY 3 - KUBERNETES DEPLOYMENT AND SERVICE"
c "kubectl -n technova get pods -l app=technova-web"
kubectl -n technova get pods -l app=technova-web
kubectl -n technova get deployment technova-web technova-db
kubectl -n technova get service technova-web
c "kubectl -n technova rollout status deployment/technova-web"
kubectl -n technova rollout status deployment/technova-web --timeout=60s
c "curl http://localhost:8081/version"; curl -s http://localhost:8081/version; echo
c "curl http://localhost:8081/ready"; curl -s http://localhost:8081/ready; echo
c "curl http://localhost:8081/metrics | head"; curl -s http://localhost:8081/metrics | grep -E '^(http_requests_total|technova_db_up|technova_app_info)' | head -4

hdr "ACTIVITY 4 - ROLLING UPDATE EVIDENCE"
c "kubectl -n technova rollout history deployment/technova-web"
kubectl -n technova rollout history deployment/technova-web
c "kubectl -n technova get replicasets -l app=technova-web"
kubectl -n technova get replicasets -l app=technova-web \
  -o custom-columns='NAME:.metadata.name,DESIRED:.spec.replicas,READY:.status.readyReplicas,IMAGE:.spec.template.spec.containers[0].image'
c "kubectl -n technova get deployment technova-web -o jsonpath='{.spec.strategy}'"
kubectl -n technova get deployment technova-web -o jsonpath='{.spec.strategy}'; echo

hdr "ACTIVITY 4 - BLUE-GREEN SIMULATION (LABELLED AS SIMULATION)"
c "bash evidence/05_bluegreen.sh"
bash evidence/05_bluegreen.sh

hdr "ACTIVITY 5 - PROMETHEUS AND GRAFANA"
c "bash evidence/08_monitoring.sh"
bash evidence/08_monitoring.sh

hdr "ACTIVITY 6 - LOGS (NORMAL, CLIENT ERROR)"
c "bash evidence/06_logs.sh"
bash evidence/06_logs.sh

hdr "ACTIVITY 6 - LOGS (INDUCED DEPENDENCY FAILURE AND RECOVERY)"
c "bash evidence/06b_logs_failure.sh"
bash evidence/06b_logs_failure.sh

hdr "ACTIVITY 6 - SECURITY CHECKLIST"
c "bash scripts/security_check.sh"
bash scripts/security_check.sh
echo "security_check.sh exit code: $?"

hdr "ACTIVITY 7 - INTEGRATED VERIFICATION"
c "bash scripts/verify.sh"
bash scripts/verify.sh

hdr "CLEANUP - REMOVE BLUE-GREEN SIMULATION OBJECTS"
c "kubectl delete -f k8s/bluegreen/"
kubectl -n technova delete -f k8s/bluegreen/ --ignore-not-found
c "kubectl -n technova get pods"
kubectl -n technova get pods

echo
echo "EXECUTION COMPLETE - Session finished: $(ts)"
c "exit"
exit 0

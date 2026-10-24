#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Full Assignment 5 execution for the recorded terminal log.
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source "$HOME/.config/assignment5/jenkins.env"

echo "ASSIGNMENT 5 - DEVOPS INTEGRATION AND MONITORING (23BCS070)"
echo "Session start: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo "Host: $(hostname)   Kernel: $(uname -r)   Python: $(python3 --version | cut -d' ' -f2)"

echo
echo "##################### ACTIVITIES 1-2: ENVIRONMENT, CI AND DOCKER #####################"
bash scripts/bootstrap.sh

echo
echo "##################### JENKINS CONTROLLER #####################"
bash scripts/start_jenkins.sh

echo
echo "##################### ACTIVITY 2-3: PIPELINE RUN AND DEPLOYMENT #####################"
bash scripts/trigger_pipeline.sh

echo
echo "##################### ACTIVITY 4: ROLLING UPDATE EVIDENCE #####################"
kubectl -n technova rollout history deployment/technova-web
kubectl -n technova get replicasets -l app=technova-web \
  -o custom-columns='NAME:.metadata.name,DESIRED:.spec.replicas,READY:.status.readyReplicas,IMAGE:.spec.template.spec.containers[0].image'
kubectl -n technova get pods -l app=technova-web \
  -o custom-columns='POD:.metadata.name,READY:.status.containerStatuses[0].ready,IMAGE:.spec.containers[0].image'
curl -fsS http://localhost:8081/version; echo

echo
echo "##################### ACTIVITY 4: BLUE-GREEN SIMULATION #####################"
bash scripts/bluegreen.sh

echo
echo "##################### ACTIVITY 5: PROMETHEUS AND GRAFANA #####################"
echo "--- Prometheus scrape targets ---"
curl -fsS 'http://127.0.0.1:9090/api/v1/targets?state=active' \
  | python3 -c '
import json,sys
d=json.load(sys.stdin)["data"]["activeTargets"]
for t in d:
    print("%-14s %-32s %-8s %s" % (t["labels"].get("job"), t["scrapeUrl"], t["health"], t["lastScrape"]))
'
echo "--- Application metrics actually collected ---"
curl -fsS 'http://127.0.0.1:9090/api/v1/query?query=up%7Bjob%3D%22technova-web%22%7D' \
  | python3 -c 'import json,sys; r=json.load(sys.stdin)["data"]["result"][0]; print("up =", r["value"][1], r["metric"])'
curl -fsS 'http://127.0.0.1:9090/api/v1/query?query=sum(rate(http_requests_total%5B5m%5D))' \
  | python3 -c 'import json,sys; r=json.load(sys.stdin)["data"]["result"]; print("request rate (5m) =", r[0]["value"][1] if r else "no data")'
curl -fsS 'http://127.0.0.1:9090/api/v1/query?query=max(technova_db_up)' \
  | python3 -c 'import json,sys; r=json.load(sys.stdin)["data"]["result"]; print("technova_db_up =", r[0]["value"][1] if r else "no data")'
echo "--- Grafana datasource and dashboard provisioning ---"
GRAFANA_PW="$(grep GRAFANA_ADMIN_PASSWORD monitoring/.env | cut -d= -f2)"
curl -fsS -u "admin:$GRAFANA_PW" http://127.0.0.1:3000/api/datasources \
  | python3 -c 'import json,sys; [print(f"datasource: {d[\"name\"]} type={d[\"type\"]} url={d[\"url\"]} default={d[\"isDefault\"]}") for d in json.load(sys.stdin)]'
curl -fsS -u "admin:$GRAFANA_PW" 'http://127.0.0.1:3000/api/search?query=TechNova' \
  | python3 -c 'import json,sys; [print(f"dashboard: {d[\"title\"]} uid={d[\"uid\"]}") for d in json.load(sys.stdin)]'

echo
echo "##################### ACTIVITY 6: LOGS AND SECURITY #####################"
bash scripts/log_evidence.sh

echo
echo "##################### ACTIVITY 7: INTEGRATED VERIFICATION #####################"
bash scripts/verify.sh

echo
echo "##################### SECURITY REVIEW (FULL) #####################"
bash scripts/security_check.sh || true

echo
echo "EXECUTION COMPLETE - Session finished: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"

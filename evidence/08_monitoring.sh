#!/usr/bin/env bash
# Screen 08: Prometheus targets and queries actually returning application data.
set -uo pipefail
cd "$HOME/devops-assignment5"

echo "Prometheus scrape targets:"
curl -fsS 'http://127.0.0.1:9090/api/v1/targets?state=active' \
  | python3 -c '
import json, sys
for t in json.load(sys.stdin)["data"]["activeTargets"]:
    print("  %-14s %-28s %-6s last scrape %s" % (
        t["labels"].get("job"), t["scrapeUrl"], t["health"], t["lastScrape"][11:19]))
'
echo
q() {
  printf '%-58s ' "$1"
  curl -fsS --get --data-urlencode "query=$2" http://127.0.0.1:9090/api/v1/query \
    | python3 -c '
import json, sys
r = json.load(sys.stdin)["data"]["result"]
print(r[0]["value"][1] if r else "no data")
'
}
echo "Live Prometheus queries:"
q "up{job=\"technova-web\"}" 'up{job="technova-web"}'
q "sum(rate(http_requests_total[5m]))" 'sum(rate(http_requests_total[5m]))'
q "avg request latency 5m (s)" 'sum(rate(http_request_duration_seconds_sum[5m])) / sum(rate(http_request_duration_seconds_count[5m]))'
q "max(technova_db_up)" 'max(technova_db_up)'
q "max(technova_app_info)" 'max(technova_app_info)'
echo
echo "Grafana health: $(curl -fsS http://127.0.0.1:3000/api/health)"
GRAFANA_PW="$(grep GRAFANA_ADMIN_PASSWORD monitoring/.env | cut -d= -f2)"
curl -fsS -u "admin:$GRAFANA_PW" http://127.0.0.1:3000/api/datasources \
  | python3 -c 'import json,sys; [print("Datasource:", d["name"], "->", d["url"], "default=%s" % d["isDefault"]) for d in json.load(sys.stdin)]'
curl -fsS -u "admin:$GRAFANA_PW" 'http://127.0.0.1:3000/api/search?query=TechNova' \
  | python3 -c 'import json,sys; [print("Dashboard :", d["title"]) for d in json.load(sys.stdin)]'

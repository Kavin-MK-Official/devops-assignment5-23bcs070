#!/usr/bin/env bash
# Screen 01: Jenkins pipeline stage results for the last build.
set -uo pipefail
cd "$HOME/devops-assignment5"
source "$HOME/.config/assignment5/jenkins.env"
J="http://localhost:8088/job/technova-assignment5"

echo "Jenkins controller : http://localhost:8088  (JCasC, no manual job setup)"
curl -fsS -u "admin:$JENKINS_ADMIN_PASSWORD" "$J/job/technova-assignment5/api/json" >/dev/null 2>&1
curl -fsS -u "admin:$JENKINS_ADMIN_PASSWORD" "$J/lastBuild/api/json" \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print("Build #%s  result=%s  duration=%.1fs" % (d["number"], d["result"], d["duration"]/1000))'
echo
printf '%-32s %-10s %s\n' "STAGE" "STATUS" "DURATION"
printf '%-32s %-10s %s\n' "--------------------------------" "----------" "--------"
curl -fsS -u "admin:$JENKINS_ADMIN_PASSWORD" "$J/lastBuild/wfapi/describe" \
  | python3 -c '
import json, sys
d = json.load(sys.stdin)
for s in d.get("stages", []):
    print("%-32s %-10s %.1fs" % (s["name"], s["status"], s.get("durationMillis", 0)/1000))
'
echo
echo "Git commit deployed by this build:"
kubectl -n technova get deployment technova-web \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'

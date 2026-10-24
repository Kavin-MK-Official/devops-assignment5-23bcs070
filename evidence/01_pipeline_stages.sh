#!/usr/bin/env bash
# Screen 01: Jenkins pipeline stage results for the last build.
set -uo pipefail
cd "$HOME/devops-assignment5"
source "$HOME/.config/assignment5/jenkins.env"
J="http://localhost:8088/job/technova-assignment5"

echo "Jenkins controller : http://localhost:8088  (JCasC: job and credentials defined as code)"
curl -fsS -u "admin:$JENKINS_ADMIN_PASSWORD" "$J/lastBuild/api/json" \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print("Build #%s  result=%s  duration=%.1fs" % (d["number"], d["result"], d["duration"]/1000))'
echo
echo "Stages executed by the Jenkinsfile:"
curl -fsS -u "admin:$JENKINS_ADMIN_PASSWORD" "$J/lastBuild/consoleText" \
  | grep -oE '\[Pipeline\] \{ \(.*' \
  | sed -E 's/\[Pipeline\] \{ \(//; s/\)$//'
echo
echo "Evidence from the same build:"
curl -fsS -u "admin:$JENKINS_ADMIN_PASSWORD" "$J/lastBuild/consoleText" \
  | grep -E "Building technova-web|Successfully tagged|successfully rolled out|SECURITY REVIEW" \
  | sed -E 's/^\[[^]]+\] //' | tail -5
echo
echo "Image running now:"
kubectl -n technova get deployment technova-web \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'

#!/usr/bin/env bash
# Trigger the Jenkins pipeline from the CLI and stream the stage result.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source "$HOME/.config/assignment5/jenkins.env"

JENKINS_URL="http://localhost:8088"
JOB="technova-assignment5"

echo "Triggering $JOB ..."
COOKIE_JAR="$(mktemp)"
CRUMB_JSON="$(curl -fsS -c "$COOKIE_JAR" -u "admin:$JENKINS_ADMIN_PASSWORD" "$JENKINS_URL/crumbIssuer/api/json")"
CRUMB="$(printf '%s' "$CRUMB_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["crumb"])')"
CRUMB_FIELD="$(printf '%s' "$CRUMB_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["crumbRequestField"])')"
curl -fsS -b "$COOKIE_JAR" -u "admin:$JENKINS_ADMIN_PASSWORD" \
  -H "$CRUMB_FIELD: $CRUMB" -X POST "$JENKINS_URL/job/$JOB/build"
rm -f "$COOKIE_JAR"
echo "build queued"

for _ in $(seq 1 120); do
  sleep 5
  JSON="$(curl -fsS -u "admin:$JENKINS_ADMIN_PASSWORD" "$JENKINS_URL/job/$JOB/lastBuild/api/json" || true)"
  [ -n "$JSON" ] || continue
  STATE="$(printf '%s' "$JSON" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("building"), d.get("result"), d.get("number"))')"
  read -r BUILDING RESULT NUMBER <<< "$STATE"
  echo "build #$NUMBER building=$BUILDING result=${RESULT:-running}"
  if [ "$BUILDING" = "False" ]; then
    echo "$RESULT" > "$HOME/.config/assignment5/last_build_result"
    echo "Pipeline result: $RESULT"
    [ "$RESULT" = "SUCCESS" ] || exit 1
    break
  fi
done

echo "--- stage results ---"
curl -fsS -u "admin:$JENKINS_ADMIN_PASSWORD" \
  "$JENKINS_URL/job/$JOB/lastBuild/wfapi/describe" \
  | python3 -c '
import json, sys
data = json.load(sys.stdin)
for stage in data.get("stages", []):
    print("%-32s %-10s %.1fs" % (stage["name"], stage["status"], stage.get("durationMillis", 0) / 1000))
'

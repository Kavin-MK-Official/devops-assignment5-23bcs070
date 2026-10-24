#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Start the Jenkins controller with JCasC, host networking (so kubectl can
# reach the kind API and docker/kind can use the host daemon) and the
# docker.sock mounted read/write. The socket mount is a documented lab
# trade-off discussed in the report's security section.
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

STATE_DIR="$HOME/.config/assignment5"
ENV_FILE="$STATE_DIR/jenkins.env"
mkdir -p "$STATE_DIR" "$HOME/jenkins_home"

if [ ! -f "$ENV_FILE" ]; then
  GH_TOKEN="$(/mnt/c/Program\ Files/GitHub\ CLI/gh.exe auth token)"
  ADMIN_PW="$(openssl rand -hex 12)"
  {
    printf 'GITHUB_TOKEN=%s\n' "$GH_TOKEN"
    printf 'JENKINS_ADMIN_PASSWORD=%s\n' "$ADMIN_PW"
  } > "$ENV_FILE"
  chmod 600 "$ENV_FILE"
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

mkdir -p "$HOME/jenkins_home/casc"
cp jenkins/casc/jenkins.yaml "$HOME/jenkins_home/casc/jenkins.yaml"

docker rm -f jenkins-a5 >/dev/null 2>&1 || true

docker run -d --name jenkins-a5 \
  --network host \
  -e JENKINS_HOME=/home/kavin/jenkins_home \
  -e CASC_JENKINS_CONFIG=/home/kavin/jenkins_home/casc/jenkins.yaml \
  -e JAVA_OPTS="-Djenkins.install.runSetupWizard=false -Duser.timezone=UTC" \
  -e JENKINS_OPTS="--httpPort=8088" \
  -e KUBECONFIG=/home/kavin/.kube/config \
  -e GITHUB_TOKEN \
  -e JENKINS_ADMIN_PASSWORD \
  -v /home/kavin/jenkins_home:/home/kavin/jenkins_home \
  -v /home/kavin/.kube:/home/kavin/.kube:ro \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add "$(stat -c %g /var/run/docker.sock)" \
  jenkins-technova:1.0 >/dev/null

echo "Jenkins container started: $(docker inspect -f '{{.Id}}' jenkins-a5 | cut -c1-12)"
for i in $(seq 1 60); do
  if curl -fsS http://localhost:8088/login >/dev/null 2>&1; then
    echo "Jenkins is up after ${i} checks: http://localhost:8088"
    break
  fi
  sleep 3
done
curl -fsS http://localhost:8088/api/json -u "admin:$JENKINS_ADMIN_PASSWORD" \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print("Jenkins version:", d.get("version","unknown"))'
docker logs jenkins-a5 2>&1 | grep -E "Configuration as Code|Started|ERROR" | tail -5 || true

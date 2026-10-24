#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Assignment 5 - one-time environment bootstrap (23BCS070)
# Creates the kind cluster, the database Secret, the application images and
# the monitoring stack. Safe to re-run: existing objects are reconciled.
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

CLUSTER="technova-a5"
STATE_DIR="$HOME/.config/assignment5"

log() { printf '\n=== %s ===\n' "$*"; }

log "1. Preflight: docker, kubectl, kind, ansible"
docker version --format 'Docker server : {{.Server.Version}}'
kubectl version --client -o json | python3 -c 'import json,sys; print("kubectl       :", json.load(sys.stdin)["clientVersion"]["gitVersion"])'
kind version
ANSIBLE_BIN="${ANSIBLE_BIN:-$HOME/.venvs/ansible/bin/ansible}"
[ -x "$ANSIBLE_BIN" ] || ANSIBLE_BIN="$(command -v ansible || true)"
if [ -n "$ANSIBLE_BIN" ]; then "$ANSIBLE_BIN" --version | head -1; else echo "ansible       : not in PATH (used inside Jenkins image)"; fi
mkdir -p "$STATE_DIR"

log "2. Build the Jenkins controller image"
if docker image inspect jenkins-technova:1.0 >/dev/null 2>&1; then
  echo "jenkins-technova:1.0 already built (set FORCE_JENKINS_BUILD=1 to rebuild)"
else
  mkdir -p jenkins/bin
  cp "$(command -v kubectl)" jenkins/bin/kubectl
  cp "$(command -v kind)" jenkins/bin/kind
  ls -l jenkins/bin
  docker build -t jenkins-technova:1.0 jenkins
fi

log "3. Create the kind cluster (NodePort 30080->8081, 30081->8082)"
# kindest/node v1.37.0 segfaults in kubeadm on this WSL kernel; v1.34.0 is the
# newest stable node image that initialises reliably here.
K8S_IMAGE="${K8S_IMAGE:-kindest/node:v1.34.0}"
if kind get clusters | grep -qx "$CLUSTER"; then
  echo "cluster $CLUSTER already exists"
else
  kind create cluster --config kind-config.yaml --name "$CLUSTER" --image "$K8S_IMAGE"
fi
kubectl cluster-info --context "kind-$CLUSTER"

log "4. Namespace and database Secret"
kubectl apply -f k8s/namespace.yaml
if [ ! -f "$STATE_DIR/db_password" ]; then
  openssl rand -hex 16 > "$STATE_DIR/db_password"
  chmod 600 "$STATE_DIR/db_password"
fi
kubectl -n technova create secret generic technova-db-secret \
  --from-literal=DB_PASSWORD="$(cat "$STATE_DIR/db_password")" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n technova get secret technova-db-secret \
  -o custom-columns='NAME:.metadata.name,TYPE:.type,KEYS:.data'

log "5. PostgreSQL"
kubectl apply -f k8s/db-deployment.yaml
kubectl -n technova rollout status deployment/technova-db --timeout=180s

log "6. Build application images 1.0.0 and 1.1.0"
docker build --build-arg APP_VERSION=1.0.0 -t technova-web-23bcs070:1.0.0 app
docker build --build-arg APP_VERSION=1.1.0 -t technova-web-23bcs070:1.1.0 app
docker images technova-web-23bcs070 --format 'table {{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}'
kind load docker-image technova-web-23bcs070:1.0.0 technova-web-23bcs070:1.1.0 --name "$CLUSTER"
docker exec "$CLUSTER-control-plane" crictl images | grep technova-web

log "7. Initial Kubernetes deployment (version 1.0.0)"
kubectl apply -f k8s/web-service.yaml -f k8s/web-deployment.yaml
kubectl -n technova rollout status deployment/technova-web --timeout=180s
kubectl -n technova get pods -o wide
kubectl -n technova get service technova-web
echo "--- application through Service (http://localhost:8081) ---"
curl -fsS http://localhost:8081/version; echo
curl -fsS http://localhost:8081/ | grep -o '<p class="roll">[^<]*'

log "8. Monitoring stack (Prometheus + Grafana)"
cd monitoring
if [ ! -f .env ]; then
  printf 'GRAFANA_ADMIN_PASSWORD=%s\n' "$(openssl rand -hex 12)" > .env
  chmod 600 .env
fi
docker compose up -d
cd ..
echo "waiting for Prometheus and Grafana..."
for _ in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:9090/-/ready >/dev/null 2>&1 \
     && curl -fsS http://127.0.0.1:3000/api/health >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
curl -fsS http://127.0.0.1:9090/-/ready; echo
curl -fsS http://127.0.0.1:3000/api/health; echo
docker ps --filter name=technova- --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'

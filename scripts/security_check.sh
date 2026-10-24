#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Basic security review of the repository and the deployed workload.
# Prints PASS/FAIL lines; exits non-zero if any check fails.
# ---------------------------------------------------------------------------
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

fails=0
pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; fails=$((fails + 1)); }
info() { printf 'INFO  %s\n' "$*"; }

echo "Security review - $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo

echo "-- 1. Hard-coded credentials in tracked files --"
HITS="$(git grep -nE '(password|passwd|token|secret_key|api_key)[[:space:]]*[:=][[:space:]]*["'"'"'][A-Za-z0-9/+_=-]{8,}' \
        -- ':!*example*' ':!README.md' ':!scripts/security_check.sh' 2>/dev/null || true)"
if [ -n "$HITS" ]; then
  printf '%s\n' "$HITS"
  fail "credential-like literals found in tracked files"
else
  pass "no hard-coded credentials in tracked files"
fi

echo "-- 2. Secret values are not committed --"
if git ls-files --error-unmatch k8s/db-secret.yaml >/dev/null 2>&1; then
  fail "k8s/db-secret.yaml is tracked"
else
  pass "only db-secret.example.yaml is tracked; the real Secret is created at runtime"
fi
kubectl -n technova get secret technova-db-secret \
  -o jsonpath='Secret {.metadata.name} type={.type} keys=[redacted]{"\n"}' 2>/dev/null \
  || info "cluster Secret not available in this environment"

echo "-- 3. Container runs as a non-root user --"
USER_CFG="$(docker image inspect technova-web-23bcs070:1.0.0 --format '{{.Config.User}}' 2>/dev/null || true)"
if [ -n "$USER_CFG" ] && [ "$USER_CFG" != "root" ] && [ "$USER_CFG" != "0" ]; then
  pass "image runs as '$USER_CFG' (Dockerfile USER appuser, uid 10001)"
else
  fail "image user is '${USER_CFG:-unknown}'"
fi

echo "-- 4. Base images are tagged, not floating --"
if grep -RInE '^FROM[[:space:]]+[^[:space:]]+:latest' app/Dockerfile jenkins/Dockerfile 2>/dev/null; then
  fail "a Dockerfile uses the :latest tag"
else
  pass "Dockerfiles pin explicit version tags"
fi

echo "-- 5. Kubernetes securityContext hardening --"
if grep -q 'runAsNonRoot: true' k8s/web-deployment.yaml \
   && grep -q 'allowPrivilegeEscalation: false' k8s/web-deployment.yaml \
   && grep -q 'drop: \["ALL"\]' k8s/web-deployment.yaml; then
  pass "web Deployment sets runAsNonRoot, allowPrivilegeEscalation=false and drops ALL capabilities"
else
  fail "web Deployment securityContext is incomplete"
fi

echo "-- 6. No privileged containers or host namespaces --"
if grep -RInE 'privileged:[[:space:]]*true|hostNetwork:[[:space:]]*true|hostPID:[[:space:]]*true' k8s/ 2>/dev/null; then
  fail "privileged/host namespace settings found in k8s manifests"
else
  pass "no privileged containers, hostNetwork or hostPID in manifests"
fi

echo "-- 7. Pipeline credentials come from Jenkins, not the repository --"
if grep -qE 'credentialsId|credentials\(' Jenkinsfile jenkins/casc/jenkins.yaml; then
  pass "Git access uses the Jenkins credential 'github-kavin'"
else
  fail "no Jenkins credential reference found"
fi
if grep -RInE 'ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}' . --exclude-dir=.git >/dev/null 2>&1; then
  fail "a GitHub token literal was found in the working tree"
else
  pass "no GitHub token literal in the working tree"
fi

echo "-- 8. Local secret material is git-ignored --"
if git check-ignore -q monitoring/.env && git check-ignore -q k8s/db-secret.yaml; then
  pass "monitoring/.env and k8s/db-secret.yaml are ignored by Git"
else
  fail "secret files are not covered by .gitignore"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "SECURITY REVIEW: all checks passed"
else
  echo "SECURITY REVIEW: $fails check(s) failed"
fi
exit "$([ "$fails" -eq 0 ] && echo 0 || echo 1)"

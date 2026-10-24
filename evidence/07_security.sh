#!/usr/bin/env bash
# Screen 07: security checklist executed against the repository and cluster.
set -uo pipefail
cd "$HOME/devops-assignment5"
echo "scripts/security_check.sh - each check run against the repo and live cluster:"
bash scripts/security_check.sh | grep -E '^(PASS|FAIL|SECURITY REVIEW)'

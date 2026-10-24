#!/usr/bin/env bash
# Screen 07: security checklist executed against the repository and cluster.
set -uo pipefail
cd "$HOME/devops-assignment5"
bash scripts/security_check.sh

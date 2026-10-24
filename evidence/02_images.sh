#!/usr/bin/env bash
# Screen 02: image build, tag and availability inside the kind node.
set -uo pipefail
cd "$HOME/devops-assignment5"
TAG="$(kubectl -n technova get deployment technova-web \
      -o jsonpath='{.spec.template.spec.containers[0].image}' | cut -d: -f2)"

echo "Images built by the Jenkins pipeline:"
docker images technova-web-23bcs070 --format 'table {{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}'
echo
echo "Image metadata for the deployed tag ($TAG):"
docker image inspect "technova-web-23bcs070:$TAG" \
  --format 'Tags   : {{.RepoTags}}
User   : {{.Config.User}}
Version: {{index .Config.Labels "version"}}
Commit : {{index .Config.Labels "org.opencontainers.image.revision"}}'
echo
echo "Image present in the kind node containerd store (no registry used):"
docker exec technova-a5-control-plane crictl images | grep -E 'IMAGE|technova-web'
echo
echo "Deployment currently requests:"
kubectl -n technova get deployment technova-web \
  -o custom-columns='NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image,READY:.status.readyReplicas'

// ---------------------------------------------------------------------------
// TechNova Solutions - DevOps Mastery Assignment 5
// Declarative CI/CD pipeline: checkout -> build/test -> Docker build/tag ->
// image into the cluster -> Ansible-rendered Kubernetes deployment ->
// verification -> security checks.
// Roll No: 23BCS070
// ---------------------------------------------------------------------------
pipeline {
    agent any

    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 20, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    environment {
        IMAGE_REPO   = 'technova-web-23bcs070'
        KIND_CLUSTER = 'technova-a5'
        NAMESPACE    = 'technova'
        DEPLOYMENT   = 'technova-web'
        SERVICE_URL  = 'http://localhost:8081'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh '''
                  echo "Repository : $(git config --get remote.origin.url | sed -E 's#https://[^@]*@#https://#')"
                  echo "Branch     : $(git rev-parse --abbrev-ref HEAD)"
                  echo "Commit     : $(git rev-parse --short HEAD) - $(git log -1 --pretty=%s)"
                  echo "Files      : $(git ls-files | wc -l) tracked"
                '''
            }
        }

        stage('Build & Test') {
            steps {
                sh '''
                  docker run --rm -v "$WORKSPACE":/src -w /src python:3.12-slim \
                    sh -c 'pip install --quiet --disable-pip-version-check -r app/requirements-dev.txt \
                           && cd app && python -m pytest -q'
                '''
            }
        }

        stage('Docker Build & Tag') {
            steps {
                script {
                    env.SHORT_SHA = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
                    env.IMAGE_TAG = "1.1.${env.BUILD_NUMBER}"
                }
                sh '''
                  echo "Building $IMAGE_REPO:$IMAGE_TAG from commit $SHORT_SHA"
                  docker build \
                    --build-arg APP_VERSION="$IMAGE_TAG" \
                    --label org.opencontainers.image.revision="$SHORT_SHA" \
                    --label org.opencontainers.image.source="https://github.com/Kavin-MK-Official/devops-assignment5-23bcs070" \
                    -t "$IMAGE_REPO:$IMAGE_TAG" \
                    -t "$IMAGE_REPO:latest" \
                    app
                  docker image inspect "$IMAGE_REPO:$IMAGE_TAG" \
                    --format 'Image: {{.RepoTags}}  Size: {{.Size}} bytes  Version label: {{index .Config.Labels "version"}}  User: {{.Config.User}}'
                '''
            }
        }

        stage('Publish Image to Cluster') {
            steps {
                sh '''
                  # Local-cluster image workflow: the image is built on the same
                  # Docker daemon that hosts the kind node, then loaded into the
                  # node's containerd image store. No registry or pull secret is
                  # needed; in a shared environment this becomes a registry push.
                  kind load docker-image "$IMAGE_REPO:$IMAGE_TAG" --name "$KIND_CLUSTER"
                  docker exec "$KIND_CLUSTER-control-plane" \
                    crictl images | grep "$IMAGE_REPO" || true
                '''
            }
        }

        stage('Configure & Deploy (Ansible)') {
            steps {
                sh '''
                  ansible-playbook -i ansible/inventory.ini ansible/deploy-app.yml \
                    -e image_tag="$IMAGE_TAG"
                '''
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                  kubectl -n "$NAMESPACE" rollout status deployment/"$DEPLOYMENT" --timeout=180s
                  kubectl -n "$NAMESPACE" get deployment "$DEPLOYMENT" \
                    -o custom-columns='NAME:.metadata.name,READY:.status.readyReplicas,IMAGE:.spec.template.spec.containers[0].image'
                  kubectl -n "$NAMESPACE" get pods -l app=technova-web -o wide
                  kubectl -n "$NAMESPACE" get endpoints technova-web
                  echo "--- /version through the Service (NodePort 30080 -> host 8081) ---"
                  curl -fsS "$SERVICE_URL/version"; echo
                  echo "--- /health ---"
                  curl -fsS "$SERVICE_URL/health"; echo
                  echo "--- /metrics sample ---"
                  curl -fsS "$SERVICE_URL/metrics" | grep -E '^(technova_app_info|http_requests_total)' | head -5
                '''
            }
        }

        stage('Security Checks') {
            steps {
                sh 'bash scripts/security_check.sh'
            }
        }
    }

    post {
        success {
            echo "Deployed $IMAGE_REPO:$IMAGE_TAG to namespace $NAMESPACE"
        }
        failure {
            sh '''
              kubectl -n "$NAMESPACE" get pods -o wide || true
              kubectl -n "$NAMESPACE" describe deployment "$DEPLOYMENT" | tail -30 || true
              kubectl -n "$NAMESPACE" logs -l app=technova-web --tail=60 || true
            '''
        }
        always {
            sh 'docker image prune -f --filter "label!=keep" >/dev/null 2>&1 || true'
        }
    }
}

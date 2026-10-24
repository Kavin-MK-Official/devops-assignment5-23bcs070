# Assignment 5 — DevOps Integration and Monitoring (23BCS070)

**Student:** Kavin MK · **Roll No:** 23BCS070 · **Course:** DevOps Mastery (CO5)
**Scenario:** Junior DevOps Engineer at TechNova Solutions — take the Flask application from
Assignment 3 from source control through CI, container packaging, Kubernetes deployment,
a deployment strategy, monitoring, logging and security checks.

---

## 1. What is in this repository

```
.
├── app/                      Flask application, Dockerfile, unit tests
├── Jenkinsfile               declarative CI/CD pipeline (7 stages)
├── Jenkinsfile stages use Ansible for the deployment hand-off
├── jenkins/                  Jenkins controller image + JCasC configuration
├── k8s/                      Namespace, PostgreSQL, web Deployment/Service
│   └── bluegreen/            blue + green Deployments and the switching Service
├── ansible/                  config-automation touchpoint carried from Assignment 4
├── monitoring/               Prometheus + Grafana (provisioned datasource/dashboard)
├── scripts/                  bootstrap, pipeline trigger, blue-green, logs, security review
├── docs/architecture.svg     end-to-end pipeline diagram
└── kind-config.yaml          kind cluster with NodePorts 30080/30081 -> host 8081/8082
```

## 2. End-to-end flow

1. **GitHub** — private repository `Kavin-MK-Official/devops-assignment5-23bcs070`; a commit on
   `main` is the input to the pipeline.
2. **Jenkins** — controller in Docker, configured entirely with JCasC. **Checkout** (Git plugin,
   credential `github-kavin`) then **Build & Test** (`pytest` inside `python:3.12-slim`).
3. **Docker** — multi-stage build of `technova-web-23bcs070:1.1.<build>` with
   `APP_VERSION` build arg and OCI labels.
4. **Image availability** — local-cluster workflow: `kind load docker-image` imports the image
   into the kind node's containerd store. No registry is used, so no registry credentials exist;
   the equivalent production step is a `docker push` with a pull secret.
5. **Kubernetes** — the **Ansible** playbook renders `k8s/web-deployment.yaml` from the image tag
   and applies it; the Deployment rolls 3 replicas with `maxUnavailable: 0`.
6. **Service** — NodePort 30080 is mapped to host port 8081 by kind; the app answers on
   `http://localhost:8081`.
7. **Monitoring / feedback** — Prometheus scrapes the application's `/metrics` endpoint through
   the Service every 10 s; Grafana reads Prometheus. Container logs and `kubectl rollout status`
   provide the operational feedback loop.

Automated: stages 2–6 inside the Jenkinsfile. Manual: creating/pushing the commit (or a webhook),
and the blue-green cut-over, which is run deliberately as an operator action.

## 3. Running it

```bash
bash scripts/bootstrap.sh        # kind cluster, DB secret, images, monitoring stack
bash scripts/start_jenkins.sh    # Jenkins controller on :8088 (JCasC)
bash scripts/trigger_pipeline.sh # run the pipeline and print stage results
bash scripts/bluegreen.sh        # blue-green traffic switch (simulation)
bash scripts/log_evidence.sh     # log inspection incl. an induced DB outage
bash scripts/security_check.sh   # security checklist
bash scripts/verify.sh           # Activity 7 verification table
```

`scripts/run_all.sh` runs the whole sequence; it was recorded with
`script -qec "bash scripts/run_all.sh" assignment5_execution.log`.

## 4. Deployment strategies

**Rolling** — the pipeline's Ansible stage replaces the image tag on the single
`technova-web` Deployment. `maxSurge: 1`, `maxUnavailable: 0` means a new Pod must become
ready before an old one is removed; `kubectl rollout status` blocks until all 3 replicas run
the new tag, and `kubectl rollout undo` is the rollback.

**Blue-green** — implemented as a **single-cluster simulation**, clearly labelled as such:
`technova-web-blue` (1.0.0) and `technova-web-green` (1.1.0) run side by side, and the
`technova-web-bg` Service moves between them with a one-field selector patch. This shows the
traffic switch and instant rollback; it is not two physically separate environments.

| Aspect | Rolling | Blue-green |
|---|---|---|
| How traffic/version changes | Pods replaced in batches behind one Service | Service selector flips from one full version to the other |
| Potential downtime risk | None if readiness probes and `maxUnavailable: 0` are correct; mixed versions during the rollout | None at the switch; both stacks must fit in the cluster |
| Resource requirements | +1 Pod surge during the rollout | 2× the application capacity while both colours run |
| Validation | Per-Pod readiness, then `rollout status` | Full green stack validated before the switch, then a single cut-over |
| Rollback | `kubectl rollout undo` (re-create old Pods) | Flip the selector back — seconds, no Pod restart |

## 5. Monitoring

- Prometheus scrapes `technova-web` (`up`, `http_requests_total`,
  `http_request_duration_seconds`, `technova_db_up`, `technova_app_info`) and itself.
- Grafana is provisioned with the Prometheus data source and the
  `TechNova Web - Assignment 5` dashboard (target status, DB reachability, running version,
  request rate by endpoint, p95 latency).

## 6. Security notes

- No credentials in Git: the DB password is a random value stored in a Kubernetes Secret created
  at runtime; the GitHub token lives in the Jenkins credential store and is injected from the
  environment. `monitoring/.env` and `k8s/db-secret.yaml` are git-ignored.
- The application image runs as uid 10001 (`appuser`), not root; the Deployment sets
  `runAsNonRoot`, `allowPrivilegeEscalation: false`, drops all capabilities and uses
  `RuntimeDefault` seccomp.
- Base images are pinned (`python:3.12-slim`, `postgres:16-alpine`, `jenkins/jenkins:lts-jdk17`,
  `prom/prometheus:v3.1.0`, `grafana/grafana:11.4.0`).
- Lab trade-off: the Jenkins controller mounts `/var/run/docker.sock`, which is root-equivalent on
  the host. It is acceptable for a single-user lab and would be replaced by a dedicated build
  agent or rootless BuildKit in a shared environment.

## 7. Evidence

Screenshots in `Screenshots/`, full terminal session in `assignment5_execution.log`, and the
Notion report mirrors this README. Blue-green evidence is labelled as a simulation.

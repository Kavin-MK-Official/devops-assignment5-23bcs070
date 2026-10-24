# ---------------------------------------------------------------------------
# Jenkins controller image for Assignment 5 (23BCS070)
# Jenkins LTS + the CLI tools the pipeline drives: docker, kubectl, kind and
# ansible-core. Built once and reused by scripts/bootstrap.sh.
# ---------------------------------------------------------------------------
FROM jenkins/jenkins:lts-jdk17

USER root

ARG KUBECTL_VERSION=v1.34.1
ARG KIND_VERSION=v0.30.0

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg git python3 python3-pip \
 && install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
 && chmod a+r /etc/apt/keyrings/docker.asc \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
         https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
         > /etc/apt/sources.list.d/docker.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends docker-ce-cli \
 && rm -rf /var/lib/apt/lists/*

RUN curl -fsSLo /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
 && chmod 0755 /usr/local/bin/kubectl \
 && curl -fsSLo /usr/local/bin/kind \
      "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64" \
 && chmod 0755 /usr/local/bin/kind

RUN python3 -m pip install --no-cache-dir --break-system-packages ansible-core \
 && ansible --version | head -2

# Plugins are pinned in plugins.txt and installed at build time so the
# controller is reproducible (no interactive plugin manager).
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

USER jenkins

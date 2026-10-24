# ---------------------------------------------------------------------------
# TechNova Solutions - DevOps Mastery Assignment 5
# Dockerfile for the Flask web application (Roll No: 23BCS070)
#
# Multi-stage build: the runtime image contains only the application and its
# wheel-installed dependencies, runs as a non-root user and exposes a
# Prometheus metrics endpoint. APP_VERSION is injected at build time so the
# image tag, the /version endpoint and the page always agree.
# ---------------------------------------------------------------------------
ARG PYTHON_VERSION=3.12-slim

# ---- Stage 1: build wheels for the Python dependencies --------------------
FROM python:${PYTHON_VERSION} AS builder

WORKDIR /build

RUN apt-get update \
 && apt-get install -y --no-install-recommends gcc libpq-dev \
 && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt


# ---- Stage 2: runtime image ----------------------------------------------
FROM python:${PYTHON_VERSION}

ARG APP_VERSION=1.0.0

LABEL maintainer="23BCS070" \
      description="TechNova Solutions web application - DevOps Assignment 5" \
      roll_number="23BCS070" \
      version="${APP_VERSION}"

RUN apt-get update \
 && apt-get install -y --no-install-recommends libpq5 curl \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --create-home --uid 10001 appuser \
 && mkdir -p /tmp/prometheus-multiproc \
 && chown appuser:appuser /tmp/prometheus-multiproc

WORKDIR /app

COPY --from=builder /wheels /wheels
COPY requirements.txt .
RUN pip install --no-cache-dir --no-index --find-links=/wheels -r requirements.txt \
 && rm -rf /wheels

COPY app.py .

ENV APP_VERSION=${APP_VERSION} \
    PROMETHEUS_MULTIPROC_DIR=/tmp/prometheus-multiproc \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    LOG_LEVEL=INFO

EXPOSE 5000

USER appuser

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -fsS http://localhost:5000/health || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", \
     "--access-logfile", "-", "--error-logfile", "-", "--log-level", "info", \
     "app:app"]

"""Unit tests for the TechNova application (run in the Jenkins Build & Test stage)."""
import os

import pytest

# Set the version before importing the module so the app_info metric carries
# the test version; unset multi-process mode for an in-process registry.
os.environ["APP_VERSION"] = "test-1.0.0"
os.environ.pop("PROMETHEUS_MULTIPROC_DIR", None)

import app as app_module  # noqa: E402


@pytest.fixture()
def client():
    app_module.app.config["TESTING"] = True
    return app_module.app.test_client()


def test_health_reports_alive(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json()["status"] == "alive"


def test_version_reports_build(client):
    payload = client.get("/version").get_json()
    assert payload["version"] == "test-1.0.0"
    assert payload["roll"] == "23BCS070"


def test_metrics_exposes_request_counter_and_build_info(client):
    client.get("/health")
    body = client.get("/metrics").get_data(as_text=True)
    assert 'technova_app_info{version="test-1.0.0"} 1.0' in body
    assert "http_requests_total" in body
    assert 'endpoint="health"' in body


def test_index_survives_database_outage(client, monkeypatch):
    def broken():
        raise RuntimeError("database down")

    monkeypatch.setattr(app_module, "record_visit", broken)
    response = client.get("/")
    assert response.status_code == 200
    assert "unavailable" in response.get_data(as_text=True)


def test_readiness_fails_when_database_is_down(client, monkeypatch):
    def broken():
        raise RuntimeError("database down")

    monkeypatch.setattr(app_module, "record_visit", broken)
    response = client.get("/ready")
    assert response.status_code == 503
    assert response.get_json()["database"] == "unavailable"

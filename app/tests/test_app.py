"""Unit tests for the TechNova application (run in the Jenkins Build & Test stage)."""
import importlib
import sys

import pytest

sys.path.insert(0, ".")


@pytest.fixture()
def client(monkeypatch):
    monkeypatch.delenv("PROMETHEUS_MULTIPROC_DIR", raising=False)
    monkeypatch.setenv("APP_VERSION", "test-1.0.0")
    import app as app_module

    importlib.reload(app_module)
    app_module.app.config["TESTING"] = True
    return app_module, app_module.app.test_client()


def test_health_reports_alive(client):
    _, flask_client = client
    response = flask_client.get("/health")
    assert response.status_code == 200
    assert response.get_json()["status"] == "alive"


def test_version_reports_build(client):
    _, flask_client = client
    payload = flask_client.get("/version").get_json()
    assert payload["version"] == "test-1.0.0"
    assert payload["roll"] == "23BCS070"


def test_metrics_exposes_request_counter_and_build_info(client):
    module, flask_client = client
    flask_client.get("/health")
    body = flask_client.get("/metrics").get_data(as_text=True)
    assert 'technova_app_info{version="test-1.0.0"} 1.0' in body
    assert "http_requests_total" in body
    assert 'endpoint="health"' in body


def test_index_survives_database_outage(client, monkeypatch):
    module, flask_client = client

    def broken():
        raise RuntimeError("database down")

    monkeypatch.setattr(module, "record_visit", broken)
    response = flask_client.get("/")
    assert response.status_code == 200
    assert "unavailable" in response.get_data(as_text=True)


def test_readiness_fails_when_database_is_down(client, monkeypatch):
    module, flask_client = client

    def broken():
        raise RuntimeError("database down")

    monkeypatch.setattr(module, "record_visit", broken)
    response = flask_client.get("/ready")
    assert response.status_code == 503
    assert response.get_json()["database"] == "unavailable"

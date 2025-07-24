"""Fitness Tracker v2 - Main Application Tests"""

import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


class TestMainEndpoints:
    """Тесты основных endpoints приложения."""

    def test_root_endpoint(self) -> None:
        """Тест корневого endpoint."""
        response = client.get("/")
        assert response.status_code == 200
        data = response.json()
        assert data["message"] == "Hello World from Fitness Tracker v2"
        assert data["status"] == "ok"
        assert data["phase"] == "0"
        assert data["version"] == "0.1.0"

    def test_health_check_endpoint(self) -> None:
        """Тест health check endpoint."""
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["service"] == "fitness-tracker-v2"
        assert data["version"] == "0.1.0"

    def test_api_status_endpoint(self) -> None:
        """Тест API status endpoint."""
        response = client.get("/api/v1/status")
        assert response.status_code == 200
        data = response.json()
        assert data["api_status"] == "operational"
        assert data["version"] == "v1"
        assert data["phase"] == "0 - Infrastructure Setup"


@pytest.fixture
def test_client():
    """Фикстура тестового клиента."""
    return TestClient(app)

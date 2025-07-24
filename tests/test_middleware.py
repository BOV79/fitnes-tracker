"""Тесты функциональности middleware."""

import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_cors_headers() -> None:
    """Тест правильной настройки CORS заголовков."""
    response = client.options(
        "/health",
        headers={
            "Origin": "http://localhost:3000",
            "Access-Control-Request-Method": "GET",
        },
    )

    assert response.status_code == 200
    assert "access-control-allow-origin" in response.headers
    assert "access-control-allow-methods" in response.headers


def test_cors_preflight_request() -> None:
    """Тест обработки CORS preflight запросов."""
    response = client.options(
        "/",
        headers={
            "Origin": "http://localhost:3000",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "Content-Type",
        },
    )

    assert response.status_code == 200


def test_cors_actual_request() -> None:
    """Тест обработки реальных CORS запросов."""
    response = client.get("/health", headers={"Origin": "http://localhost:3000"})

    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "access-control-allow-origin" in response.headers


def test_cors_with_credentials() -> None:
    """Тест CORS с учётными данными."""
    response = client.get(
        "/health", headers={"Origin": "http://localhost:3000", "Cookie": "session=test"}
    )

    assert response.status_code == 200
    # Должен правильно обрабатывать учётные данные


@pytest.mark.integration
def test_cors_integration_across_endpoints() -> None:
    """Тест интеграции CORS через разные эндпоинты."""
    origins = [
        "http://localhost:3000",
        "http://localhost:8080",
        "http://127.0.0.1:3000",
    ]

    endpoints = ["/", "/health", "/api/v1/status"]

    for origin in origins:
        for endpoint in endpoints:
            response = client.get(endpoint, headers={"Origin": origin})
            assert response.status_code == 200
            assert "access-control-allow-origin" in response.headers


def test_cors_allowed_methods() -> None:
    """Тест разрешённых методов CORS."""
    response = client.options(
        "/",
        headers={
            "Origin": "http://localhost:3000",
            "Access-Control-Request-Method": "POST",
        },
    )

    assert response.status_code == 200
    allowed_methods = response.headers.get("access-control-allow-methods", "")

    # Проверим, что основные методы разрешены
    for method in ["GET", "POST", "PUT", "DELETE"]:
        assert method in allowed_methods


def test_cors_credentials_support() -> None:
    """Тест поддержки учётных данных в CORS."""
    response = client.get("/health", headers={"Origin": "http://localhost:3000"})

    assert response.status_code == 200
    # Проверим, что credentials поддерживаются
    credentials_header = response.headers.get("access-control-allow-credentials")
    assert credentials_header == "true"


def test_cors_headers_allowed() -> None:
    """Тест разрешённых заголовков CORS."""
    response = client.options(
        "/health",
        headers={
            "Origin": "http://localhost:3000",
            "Access-Control-Request-Method": "GET",
            "Access-Control-Request-Headers": "Content-Type, Authorization",
        },
    )

    assert response.status_code == 200
    assert "access-control-allow-headers" in response.headers

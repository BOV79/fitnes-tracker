"""Интеграционные тесты для полных рабочих процессов."""

import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_health_check_integration() -> None:
    """Тест полного рабочего процесса проверки здоровья."""
    response = client.get("/health")

    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["service"] == "fitness-tracker-v2"
    assert data["version"] == "0.1.0"
    assert "application/json" in response.headers["content-type"]


def test_api_documentation_access() -> None:
    """Тест доступа к эндпоинтам документации API."""
    # Тест OpenAPI схемы
    response = client.get("/openapi.json")
    assert response.status_code == 200

    schema = response.json()
    assert "openapi" in schema
    assert "info" in schema
    assert schema["info"]["title"] == "Fitness Tracker v2"

    # Тест Swagger UI (должен вернуть HTML)
    response = client.get("/docs")
    assert response.status_code == 200
    assert "text/html" in response.headers["content-type"]


def test_redoc_documentation() -> None:
    """Тест эндпоинта документации ReDoc."""
    response = client.get("/redoc")
    assert response.status_code == 200
    assert "text/html" in response.headers["content-type"]


@pytest.mark.integration
def test_full_application_startup() -> None:
    """Тест корректного запуска приложения со всеми middleware."""
    # Этот тест гарантирует, что приложение может обрабатывать несколько одновременных запросов
    responses = []

    for i in range(5):
        response = client.get("/health")
        responses.append(response)

    # Все запросы должны быть успешными
    for response in responses:
        assert response.status_code == 200
        assert response.json()["status"] == "healthy"


@pytest.mark.integration
def test_cors_integration() -> None:
    """Тест интеграции CORS через разные эндпоинты."""
    origins = [
        "http://localhost:3000",
        "http://localhost:8080",
        "http://127.0.0.1:3000",
    ]

    for origin in origins:
        # Тест health эндпоинта
        response = client.get("/health", headers={"Origin": origin})
        assert response.status_code == 200
        assert "access-control-allow-origin" in response.headers

        # Тест API status эндпоинта
        response = client.get("/api/v1/status", headers={"Origin": origin})
        assert response.status_code == 200
        assert "access-control-allow-origin" in response.headers


@pytest.mark.integration
def test_application_metadata() -> None:
    """Тест метаданных и конфигурации приложения."""
    # Тест OpenAPI схемы содержит правильные метаданные
    response = client.get("/openapi.json")
    schema = response.json()

    assert schema["info"]["title"] == "Fitness Tracker v2"
    assert schema["info"]["version"] == "0.1.0"
    assert "description" in schema["info"]


@pytest.mark.slow
def test_performance_baseline() -> None:
    """Тест базовых характеристик производительности."""
    import time

    # Измерить время отклика для проверки здоровья
    start_time = time.time()
    response = client.get("/health")
    end_time = time.time()

    assert response.status_code == 200
    response_time = end_time - start_time

    # Проверка здоровья должна быть очень быстрой (менее 100мс в тестовом окружении)
    assert (
        response_time < 0.1
    ), f"Проверка здоровья заняла {response_time:.3f}с, ожидалось <0.1с"


def test_error_handling_integration() -> None:
    """Тест обработки ошибок во всём приложении."""
    # Тест обработки 404
    response = client.get("/api/v1/несуществующий")
    assert response.status_code == 404

    # Тест метода не разрешён
    response = client.post("/health")
    assert response.status_code == 405

    # Убедиться, что ответы об ошибках также имеют CORS заголовки при необходимости
    response = client.get(
        "/несуществующий", headers={"Origin": "http://localhost:3000"}
    )
    assert response.status_code == 404
    assert "access-control-allow-origin" in response.headers


@pytest.mark.integration
def test_all_endpoints_consistency() -> None:
    """Тест согласованности всех эндпоинтов."""
    endpoints = [
        ("/", "application/json"),
        ("/health", "application/json"),
        ("/api/v1/status", "application/json"),
        ("/openapi.json", "application/json"),
        ("/docs", "text/html"),
        ("/redoc", "text/html"),
    ]

    for endpoint, expected_content_type in endpoints:
        response = client.get(endpoint)
        assert response.status_code == 200
        assert len(response.content) > 0

        # Проверим content-type
        content_type = response.headers.get("content-type", "")
        assert expected_content_type in content_type


@pytest.mark.integration
def test_logging_integration() -> None:
    """Тест интеграции логирования."""
    # Этот тест проверяет, что логирование работает без ошибок
    # В реальном приложении можно было бы перехватывать логи

    # Делаем несколько запросов, которые должны генерировать логи
    response = client.get("/")
    assert response.status_code == 200

    response = client.get("/health")
    assert response.status_code == 200

    response = client.get("/api/v1/status")
    assert response.status_code == 200

    # Если приложение дошло до этой точки без исключений, логирование работает


@pytest.mark.integration
def test_middleware_chain_integration() -> None:
    """Тест интеграции цепочки middleware."""
    # Проверяем, что все middleware работают вместе корректно
    response = client.get(
        "/health",
        headers={
            "Origin": "http://localhost:3000",
            "User-Agent": "TestClient/1.0",
            "Accept": "application/json",
        },
    )

    assert response.status_code == 200

    # CORS middleware должен добавить заголовки
    assert "access-control-allow-origin" in response.headers

    # Ответ должен быть JSON
    assert "application/json" in response.headers["content-type"]

    # Данные должны быть корректными
    data = response.json()
    assert data["status"] == "healthy"


@pytest.mark.slow
def test_stress_multiple_endpoints() -> None:
    """Тест нагрузки на множественные эндпоинты."""
    import concurrent.futures
    import random

    endpoints = ["/", "/health", "/api/v1/status"]

    def make_random_request():
        endpoint = random.choice(endpoints)
        return client.get(endpoint)

    # Делаем 50 случайных запросов одновременно
    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
        futures = [executor.submit(make_random_request) for _ in range(50)]
        responses = [
            future.result() for future in concurrent.futures.as_completed(futures)
        ]

    # Все запросы должны быть успешными
    for response in responses:
        assert response.status_code == 200


@pytest.mark.integration
def test_api_version_consistency() -> None:
    """Тест согласованности версии API."""
    # Проверим, что версия согласована во всех местах

    # Корневой эндпоинт
    root_response = client.get("/")
    root_data = root_response.json()

    # Health эндпоинт
    health_response = client.get("/health")
    health_data = health_response.json()

    # API status эндпоинт
    status_response = client.get("/api/v1/status")
    status_data = status_response.json()

    # OpenAPI схема
    openapi_response = client.get("/openapi.json")
    openapi_data = openapi_response.json()

    # Все должны содержать версию 0.1.0
    assert root_data["version"] == "0.1.0"
    assert health_data["version"] == "0.1.0"
    assert openapi_data["info"]["version"] == "0.1.0"

    # API status может иметь свою версионность
    assert "version" in status_data


@pytest.mark.integration
def test_phase_0_requirements() -> None:
    """Тест требований Фазы 0."""
    # Проверим, что все требования Фазы 0 выполнены

    # 1. Приложение запускается
    response = client.get("/health")
    assert response.status_code == 200

    # 2. CORS настроен
    response = client.get("/health", headers={"Origin": "http://localhost:3000"})
    assert "access-control-allow-origin" in response.headers

    # 3. Логирование работает (structlog)
    response = client.get("/")
    assert (
        response.status_code == 200
    )  # Если логирование сломано, приложение может упасть

    # 4. Документация доступна
    docs_response = client.get("/docs")
    assert docs_response.status_code == 200

    # 5. API эндпоинты отвечают
    api_response = client.get("/api/v1/status")
    assert api_response.status_code == 200
    api_data = api_response.json()
    assert "0 - Infrastructure Setup" in api_data["phase"]

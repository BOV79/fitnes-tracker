"""Тесты обработки ошибок."""

import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_404_error() -> None:
    """Тест обработки ошибки 404."""
    response = client.get("/несуществующий-эндпоинт")
    assert response.status_code == 404

    # FastAPI возвращает стандартный ответ 404
    response_data = response.json()
    assert "detail" in response_data
    assert response_data["detail"] == "Not Found"


def test_method_not_allowed() -> None:
    """Тест обработки ошибки 405."""
    # Health эндпоинт принимает только GET, попробуем POST
    response = client.post("/health")
    assert response.status_code == 405

    response_data = response.json()
    assert "detail" in response_data
    assert response_data["detail"] == "Method Not Allowed"


def test_invalid_route_structure() -> None:
    """Тест обработки неверной структуры маршрута."""
    response = client.get("/api/v999/invalid")
    assert response.status_code == 404


def test_large_request_url() -> None:
    """Тест обработки очень длинных URL."""
    long_path = "/api/v1/" + "x" * 2000
    response = client.get(long_path)
    # Должен вернуть 404, а не падать
    assert response.status_code == 404


def test_invalid_headers() -> None:
    """Тест обработки неверных заголовков."""
    response = client.get(
        "/health", headers={"Invalid-Header": "value\r\nInjection-Attempt: malicious"}
    )

    # Должен всё равно работать, просто игнорировать неверные заголовки
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"


def test_options_method_on_all_endpoints() -> None:
    """Тест OPTIONS метода на всех эндпоинтах для CORS."""
    endpoints = ["/", "/health", "/api/v1/status"]

    for endpoint in endpoints:
        response = client.options(endpoint, headers={"Origin": "http://localhost:3000"})
        # OPTIONS должен быть разрешён для CORS или возвращать 405 но с CORS заголовками
        assert response.status_code in [200, 405]


def test_unsupported_content_type() -> None:
    """Тест неподдерживаемого типа контента."""
    response = client.post(
        "/health",  # Этот эндпоинт не принимает POST
        headers={"Content-Type": "application/xml"},
        data="<xml>test</xml>",
    )
    assert response.status_code == 405


def test_malformed_request() -> None:
    """Тест неправильно сформированных запросов."""
    # Тест с невалидными query параметрами
    response = client.get("/health?invalid=param&malformed")
    # Должен игнорировать невалидные параметры и работать нормально
    assert response.status_code == 200


@pytest.mark.integration
def test_error_responses_have_cors_headers() -> None:
    """Тест наличия CORS заголовков в ответах об ошибках."""
    # Тест 404 с CORS
    response = client.get(
        "/несуществующий", headers={"Origin": "http://localhost:3000"}
    )
    assert response.status_code == 404
    assert "access-control-allow-origin" in response.headers

    # Тест 405 с CORS
    response = client.post("/health", headers={"Origin": "http://localhost:3000"})
    assert response.status_code == 405
    assert "access-control-allow-origin" in response.headers


def test_multiple_slashes_in_path() -> None:
    """Тест обработки множественных слешей в пути."""
    response = client.get("//health")
    # FastAPI должен нормализовать путь
    assert response.status_code in [200, 404]


def test_path_traversal_protection() -> None:
    """Тест защиты от path traversal атак."""
    malicious_paths = [
        "/../../../etc/passwd",
        "/health/../../../etc/passwd",
        "/api/v1/../../../etc/passwd",
    ]

    for path in malicious_paths:
        response = client.get(path)
        # Не должен возвращать содержимое файлов системы
        assert response.status_code == 404


def test_special_characters_in_url() -> None:
    """Тест обработки специальных символов в URL."""
    special_chars = ["<", ">", '"', "'", "&", "%", "#"]

    for char in special_chars:
        response = client.get(f"/health{char}")
        # Должен корректно обрабатывать без падения
        assert response.status_code in [200, 404, 422]


def test_unicode_in_url() -> None:
    """Тест обработки Unicode символов в URL."""
    unicode_paths = ["/health🚀", "/api/v1/тест", "/здоровье"]

    for path in unicode_paths:
        response = client.get(path)
        # Должен корректно обрабатывать Unicode
        assert response.status_code in [200, 404]


def test_concurrent_error_handling() -> None:
    """Тест обработки ошибок при одновременных запросах."""
    import concurrent.futures

    def make_request():
        return client.get("/несуществующий-эндпоинт")

    # Делаем 10 одновременных запросов к несуществующему эндпоинту
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
        futures = [executor.submit(make_request) for _ in range(10)]
        responses = [
            future.result() for future in concurrent.futures.as_completed(futures)
        ]

    # Все должны вернуть 404
    for response in responses:
        assert response.status_code == 404

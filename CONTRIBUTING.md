# Руководство по участию в проекте Fitness Tracker v2

Спасибо за интерес к проекту Fitness Tracker v2! Этот документ поможет вам быстро начать разработку.

## Быстрый старт

### Предварительные требования
- Python 3.11+ (рекомендуется 3.13)
- Git
- Базовые знания FastAPI

### Настройка окружения
```bash
# 1. Клонировать репозиторий
git clone <url>
cd fitness-tracker-v2

# 2. Активировать виртуальное окружение
source venv/bin/activate

# 3. Установить зависимости
pip install -r requirements.txt

# 4. Установить pre-commit хуки
pre-commit install

# 5. Запустить тесты
./scripts/test.sh --quick

# 6. Запустить сервер разработки
./scripts/dev.sh
```

## Доступные скрипты

### 🧪 Тестирование (`scripts/test.sh`)
```bash
./scripts/test.sh --quick      # Быстрые тесты (~2 сек)
./scripts/test.sh --full       # Полные тесты (~4 сек)
./scripts/test.sh --coverage   # Тесты с покрытием
./scripts/test.sh --help       # Справка
```

### 🔍 Качество кода (`scripts/quality.sh`)
```bash
./scripts/quality.sh           # Проверить качество
./scripts/quality.sh --fix     # Исправить автоматически
./scripts/quality.sh --security # Включить проверки безопасности
./scripts/quality.sh --help    # Справка
```

### 🚀 Разработка (`scripts/dev.sh`)
```bash
./scripts/dev.sh               # Запустить сервер (localhost:8000)
./scripts/dev.sh --port 8080   # На другом порту
./scripts/dev.sh --host 0.0.0.0 # На всех интерфейсах
./scripts/dev.sh --help        # Справка
```

## Стандарты качества

### Автоматические проверки
- **Black**: Форматирование кода (88 символов)
- **Flake8**: Линтинг и стиль кода
- **MyPy**: Проверка типов
- **Pytest**: Минимум 85% покрытия тестов
- **Pre-commit**: Автоматические проверки перед коммитом

### Все проверки должны проходить:
```bash
./scripts/quality.sh    # ✅ Все проверки
./scripts/test.sh --full # ✅ Все тесты с покрытием ≥85%
```

## Рабочий процесс

### 1. Создание ветки
```bash
git checkout -b feature/новая-функция
```

### 2. Разработка
- Пишите код, следуя стандартам
- Добавляйте тесты для новой функциональности
- Проверяйте качество: `./scripts/quality.sh`

### 3. Перед коммитом
```bash
./scripts/test.sh --full    # Убедитесь, что все тесты проходят
git add .
git commit -m "feat: описание изменения"
```

### 4. Push и PR
```bash
git push origin feature/новая-функция
# Создайте Pull Request
```

## Структура проекта

```
fitness-tracker-v2/
├── app/                    # Код приложения
│   ├── main.py            # Основное приложение FastAPI
│   ├── api/               # API роутеры
│   └── core/              # Конфигурация
├── tests/                 # Тесты
│   ├── test_main.py       # Основные тесты
│   ├── test_middleware.py # Тесты middleware
│   ├── test_errors.py     # Тесты ошибок
│   └── test_integration.py # Интеграционные тесты
├── scripts/               # Скрипты автоматизации
│   ├── test.sh           # Тестирование
│   ├── quality.sh        # Проверки качества
│   └── dev.sh            # Сервер разработки
├── pyproject.toml         # Конфигурация проекта
├── requirements.txt       # Зависимости
└── .pre-commit-config.yaml # Pre-commit хуки
```

## Типы тестов

### Unit тесты (`pytest -m unit`)
```python
@pytest.mark.unit
def test_specific_function():
    """Тест конкретной функции."""
    pass
```

### Интеграционные тесты (`pytest -m integration`)
```python
@pytest.mark.integration
def test_full_workflow():
    """Тест полного рабочего процесса."""
    pass
```

### Медленные тесты (`pytest -m slow`)
```python
@pytest.mark.slow
def test_performance():
    """Тест производительности."""
    pass
```

## Соглашения о коммитах

Используйте conventional commits:
- `feat: добавить новую функцию`
- `fix: исправить ошибку`
- `docs: обновить документацию`
- `style: исправить форматирование`
- `refactor: рефакторинг кода`
- `test: добавить тесты`
- `chore: обновить зависимости`

## Устранение неполадок

### Pre-commit хуки не работают
```bash
pre-commit install
pre-commit run --all-files
```

### Тесты падают
```bash
./scripts/test.sh --quick -v  # Подробный вывод
pytest tests/test_file.py::test_name -v  # Конкретный тест
```

### Проблемы с качеством кода
```bash
./scripts/quality.sh --fix   # Автоматические исправления
black .                      # Форматирование
flake8 .                     # Линтинг
mypy app/                    # Типы
```

### Проблемы с сервером
```bash
./scripts/dev.sh --port 8080  # Другой порт
lsof -i :8000                 # Что использует порт
```

## Текущий статус (День 2 завершён ✅)

### Реализовано:
- ✅ **Профессиональная система качества кода** (Black, Flake8, MyPy)
- ✅ **Комплексное тестирование** (39 тестов, покрытие 93%)
- ✅ **Автоматизация** (3 скрипта для всех задач)
- ✅ **Pre-commit хуки** (автоматические проверки)
- ✅ **Безопасность** (сканирование уязвимостей)
- ✅ **Документация** (полная на русском языке)

### Метрики качества:
- **Покрытие тестов**: 93% (цель: ≥85%)
- **Качество кода**: 0 ошибок в линтерах
- **Производительность**: все проверки <5 сек
- **Автоматизация**: 100% процессов автоматизировано

### Готовность к Дню 3:
- [ ] GitHub репозиторий
- [ ] CI/CD pipeline
- [ ] Synology интеграция
- [ ] MVP планирование

---

**Удачной разработки! 🚀**

*Этот проект следует принципам качества кода и современным практикам разработки.*

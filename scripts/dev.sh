#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Без цвета

# Конфигурация
PORT=8000
HOST="127.0.0.1"
RELOAD=true
LOG_LEVEL="info"
HELP_MODE=false
CHECK_ENV=true

# Парсинг аргументов командной строки
while [[ $# -gt 0 ]]; do
    case $1 in
        --port)
            PORT="$2"
            shift 2
            ;;
        --host)
            HOST="$2"
            shift 2
            ;;
        --no-reload)
            RELOAD=false
            shift
            ;;
        --log-level)
            LOG_LEVEL="$2"
            shift 2
            ;;
        --no-check)
            CHECK_ENV=false
            shift
            ;;
        --help|-h)
            HELP_MODE=true
            shift
            ;;
        *)
            echo -e "${RED}Неизвестная опция: $1${NC}"
            exit 1
            ;;
    esac
done

# Показать справку
if [[ "$HELP_MODE" == true ]]; then
    echo -e "${BLUE}Сервер разработки Fitness Tracker v2${NC}"
    echo ""
    echo "Использование: $0 [ОПЦИИ]"
    echo ""
    echo "Опции:"
    echo "  --port PORT       Порт сервера (по умолчанию: 8000)"
    echo "  --host HOST       Хост сервера (по умолчанию: 127.0.0.1)"
    echo "  --no-reload       Отключить авто-перезагрузку при изменении файлов"
    echo "  --log-level LEVEL Уровень логирования: critical, error, warning, info, debug, trace"
    echo "  --no-check        Пропустить проверки окружения"
    echo "  --help, -h        Показать это сообщение справки"
    echo ""
    echo "Примеры:"
    echo "  $0                    # Запуск с настройками по умолчанию"
    echo "  $0 --port 8080       # Запуск на порту 8080"
    echo "  $0 --host 0.0.0.0    # Запуск на всех интерфейсах"
    exit 0
fi

# Функция для печати заголовков секций
print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Функция для проверки успешности команды
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
        return 0
    else
        echo -e "${RED}✗ $1${NC}"
        return 1
    fi
}

print_section "Запуск сервера разработки Fitness Tracker v2"

# Проверить, что мы в правильной директории
if [ ! -f "app/main.py" ]; then
    echo -e "${RED}Ошибка: app/main.py не найден. Вы находитесь в корне проекта?${NC}"
    exit 1
fi

# Проверки окружения
if [[ "$CHECK_ENV" == true ]]; then
    print_section "Проверки окружения"

    # Проверить существование виртуального окружения и активировать его
    if [ -d "venv" ]; then
        echo -e "${YELLOW}Активация виртуального окружения...${NC}"
        source venv/bin/activate
        check_success "Виртуальное окружение активировано"
    else
        echo -e "${YELLOW}Предупреждение: Виртуальное окружение не найдено${NC}"
        echo -e "${YELLOW}Рассмотрите создание: python3 -m venv venv${NC}"
    fi

    # Проверить версию Python
    PYTHON_VERSION=$(python --version 2>&1)
    echo -e "${BLUE}Версия Python: $PYTHON_VERSION${NC}"

    # Проверить установку необходимых пакетов
    echo -e "${YELLOW}Проверка необходимых пакетов...${NC}"

    if python -c "import fastapi" 2>/dev/null; then
        check_success "FastAPI установлен"
    else
        echo -e "${RED}✗ FastAPI не установлен${NC}"
        echo -e "${YELLOW}Запустите: pip install -r requirements.txt${NC}"
        exit 1
    fi

    if python -c "import uvicorn" 2>/dev/null; then
        check_success "Uvicorn установлен"
    else
        echo -e "${RED}✗ Uvicorn не установлен${NC}"
        echo -e "${YELLOW}Запустите: pip install -r requirements.txt${NC}"
        exit 1
    fi

    # Проверить доступность порта
    if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${RED}✗ Порт $PORT уже используется${NC}"
        echo -e "${YELLOW}Попробуйте другой порт с --port XXXX${NC}"
        exit 1
    else
        check_success "Порт $PORT доступен"
    fi
fi

# Создать команду uvicorn
UVICORN_CMD="python -m uvicorn app.main:app --host $HOST --port $PORT --log-level $LOG_LEVEL"

if [[ "$RELOAD" == true ]]; then
    UVICORN_CMD="$UVICORN_CMD --reload"
fi

print_section "Конфигурация сервера"
echo -e "${BLUE}Хост: $HOST${NC}"
echo -e "${BLUE}Порт: $PORT${NC}"
echo -e "${BLUE}Авто-перезагрузка: $RELOAD${NC}"
echo -e "${BLUE}Уровень логирования: $LOG_LEVEL${NC}"
echo -e "${BLUE}URL: http://$HOST:$PORT${NC}"

print_section "Запуск сервера"
echo -e "${GREEN}Запуск сервера разработки...${NC}"
echo -e "${YELLOW}Нажмите Ctrl+C для остановки сервера${NC}"

# Добавить разделитель для ясности
echo -e "\n${BLUE}==================== ВЫВОД СЕРВЕРА ====================${NC}\n"

# Запустить сервер
$UVICORN_CMD

#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Без цвета

# Конфигурация
FIX_MODE=false
HELP_MODE=false
SECURITY_CHECK=false

# Парсинг аргументов командной строки
while [[ $# -gt 0 ]]; do
    case $1 in
        --fix)
            FIX_MODE=true
            shift
            ;;
        --security)
            SECURITY_CHECK=true
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
    echo -e "${BLUE}Скрипт проверки качества кода Fitness Tracker v2${NC}"
    echo ""
    echo "Использование: $0 [ОПЦИИ]"
    echo ""
    echo "Опции:"
    echo "  --fix        Автоматически исправить проблемы форматирования и импортов"
    echo "  --security   Запустить проверки уязвимостей безопасности"
    echo "  --help, -h   Показать это сообщение справки"
    echo ""
    echo "По умолчанию: Запуск всех проверок качества без исправлений"
    exit 0
fi

# Функция для печати заголовков секций
print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Функция для проверки успешности команды
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1 успешно${NC}"
        return 0
    else
        echo -e "${RED}✗ $1 неудачно${NC}"
        return 1
    fi
}

# Функция для запуска с замером времени
run_timed() {
    local start_time=$(date +%s)
    eval "$1"
    local exit_code=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ Завершено за ${duration}с${NC}"
    else
        echo -e "${RED}✗ Не удалось за ${duration}с${NC}"
    fi

    return $exit_code
}

# Начать отсчёт времени
SCRIPT_START=$(date +%s)

print_section "Запуск проверок качества кода"

# Активировать виртуальное окружение если оно существует
if [ -d "venv" ]; then
    echo -e "${YELLOW}Активация виртуального окружения...${NC}"
    source venv/bin/activate
fi

# Проверить, что мы в правильной директории
if [ ! -f "app/main.py" ]; then
    echo -e "${RED}Ошибка: app/main.py не найден. Вы находитесь в корне проекта?${NC}"
    exit 1
fi

FAILED_CHECKS=0

# Форматирование кода
print_section "Форматирование кода (Black)"
if [[ "$FIX_MODE" == true ]]; then
    echo -e "${YELLOW}Исправление форматирования кода...${NC}"
    run_timed "python -m black ."
    check_success "Исправление форматирования Black"
else
    run_timed "python -m black --check --diff ."
    if ! check_success "Проверка форматирования Black"; then
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        echo -e "${YELLOW}Запустите с --fix для автоматического форматирования кода${NC}"
    fi
fi

# Линтинг кода
print_section "Линтинг кода (Flake8)"
run_timed "python -m flake8 . --statistics"
if ! check_success "Линтинг Flake8"; then
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    echo -e "${YELLOW}Исправьте проблемы линтинга вручную${NC}"
fi

# Проверка типов
print_section "Проверка типов (MyPy)"
run_timed "python -m mypy app/ --show-error-codes"
if ! check_success "Проверка типов MyPy"; then
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    echo -e "${YELLOW}Исправьте аннотации типов вручную${NC}"
fi

# Проверка безопасности
if [[ "$SECURITY_CHECK" == true ]]; then
    print_section "Проверка безопасности (Safety)"
    run_timed "python -m safety check"
    if ! check_success "Проверка безопасности Safety"; then
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        echo -e "${YELLOW}Просмотрите уязвимости безопасности выше${NC}"
    fi
fi

# Проверка сложности кода (используя flake8 с плагином сложности)
print_section "Проверка сложности кода"
run_timed "python -m flake8 . --select=C901 --max-complexity=10"
if ! check_success "Проверка сложности"; then
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    echo -e "${YELLOW}Рассмотрите рефакторинг сложных функций${NC}"
fi

# Финальная сводка
SCRIPT_END=$(date +%s)
TOTAL_TIME=$((SCRIPT_END - SCRIPT_START))

print_section "Сводка проверки качества"
echo -e "Общее время выполнения: ${TOTAL_TIME}с"

if [ $FAILED_CHECKS -eq 0 ]; then
    echo -e "${GREEN}🎉 Все проверки качества прошли!${NC}"
    echo -e "${GREEN}Код готов к коммиту${NC}"
    exit 0
else
    echo -e "${RED}❌ $FAILED_CHECKS проверка(и) не прошли${NC}"
    echo -e "${YELLOW}Пожалуйста, исправьте проблемы выше перед коммитом${NC}"

    if [[ "$FIX_MODE" == false ]]; then
        echo -e "${BLUE}Совет: Запустите с --fix для автоматического исправления некоторых проблем${NC}"
    fi

    exit 1
fi

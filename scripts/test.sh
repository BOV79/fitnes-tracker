#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Без цвета

# Конфигурация
MIN_COVERAGE=85
QUICK_MODE=false
FULL_MODE=false
COVERAGE_MODE=false
HELP_MODE=false

# Парсинг аргументов командной строки
while [[ $# -gt 0 ]]; do
    case $1 in
        --quick)
            QUICK_MODE=true
            shift
            ;;
        --full)
            FULL_MODE=true
            shift
            ;;
        --coverage)
            COVERAGE_MODE=true
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
    echo -e "${BLUE}Скрипт тестирования Fitness Tracker v2${NC}"
    echo ""
    echo "Использование: $0 [ОПЦИИ]"
    echo ""
    echo "Опции:"
    echo "  --quick      Запуск только быстрых тестов (без покрытия, без проверок качества)"
    echo "  --full       Запуск полного набора тестов со всеми проверками"
    echo "  --coverage   Запуск тестов с подробным отчётом о покрытии"
    echo "  --help, -h   Показать это сообщение справки"
    echo ""
    echo "По умолчанию: Запуск стандартных тестов с базовыми проверками качества"
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

print_section "Запуск тестов Fitness Tracker v2"

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

# Быстрый режим - только запуск тестов
if [[ "$QUICK_MODE" == true ]]; then
    print_section "Быстрые тесты"
    run_timed "python -m pytest tests/ -v"
    check_success "Быстрые тесты"
    exit $?
fi

# Стандартный и полный режим
FAILED_CHECKS=0

# Проверка форматирования кода
if [[ "$QUICK_MODE" == false ]]; then
    print_section "Форматирование кода (Black)"
    run_timed "python -m black --check --diff ."
    if ! check_success "Форматирование Black"; then
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        echo -e "${YELLOW}Запустите 'black .' для исправления проблем форматирования${NC}"
    fi
fi

# Линтинг кода
if [[ "$QUICK_MODE" == false ]]; then
    print_section "Линтинг кода (Flake8)"
    run_timed "python -m flake8 ."
    if ! check_success "Линтинг Flake8"; then
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
fi

# Проверка типов
if [[ "$QUICK_MODE" == false ]]; then
    print_section "Проверка типов (MyPy)"
    run_timed "python -m mypy app/"
    if ! check_success "Проверка типов MyPy"; then
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
fi

# Проверка безопасности
if [[ "$FULL_MODE" == true ]]; then
    print_section "Проверка безопасности (Safety)"
    run_timed "python -m safety check"
    if ! check_success "Проверка безопасности Safety"; then
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
fi

# Запуск тестов с покрытием
print_section "Запуск тестов"
if [[ "$COVERAGE_MODE" == true || "$FULL_MODE" == true ]]; then
    run_timed "python -m pytest tests/ -v --cov=app --cov-report=term-missing --cov-report=html --cov-fail-under=$MIN_COVERAGE"
    TEST_RESULT=$?

    if [ $TEST_RESULT -eq 0 ]; then
        echo -e "${GREEN}✓ Тесты прошли с покрытием ≥${MIN_COVERAGE}%${NC}"
        if [[ "$COVERAGE_MODE" == true || "$FULL_MODE" == true ]]; then
            echo -e "${BLUE}HTML отчёт о покрытии создан в htmlcov/index.html${NC}"
        fi
    else
        echo -e "${RED}✗ Тесты не прошли или покрытие ниже ${MIN_COVERAGE}%${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
else
    run_timed "python -m pytest tests/ -v"
    TEST_RESULT=$?

    if [ $TEST_RESULT -eq 0 ]; then
        echo -e "${GREEN}✓ Тесты прошли${NC}"
    else
        echo -e "${RED}✗ Тесты не прошли${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
fi

# Финальная сводка
SCRIPT_END=$(date +%s)
TOTAL_TIME=$((SCRIPT_END - SCRIPT_START))

print_section "Сводка"
echo -e "Общее время выполнения: ${TOTAL_TIME}с"

if [ $FAILED_CHECKS -eq 0 ]; then
    echo -e "${GREEN}🎉 Все проверки прошли!${NC}"
    exit 0
else
    echo -e "${RED}❌ $FAILED_CHECKS проверка(и) не прошли${NC}"
    echo -e "${YELLOW}Пожалуйста, исправьте проблемы выше перед коммитом${NC}"
    exit 1
fi

#!/bin/bash

# ==============================================
# Fitness Tracker v2 - Synology Deployment Script
# ==============================================

set -e  # Выход при любой ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
APP_NAME="fitness-tracker-v2"

# Загружаем переменные окружения если .env существует
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    echo -e "${BLUE}📁 Загружаем переменные окружения из .env${NC}"
    source "$PROJECT_ROOT/.env"
fi

# Переменные по умолчанию
SYNOLOGY_HOST="${SYNOLOGY_HOST:-192.168.1.100}"
SYNOLOGY_USER="${SYNOLOGY_USER:-admin}"
SYNOLOGY_SSH_PORT="${SYNOLOGY_SSH_PORT:-22}"
REMOTE_APP_DIR="/volume1/docker/${APP_NAME}"
IMAGE_NAME="ghcr.io/bov79/fitnes-tracker"
IMAGE_TAG="${1:-latest}"

# Функции для логирования
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Функция для выполнения SSH команд
ssh_execute() {
    local command="$1"
    log_info "Выполняем на Synology: $command"
    ssh -i ~/.ssh/synology_fitness -p "$SYNOLOGY_SSH_PORT" "$SYNOLOGY_USER@$SYNOLOGY_HOST" "$command"
}

# Функция для копирования файлов через SCP
scp_copy() {
    local local_path="$1"
    local remote_path="$2"
    log_info "Копируем $local_path в $remote_path"
    scp -i ~/.ssh/synology_fitness -P "$SYNOLOGY_SSH_PORT" "$local_path" "$SYNOLOGY_USER@$SYNOLOGY_HOST:$remote_path"
}

# Проверка зависимостей
check_dependencies() {
    log_info "Проверяем зависимости..."

    if ! command -v ssh &> /dev/null; then
        log_error "SSH не установлен"
        exit 1
    fi

    if ! command -v scp &> /dev/null; then
        log_error "SCP не установлен"
        exit 1
    fi

    if [[ ! -f ~/.ssh/synology_fitness ]]; then
        log_error "SSH ключ ~/.ssh/synology_fitness не найден"
        log_info "Создайте SSH ключ: ssh-keygen -t ed25519 -f ~/.ssh/synology_fitness"
        exit 1
    fi

    log_success "Все зависимости в порядке"
}

# Проверка подключения к Synology
check_connection() {
    log_info "Проверяем подключение к Synology ($SYNOLOGY_HOST:$SYNOLOGY_SSH_PORT)..."

    if ssh_execute "echo 'Connection test successful'"; then
        log_success "Подключение к Synology установлено"
    else
        log_error "Не удается подключиться к Synology"
        exit 1
    fi
}

# Создание структуры директорий на Synology
setup_directories() {
    log_info "Создаем структуру директорий на Synology..."

    ssh_execute "mkdir -p $REMOTE_APP_DIR/{config,logs,data,backups}"
    ssh_execute "mkdir -p $REMOTE_APP_DIR/config/{nginx,prometheus,grafana}"

    log_success "Структура директорий создана"
}

# Копирование конфигурационных файлов
deploy_configs() {
    log_info "Копируем конфигурационные файлы..."

    # Docker Compose файл
    scp_copy "$PROJECT_ROOT/docker-compose.prod.yml" "$REMOTE_APP_DIR/docker-compose.yml"

    # Environment файл (если существует)
    if [[ -f "$PROJECT_ROOT/.env" ]]; then
        scp_copy "$PROJECT_ROOT/.env" "$REMOTE_APP_DIR/.env"
    else
        log_warning ".env файл не найден, используйте .env.example как шаблон"
    fi

    log_success "Конфигурационные файлы скопированы"
}

# Создание backup текущей версии
create_backup() {
    log_info "Создаем backup текущей версии..."

    local backup_name="backup-$(date +%Y%m%d-%H%M%S)"

    ssh_execute "cd $REMOTE_APP_DIR && docker-compose down || true"
    ssh_execute "mkdir -p $REMOTE_APP_DIR/backups/$backup_name"
    ssh_execute "cp -r $REMOTE_APP_DIR/data/* $REMOTE_APP_DIR/backups/$backup_name/ 2>/dev/null || true"

    log_success "Backup создан: $backup_name"
    echo "$backup_name" > /tmp/fitness_tracker_backup_name
}

# Обновление Docker образов
update_images() {
    log_info "Обновляем Docker образы..."

    ssh_execute "docker pull $IMAGE_NAME:$IMAGE_TAG"

    # Обновляем docker-compose.yml с новым тегом
    ssh_execute "cd $REMOTE_APP_DIR && sed -i 's|image: .*fitness-tracker.*|image: $IMAGE_NAME:$IMAGE_TAG|g' docker-compose.yml"

    log_success "Docker образы обновлены"
}

# Запуск приложения
start_application() {
    log_info "Запускаем приложение..."

    ssh_execute "cd $REMOTE_APP_DIR && docker-compose up -d --remove-orphans"

    log_success "Приложение запущено"
}

# Health check
health_check() {
    log_info "Проверяем работоспособность приложения..."

    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        log_info "Попытка $attempt/$max_attempts: проверяем health endpoint..."

        if ssh_execute "curl -f http://localhost:8000/health >/dev/null 2>&1"; then
            log_success "Health check пройден!"
            return 0
        fi

        sleep 10
        ((attempt++))
    done

    log_error "Health check не пройден после $max_attempts попыток"
    return 1
}

# Rollback к предыдущей версии
rollback() {
    log_warning "Выполняем rollback..."

    if [[ -f /tmp/fitness_tracker_backup_name ]]; then
        local backup_name=$(cat /tmp/fitness_tracker_backup_name)
        log_info "Восстанавливаем из backup: $backup_name"

        ssh_execute "cd $REMOTE_APP_DIR && docker-compose down"
        ssh_execute "cp -r $REMOTE_APP_DIR/backups/$backup_name/* $REMOTE_APP_DIR/data/ 2>/dev/null || true"
        ssh_execute "cd $REMOTE_APP_DIR && docker-compose up -d"

        log_success "Rollback выполнен"
    else
        log_error "Backup не найден для rollback"
    fi
}

# Очистка старых образов и backup'ов
cleanup() {
    log_info "Очищаем старые образы и backup'ы..."

    # Удаляем неиспользуемые Docker образы
    ssh_execute "docker system prune -f"

    # Удаляем backup'ы старше 30 дней
    ssh_execute "find $REMOTE_APP_DIR/backups -type d -mtime +30 -exec rm -rf {} + 2>/dev/null || true"

    log_success "Очистка завершена"
}

# Показ логов
show_logs() {
    log_info "Показываем логи приложения..."
    ssh_execute "cd $REMOTE_APP_DIR && docker-compose logs --tail=50 -f app"
}

# Показ статуса
show_status() {
    log_info "Статус сервисов:"
    ssh_execute "cd $REMOTE_APP_DIR && docker-compose ps"

    log_info "Использование ресурсов:"
    ssh_execute "cd $REMOTE_APP_DIR && docker stats --no-stream"
}

# Главная функция деплоя
deploy() {
    echo -e "${BLUE}"
    echo "=================================="
    echo "🚀 Fitness Tracker v2 Deployment"
    echo "=================================="
    echo -e "${NC}"
    echo "Host: $SYNOLOGY_HOST:$SYNOLOGY_SSH_PORT"
    echo "User: $SYNOLOGY_USER"
    echo "Image: $IMAGE_NAME:$IMAGE_TAG"
    echo "Directory: $REMOTE_APP_DIR"
    echo ""

    # Выполняем деплой
    check_dependencies
    check_connection
    setup_directories
    deploy_configs
    create_backup
    update_images
    start_application

    if health_check; then
        cleanup
        log_success "🎉 Деплой успешно завершен!"
        echo ""
        echo "Доступные команды:"
        echo "  $0 status  - показать статус сервисов"
        echo "  $0 logs    - показать логи"
        echo "  $0 rollback - откатить к предыдущей версии"
    else
        log_error "Деплой не удался, выполняем rollback..."
        rollback
        exit 1
    fi
}

# Обработка аргументов командной строки
case "${1:-deploy}" in
    "deploy")
        deploy
        ;;
    "status")
        show_status
        ;;
    "logs")
        show_logs
        ;;
    "rollback")
        rollback
        ;;
    "check")
        check_dependencies
        check_connection
        log_success "Все проверки пройдены"
        ;;
    "cleanup")
        cleanup
        ;;
    "help"|"-h"|"--help")
        echo "Использование: $0 [команда]"
        echo ""
        echo "Команды:"
        echo "  deploy   - выполнить деплой (по умолчанию)"
        echo "  status   - показать статус сервисов"
        echo "  logs     - показать логи приложения"
        echo "  rollback - откатить к предыдущей версии"
        echo "  check    - проверить подключение и зависимости"
        echo "  cleanup  - очистить старые образы и backup'ы"
        echo "  help     - показать эту справку"
        echo ""
        echo "Переменные окружения:"
        echo "  SYNOLOGY_HOST - IP адрес Synology NAS"
        echo "  SYNOLOGY_USER - пользователь для SSH"
        echo "  SYNOLOGY_SSH_PORT - порт SSH (по умолчанию 22)"
        ;;
    *)
        log_error "Неизвестная команда: $1"
        echo "Используйте '$0 help' для справки"
        exit 1
        ;;
esac

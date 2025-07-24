#!/bin/bash

# ==============================================
# Fitness Tracker v2 - Docker Build Script
# ==============================================

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IMAGE_NAME="fitness-tracker-v2"
REGISTRY="ghcr.io/bov79/fitnes-tracker"

# Функции логирования
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

# Получение версии из Git
get_version() {
    if git describe --tags --exact-match 2>/dev/null; then
        # Если на теге, используем версию тега
        git describe --tags --exact-match | sed 's/^v//'
    else
        # Иначе используем версию с commit hash
        echo "0.1.0-dev.$(git rev-parse --short HEAD)"
    fi
}

# Получение build информации
get_build_info() {
    export VERSION=$(get_version)
    export BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
    export GIT_COMMIT=$(git rev-parse HEAD)
    export GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

    log_info "Build информация:"
    echo "  Version: $VERSION"
    echo "  Build Date: $BUILD_DATE"
    echo "  Git Commit: $GIT_COMMIT"
    echo "  Git Branch: $GIT_BRANCH"
}

# Сборка образа
build_image() {
    local tag=${1:-latest}
    local target=${2:-production}

    log_info "Собираем Docker образ..."
    log_info "Tag: $tag"
    log_info "Target: $target"

    docker build \
        --target "$target" \
        --build-arg VERSION="$VERSION" \
        --build-arg BUILD_DATE="$BUILD_DATE" \
        --build-arg GIT_COMMIT="$GIT_COMMIT" \
        --tag "$IMAGE_NAME:$tag" \
        --tag "$IMAGE_NAME:latest" \
        "$PROJECT_ROOT"

    log_success "Образ собран: $IMAGE_NAME:$tag"
}

# Тестирование образа
test_image() {
    local tag=${1:-latest}

    log_info "Тестируем Docker образ..."

    # Запускаем контейнер для тестирования
    local container_id=$(docker run -d -p 8080:8000 --name "test-$IMAGE_NAME" "$IMAGE_NAME:$tag")

    # Ждем запуска
    sleep 10

    # Проверяем health endpoint
    if curl -f http://localhost:8080/health >/dev/null 2>&1; then
        log_success "Health check пройден"
    else
        log_error "Health check не пройден"
        docker logs "$container_id"
        docker rm -f "$container_id"
        return 1
    fi

    # Останавливаем и удаляем тестовый контейнер
    docker rm -f "$container_id"

    log_success "Тестирование образа завершено"
}

# Публикация образа
push_image() {
    local tag=${1:-latest}

    if [[ -z "$GITHUB_TOKEN" ]]; then
        log_warning "GITHUB_TOKEN не установлен, пропускаем публикацию"
        return 0
    fi

    log_info "Публикуем образ в GitHub Container Registry..."

    # Логинимся в GitHub Container Registry
    echo "$GITHUB_TOKEN" | docker login ghcr.io -u BOV79 --password-stdin

    # Тегируем для registry
    docker tag "$IMAGE_NAME:$tag" "$REGISTRY:$tag"
    docker tag "$IMAGE_NAME:$tag" "$REGISTRY:latest"

    # Публикуем
    docker push "$REGISTRY:$tag"
    docker push "$REGISTRY:latest"

    log_success "Образ опубликован: $REGISTRY:$tag"
}

# Анализ размера образа
analyze_image() {
    local tag=${1:-latest}

    log_info "Анализируем размер образа..."

    # Общий размер
    local size=$(docker images "$IMAGE_NAME:$tag" --format "{{.Size}}")
    log_info "Размер образа: $size"

    # История слоев
    docker history "$IMAGE_NAME:$tag" --human --format "table {{.CreatedBy}}\t{{.Size}}"

    # Проверяем цель по размеру (<200MB)
    local size_mb=$(docker images "$IMAGE_NAME:$tag" --format "{{.Size}}" | sed 's/MB//' | cut -d'.' -f1)
    if [[ "$size_mb" -lt 200 ]]; then
        log_success "Размер образа соответствует цели (<200MB)"
    else
        log_warning "Размер образа превышает цель (200MB): ${size_mb}MB"
    fi
}

# Очистка старых образов
cleanup() {
    log_info "Очищаем старые образы..."

    # Удаляем dangling образы
    docker image prune -f

    # Удаляем старые версии (оставляем последние 5)
    docker images "$IMAGE_NAME" --format "table {{.Repository}}:{{.Tag}}\t{{.CreatedAt}}" | \
        tail -n +2 | sort -k2 -r | tail -n +6 | awk '{print $1}' | \
        xargs -r docker rmi 2>/dev/null || true

    log_success "Очистка завершена"
}

# Главная функция сборки
build() {
    local tag=${1:-latest}
    local push=${2:-false}

    echo -e "${BLUE}"
    echo "=================================="
    echo "🐳 Docker Build - Fitness Tracker v2"
    echo "=================================="
    echo -e "${NC}"

    get_build_info
    echo ""

    build_image "$tag"
    test_image "$tag"
    analyze_image "$tag"

    if [[ "$push" == "true" ]]; then
        push_image "$tag"
    fi

    log_success "🎉 Сборка завершена успешно!"

    echo ""
    echo "Доступные образы:"
    docker images "$IMAGE_NAME" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}"
}

# Обработка аргументов
case "${1:-build}" in
    "build")
        build "${2:-latest}" false
        ;;
    "build-push")
        build "${2:-latest}" true
        ;;
    "test")
        test_image "${2:-latest}"
        ;;
    "push")
        push_image "${2:-latest}"
        ;;
    "analyze")
        analyze_image "${2:-latest}"
        ;;
    "cleanup")
        cleanup
        ;;
    "version")
        get_build_info
        ;;
    "help"|"-h"|"--help")
        echo "Использование: $0 [команда] [tag]"
        echo ""
        echo "Команды:"
        echo "  build      - собрать образ (по умолчанию)"
        echo "  build-push - собрать и опубликовать образ"
        echo "  test       - протестировать образ"
        echo "  push       - опубликовать образ"
        echo "  analyze    - проанализировать размер образа"
        echo "  cleanup    - очистить старые образы"
        echo "  version    - показать информацию о версии"
        echo "  help       - показать эту справку"
        echo ""
        echo "Примеры:"
        echo "  $0 build v1.0.0    - собрать образ с тегом v1.0.0"
        echo "  $0 build-push      - собрать и опубликовать с тегом latest"
        echo "  $0 test latest     - протестировать образ latest"
        ;;
    *)
        log_error "Неизвестная команда: $1"
        echo "Используйте '$0 help' для справки"
        exit 1
        ;;
esac

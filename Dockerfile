# Multi-stage build для минимизации размера образа
FROM python:3.14-slim as builder

# Метаданные
LABEL maintainer="BOV79 <your-email@domain.com>"
LABEL description="Fitness Tracker v2 - Modern fitness tracking with Apple Health integration"
LABEL version="2.0"

# Build arguments
ARG VERSION=0.1.0
ARG BUILD_DATE
ARG GIT_COMMIT

# Environment labels
LABEL org.opencontainers.image.version=$VERSION
LABEL org.opencontainers.image.created=$BUILD_DATE
LABEL org.opencontainers.image.revision=$GIT_COMMIT
LABEL org.opencontainers.image.source="https://github.com/BOV79/fitnes-tracker"

# Устанавливаем системные зависимости для сборки
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        && rm -rf /var/lib/apt/lists/*

# Создаем виртуальное окружение
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Копируем файлы зависимостей
COPY requirements.txt .

# Устанавливаем Python зависимости
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Production stage
FROM python:3.14-slim as production

# Создаем пользователя без прав root для безопасности
RUN groupadd --gid 1000 appuser && \
    useradd --uid 1000 --gid appuser --shell /bin/bash --create-home appuser

# Устанавливаем runtime зависимости
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        dumb-init \
        && rm -rf /var/lib/apt/lists/*

# Копируем виртуальное окружение из builder stage
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Создаем рабочую директорию
WORKDIR /app

# Копируем код приложения
COPY --chown=appuser:appuser app/ ./app/
COPY --chown=appuser:appuser pyproject.toml ./

# Создаем директории для логов и данных
RUN mkdir -p /app/logs /app/data && \
    chown -R appuser:appuser /app

# Переключаемся на непривилегированного пользователя
USER appuser

# Environment variables
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV APP_VERSION=$VERSION

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Expose port
EXPOSE 8000

# Volumes для персистентных данных
VOLUME ["/app/logs", "/app/data"]

# Команда запуска с использованием dumb-init для правильной обработки сигналов
ENTRYPOINT ["dumb-init", "--"]
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1", "--log-config", "/dev/null"]

"""Fitness Tracker v2 - Main Application"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import structlog

# Настройка логирования
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer(),
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

app = FastAPI(
    title="Fitness Tracker v2",
    description="Fitness data tracking with Apple Health integration",
    version="0.1.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS настройки - ИСПРАВЛЕНО!
ALLOWED_ORIGINS = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    "http://localhost:8080",
    "http://127.0.0.1:8080",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup_event() -> None:
    """Инициализация приложения при запуске."""
    logger.info("Starting Fitness Tracker v2", version="0.1.0", phase="0")


@app.on_event("shutdown")
async def shutdown_event() -> None:
    """Завершение работы приложения."""
    logger.info("Shutting down Fitness Tracker v2")


@app.get("/")
async def root() -> dict[str, str]:
    """Корневой endpoint."""
    logger.info("Root endpoint accessed")
    return {
        "message": "Hello World from Fitness Tracker v2",
        "status": "ok",
        "phase": "0",
        "version": "0.1.0",
    }


@app.get("/health")
async def health_check() -> dict[str, str]:
    """Health check endpoint для мониторинга."""
    logger.info("Health check requested")
    return {"status": "healthy", "service": "fitness-tracker-v2", "version": "0.1.0"}


@app.get("/api/v1/status")
async def api_status() -> dict[str, str]:
    """API статус endpoint."""
    logger.info("API status requested")
    return {
        "api_status": "operational",
        "version": "v1",
        "phase": "0 - Infrastructure Setup",
    }


if __name__ == "__main__":
    import uvicorn

    logger.info("Starting development server")
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True, log_level="info")

from fastapi import FastAPI
from middlewares.logging import LoggingMiddleware

from .api.health import router as health_router
from .config import get_settings


def create_app() -> FastAPI:
    app = FastAPI(title="Blockrendum")
    settings = get_settings()
    app.add_middleware(LoggingMiddleware)
    app.include_router(health_router, prefix=settings.api_prefix)
    return app


app = create_app()

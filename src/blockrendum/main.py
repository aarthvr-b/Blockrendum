from fastapi import FastAPI

from blockrendum.config import get_settings


def create_app() -> FastAPI:
    settings = get_settings()
    print(f"app_name: {settings.app_name}")
    return FastAPI(title="Blockrendum")


app = create_app()


@app.get("/health")
async def check_health():
    return {"status": "ok"}

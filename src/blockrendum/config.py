from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    app_name:str = "Blockrendum"
    app_env:str = ""
    api_prefix:str = "/api/v1"

def get_settings() -> Settings:
    return Settings()

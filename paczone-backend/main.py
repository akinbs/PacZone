import uvicorn
from fastapi import FastAPI
from app.core.config import settings
from app.core.cors import setup_cors
from app.core.errors import setup_error_handlers
from app.api.router import api_router

app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    docs_url="/docs",
    redoc_url="/redoc",
)

setup_cors(app)
setup_error_handlers(app)

app.include_router(api_router, prefix=settings.API_PREFIX)


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)

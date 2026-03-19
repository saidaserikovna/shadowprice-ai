from __future__ import annotations

from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from .config import Settings, get_settings
from .schemas import AnalysisRequest, ChatRequest, ChatResponse, PriceComparisonResponse
from .services.comparison_service import ComparisonService


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title='ShadowPrice AI Backend',
        version='1.0.0',
        summary='Real-time marketplace comparison backend for ShadowPrice AI',
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=['*'],
        allow_headers=['*'],
    )

    service = ComparisonService(settings)

    @app.on_event('startup')
    async def _startup() -> None:
        await service.startup()

    @app.on_event('shutdown')
    async def _shutdown() -> None:
        await service.shutdown()

    @app.get('/healthz')
    async def health() -> dict[str, str]:
        return {'status': 'ok'}

    @app.post('/api/v1/analyze', response_model=PriceComparisonResponse)
    async def analyze(
        request: AnalysisRequest,
        app_settings: Settings = Depends(get_settings),
    ) -> PriceComparisonResponse:
        _ = app_settings
        try:
            return await service.compare(request.query)
        except Exception as error:
            raise HTTPException(status_code=400, detail=str(error)) from error

    @app.post('/api/v1/chat', response_model=ChatResponse)
    async def chat(request: ChatRequest) -> ChatResponse:
        try:
            return await service.ai.answer_chat(request)
        except Exception as error:
            raise HTTPException(status_code=400, detail=str(error)) from error

    return app


app = create_app()

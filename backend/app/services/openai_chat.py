from __future__ import annotations

import json
from datetime import datetime, timezone

from ..config import Settings
from ..schemas import ChatRequest, ChatResponse, PriceComparisonResponse


class OpenAIChatService:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._client = None
        if settings.openai_api_key:
            from openai import AsyncOpenAI

            self._client = AsyncOpenAI(api_key=settings.openai_api_key)

    @property
    def enabled(self) -> bool:
        return self._client is not None

    async def summarize_analysis(self, analysis: PriceComparisonResponse) -> str | None:
        if not self.enabled or self._client is None:
            return None

        prompt = (
            'You are ShadowPrice AI. Summarize this real-time marketplace comparison. '
            'Use only the supplied JSON and never invent prices, stores, or timing. '
            'Keep it under 120 words.'
        )
        response = await self._client.responses.create(
            model=self._settings.openai_model,
            instructions=prompt,
            input=json.dumps(analysis.model_dump(mode='json'), ensure_ascii=False),
        )
        return response.output_text.strip() or None

    async def answer_chat(self, request: ChatRequest) -> ChatResponse:
        if not self.enabled or self._client is None:
            return self._rules_fallback(request)

        history = [{'role': message.role, 'content': message.content} for message in request.history]
        context = {
            'analysis': request.analysis.model_dump(mode='json') if request.analysis else None,
            'question': request.question,
        }

        response = await self._client.responses.create(
            model=self._settings.openai_model,
            instructions=(
                'You are ShadowPrice AI, a shopping assistant. '
                'Answer only from the provided extracted marketplace data. '
                'If the data does not prove something, say that clearly. '
                'Never invent a store, price, discount, prediction, or timing signal. '
                'Use concise English.'
            ),
            input=history + [{'role': 'user', 'content': json.dumps(context, ensure_ascii=False)}],
        )

        return ChatResponse(
            answer=response.output_text.strip(),
            provider='openai',
            model=self._settings.openai_model,
            suggested_questions=_default_suggested_questions(request.analysis),
            timestamp=datetime.now(timezone.utc),
        )

    def _rules_fallback(self, request: ChatRequest) -> ChatResponse:
        if request.analysis is None or not request.analysis.offers:
            answer = (
                'Analyze a product first so I can answer from live marketplace data. '
                'Right now I do not have verified prices to compare.'
            )
        else:
            cheapest = request.analysis.cheapest_offer
            if cheapest is None:
                answer = 'I do not have a verified cheapest offer yet.'
            else:
                answer = (
                    f'The cheapest verified option right now is {cheapest.marketplace} at '
                    f'{cheapest.price:g} {cheapest.currency or ""}. '
                    f'{request.analysis.reasoning}'
                ).strip()

        return ChatResponse(
            answer=answer,
            provider='rules',
            model=None,
            suggested_questions=_default_suggested_questions(request.analysis),
            timestamp=datetime.now(timezone.utc),
        )


def _default_suggested_questions(analysis: PriceComparisonResponse | None) -> list[str]:
    if analysis is None or not analysis.offers:
        return [
            'Where is it cheapest?',
            'Should I buy now or wait?',
            'Which store looks best?',
        ]
    cheapest = analysis.cheapest_offer.marketplace if analysis.cheapest_offer else 'the cheapest store'
    return [
        f'Why is {cheapest} the best option?',
        'Should I buy now or wait?',
        'What should I watch before ordering?',
    ]

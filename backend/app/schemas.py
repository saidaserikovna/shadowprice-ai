from __future__ import annotations

from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, Field, HttpUrl


class AnalysisRequest(BaseModel):
    query: str = Field(min_length=2, max_length=1000)
    locale: str = 'en-US'


class SourceProduct(BaseModel):
    input_value: str
    extracted_from_url: bool
    product_name: str
    normalized_name: str
    store_name: Optional[str] = None
    product_url: Optional[HttpUrl] = None
    image_url: Optional[HttpUrl] = None
    price: Optional[float] = None
    currency: Optional[str] = None


class MarketplaceOffer(BaseModel):
    marketplace: str
    title: str
    normalized_title: str
    price: float
    currency: Optional[str] = None
    price_text: Optional[str] = None
    product_url: HttpUrl
    image_url: Optional[HttpUrl] = None
    in_stock: Optional[bool] = None
    extracted_at: datetime
    similarity_score: float
    matched_query: str
    extraction_source: Literal['search_result', 'product_page']


class MarketplaceFailure(BaseModel):
    marketplace: str
    reason: str


class PriceComparisonResponse(BaseModel):
    query: str
    normalized_query: str
    source_product: Optional[SourceProduct] = None
    offers: list[MarketplaceOffer]
    cheapest_offer: Optional[MarketplaceOffer] = None
    marketplaces_checked: list[str]
    failures: list[MarketplaceFailure] = Field(default_factory=list)
    recommendation: Literal['buy', 'wait']
    reasoning: str
    ai_summary: Optional[str] = None
    timestamp: datetime


class ChatMessage(BaseModel):
    role: Literal['user', 'assistant']
    content: str = Field(min_length=1, max_length=4000)


class ChatRequest(BaseModel):
    question: str = Field(min_length=1, max_length=4000)
    analysis: Optional[PriceComparisonResponse] = None
    history: list[ChatMessage] = Field(default_factory=list)


class ChatResponse(BaseModel):
    answer: str
    provider: Literal['openai', 'rules']
    model: Optional[str] = None
    suggested_questions: list[str] = Field(default_factory=list)
    timestamp: datetime

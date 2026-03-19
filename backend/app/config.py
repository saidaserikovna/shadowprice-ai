from __future__ import annotations

import os
from dataclasses import dataclass, field
from functools import lru_cache
from typing import List


def _parse_bool(value: str | None, default: bool) -> bool:
    if value is None:
        return default
    return value.strip().lower() not in {'0', 'false', 'no', 'off'}


def _parse_csv(value: str | None, default: List[str]) -> List[str]:
    if not value:
        return default
    return [item.strip() for item in value.split(',') if item.strip()]


@dataclass(frozen=True)
class Settings:
    openai_api_key: str | None = os.getenv('OPENAI_API_KEY') or os.getenv('SHADOWPRICE_OPENAI_API_KEY')
    openai_model: str = os.getenv('SHADOWPRICE_OPENAI_MODEL', 'gpt-5.4-mini')
    cors_origins: List[str] = field(
        default_factory=lambda: _parse_csv(os.getenv('SHADOWPRICE_CORS_ORIGINS'), ['*'])
    )
    browser_enabled: bool = _parse_bool(os.getenv('SHADOWPRICE_BROWSER_ENABLED'), True)
    browser_headless: bool = _parse_bool(os.getenv('SHADOWPRICE_BROWSER_HEADLESS'), True)
    request_timeout: float = float(os.getenv('SHADOWPRICE_REQUEST_TIMEOUT', '12'))
    search_results_per_market: int = int(os.getenv('SHADOWPRICE_RESULTS_PER_MARKET', '3'))
    verify_top_n: int = int(os.getenv('SHADOWPRICE_VERIFY_TOP_N', '2'))
    max_concurrency: int = int(os.getenv('SHADOWPRICE_MAX_CONCURRENCY', '6'))
    user_agent: str = os.getenv(
        'SHADOWPRICE_USER_AGENT',
        (
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/136.0.0.0 Safari/537.36'
        ),
    )


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()

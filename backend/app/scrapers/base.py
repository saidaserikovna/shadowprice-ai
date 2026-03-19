from __future__ import annotations

import asyncio
from dataclasses import dataclass, field
from typing import Iterable
from urllib.parse import quote_plus, urljoin

import httpx
from bs4 import BeautifulSoup, Tag

from ..config import Settings
from ..services.browser import BrowserManager
from ..services.page_extract import ProductSnapshot, detect_bot_block, extract_product_snapshot, parse_price_text
from ..utils.text import normalize_product_name, similarity_score


@dataclass
class SearchCandidate:
    marketplace: str
    title: str
    url: str
    price_text: str | None = None
    image_url: str | None = None
    in_stock: bool | None = None


@dataclass
class VerifiedOffer:
    marketplace: str
    title: str
    normalized_title: str
    price: float
    currency: str | None
    price_text: str | None
    product_url: str
    image_url: str | None
    in_stock: bool | None
    similarity_score: float
    extraction_source: str


@dataclass
class ScrapeResult:
    marketplace: str
    offers: list[VerifiedOffer] = field(default_factory=list)
    error: str | None = None


class MarketplaceScraper:
    name = 'base'
    base_url = ''
    search_path = ''
    prefers_browser = False

    def build_search_url(self, query: str) -> str:
        return self.search_path.format(query=quote_plus(query))

    async def search(
        self,
        query: str,
        client: httpx.AsyncClient,
        browser: BrowserManager,
        settings: Settings,
        semaphore: asyncio.Semaphore,
    ) -> ScrapeResult:
        search_url = self.build_search_url(query)

        try:
            html, final_url = await self._load_html(
                search_url,
                client=client,
                browser=browser,
                settings=settings,
                force_browser=self.prefers_browser,
            )
            candidates = self.parse_candidates(html, final_url)
            if not candidates:
                return ScrapeResult(self.name, error='No live candidates were extracted.')

            scored = [
                (
                    candidate,
                    similarity_score(query, candidate.title),
                )
                for candidate in candidates
                if candidate.title and candidate.url
            ]
            scored.sort(key=lambda item: item[1], reverse=True)
            scored = [item for item in scored if item[1] >= 0.45][: settings.verify_top_n]

            if not scored:
                return ScrapeResult(self.name, error='No close product match was verified.')

            offers = await asyncio.gather(
                *[
                    self._verify_candidate(
                        candidate=item[0],
                        match_score=item[1],
                        client=client,
                        browser=browser,
                        settings=settings,
                        semaphore=semaphore,
                    )
                    for item in scored
                ]
            )
            verified = [offer for offer in offers if offer is not None]
            if not verified:
                return ScrapeResult(self.name, error='Candidates were found but could not be verified.')

            return ScrapeResult(self.name, offers=verified)
        except Exception as error:  # pragma: no cover - scraper failures are runtime specific
            return ScrapeResult(self.name, error=str(error))

    def parse_candidates(self, html: str, final_url: str) -> list[SearchCandidate]:
        raise NotImplementedError

    async def _verify_candidate(
        self,
        candidate: SearchCandidate,
        match_score: float,
        client: httpx.AsyncClient,
        browser: BrowserManager,
        settings: Settings,
        semaphore: asyncio.Semaphore,
    ) -> VerifiedOffer | None:
        async with semaphore:
            snapshot: ProductSnapshot | None = None
            try:
                html, final_url = await self._load_html(
                    candidate.url,
                    client=client,
                    browser=browser,
                    settings=settings,
                    force_browser=self.prefers_browser,
                )
                snapshot = extract_product_snapshot(
                    html,
                    final_url,
                    store_hint=self.name,
                )
            except Exception:
                snapshot = None

            if snapshot is not None:
                return VerifiedOffer(
                    marketplace=self.name,
                    title=snapshot.title,
                    normalized_title=normalize_product_name(snapshot.title),
                    price=snapshot.price,
                    currency=snapshot.currency,
                    price_text=None,
                    product_url=snapshot.product_url,
                    image_url=snapshot.image_url or candidate.image_url,
                    in_stock=snapshot.in_stock,
                    similarity_score=match_score,
                    extraction_source=snapshot.extraction_source,
                )

            price, currency = parse_price_text(candidate.price_text)
            if price is None:
                return None

            return VerifiedOffer(
                marketplace=self.name,
                title=candidate.title,
                normalized_title=normalize_product_name(candidate.title),
                price=price,
                currency=currency,
                price_text=candidate.price_text,
                product_url=candidate.url,
                image_url=candidate.image_url,
                in_stock=candidate.in_stock,
                similarity_score=match_score,
                extraction_source='search_result',
            )

    async def _load_html(
        self,
        url: str,
        *,
        client: httpx.AsyncClient,
        browser: BrowserManager,
        settings: Settings,
        force_browser: bool = False,
    ) -> tuple[str, str]:
        if force_browser and browser.enabled:
            browser_result = await browser.fetch(url)
            return browser_result.html, browser_result.final_url

        response = await client.get(url)
        response.raise_for_status()
        html = response.text
        final_url = str(response.url)

        if detect_bot_block(html) and browser.enabled:
            browser_result = await browser.fetch(url)
            return browser_result.html, browser_result.final_url

        return html, final_url

    def _candidate(
        self,
        *,
        title: str | None,
        url: str | None,
        base_url: str,
        price_text: str | None = None,
        image_url: str | None = None,
        in_stock: bool | None = None,
    ) -> SearchCandidate | None:
        if not title or not url:
            return None
        return SearchCandidate(
            marketplace=self.name,
            title=' '.join(title.split()),
            url=urljoin(base_url, url),
            price_text=' '.join(price_text.split()) if price_text else None,
            image_url=urljoin(base_url, image_url) if image_url else None,
            in_stock=in_stock,
        )

    def _text(self, node: Tag | None, selectors: Iterable[str]) -> str | None:
        if node is None:
            return None
        for selector in selectors:
            target = node.select_one(selector)
            if target:
                text = target.get_text(' ', strip=True)
                if text:
                    return text
        return None

    def _attr(self, node: Tag | None, selectors: Iterable[str], attr_name: str) -> str | None:
        if node is None:
            return None
        for selector in selectors:
            target = node.select_one(selector)
            if target:
                value = target.get(attr_name)
                if value:
                    return value.strip()
        return None

    def soup(self, html: str) -> BeautifulSoup:
        return BeautifulSoup(html, 'lxml')

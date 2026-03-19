from __future__ import annotations

import asyncio
import re
from datetime import datetime, timezone
from statistics import median
from urllib.parse import unquote, urlparse

import httpx

from ..config import Settings
from ..schemas import MarketplaceFailure, MarketplaceOffer, PriceComparisonResponse, SourceProduct
from ..services.browser import BrowserManager
from ..services.openai_chat import OpenAIChatService
from ..services.page_extract import detect_bot_block, extract_product_hint, extract_product_snapshot
from ..scrapers.aliexpress import AliExpressScraper
from ..scrapers.amazon import AmazonScraper
from ..scrapers.base import ScrapeResult
from ..scrapers.ebay import EbayScraper
from ..scrapers.kaspi import KaspiScraper
from ..scrapers.ozon import OzonScraper
from ..scrapers.wildberries import WildberriesScraper
from ..utils.text import looks_like_url, normalize_product_name


class ComparisonService:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._http = httpx.AsyncClient(
            follow_redirects=True,
            timeout=settings.request_timeout,
            headers={
                'User-Agent': settings.user_agent,
                'Accept-Language': 'en-US,en;q=0.9',
                'Cache-Control': 'no-cache',
            },
        )
        self._browser = BrowserManager(settings)
        self._ai = OpenAIChatService(settings)
        self._scrapers = [
            KaspiScraper(),
            AmazonScraper(),
            EbayScraper(),
            AliExpressScraper(),
            WildberriesScraper(),
            OzonScraper(),
        ]
        self._verify_semaphore = asyncio.Semaphore(settings.max_concurrency)

    async def startup(self) -> None:
        if self._browser.enabled:
            await self._browser.startup()

    async def shutdown(self) -> None:
        await self._http.aclose()
        await self._browser.shutdown()

    async def compare(self, query: str) -> PriceComparisonResponse:
        source_product = await self._resolve_source(query)
        search_query = source_product.product_name if source_product else query.strip()
        normalized_query = normalize_product_name(search_query)
        failures: list[MarketplaceFailure] = []
        results: list[ScrapeResult] = []
        url_guidance = self._url_guidance_failure(source_product)
        if url_guidance is not None:
            failures.append(url_guidance)

        if url_guidance is None and self._can_search_from_source(source_product, search_query):
            tasks = [
                scraper.search(
                    search_query,
                    client=self._http,
                    browser=self._browser,
                    settings=self._settings,
                    semaphore=self._verify_semaphore,
                )
                for scraper in self._scrapers
            ]
            results = await asyncio.gather(*tasks)
        elif url_guidance is None and source_product and source_product.extracted_from_url:
            failures.append(
                MarketplaceFailure(
                    marketplace='Source URL',
                    reason=(
                        'This link did not expose a reliable product name for cross-market comparison. '
                        'Try a more direct product page.'
                    ),
                )
            )

        offers, result_failures = self._collect_results(results, search_query)
        failures.extend(result_failures)
        source_offer = self._source_offer(source_product)
        if source_offer is not None:
            offers.insert(0, source_offer)
            offers = self._dedupe_offers(offers)
            failures = self._remove_source_marketplace_failures(failures, source_offer.marketplace)
        browser_issue = self._browser.startup_error
        if browser_issue:
            failures.append(
                MarketplaceFailure(
                    marketplace='Browser fallback',
                    reason=(
                        'Playwright browser could not start, so anti-bot protected marketplaces '
                        'may return fewer verified results.'
                    ),
                )
            )
        cheapest = min(offers, key=lambda item: item.price, default=None)
        recommendation = self._recommend(source_product, offers)
        reasoning = self._reason(source_product, offers, cheapest, recommendation)

        response = PriceComparisonResponse(
            query=query.strip(),
            normalized_query=normalized_query,
            source_product=source_product,
            offers=offers,
            cheapest_offer=cheapest,
            marketplaces_checked=[scraper.name for scraper in self._scrapers],
            failures=failures,
            recommendation=recommendation,
            reasoning=reasoning,
            ai_summary=None,
            timestamp=datetime.now(timezone.utc),
        )

        response.ai_summary = await self._ai.summarize_analysis(response)
        return response

    async def _resolve_source(self, query: str) -> SourceProduct | None:
        stripped = query.strip()
        if not looks_like_url(stripped):
            normalized = normalize_product_name(stripped)
            return SourceProduct(
                input_value=stripped,
                extracted_from_url=False,
                product_name=stripped,
                normalized_name=normalized,
            )

        if self._is_supported_marketplace_url(stripped) and not self._is_supported_product_page_url(stripped):
            return self._fallback_source_from_url(stripped, stripped)

        final_url = stripped
        html: str | None = None
        snapshot = None
        hint = None

        try:
            response = await self._http.get(stripped)
            response.raise_for_status()
            html = response.text
            final_url = str(response.url)
            snapshot = extract_product_snapshot(html, final_url)
            if snapshot is None:
                hint = extract_product_hint(html, final_url)
            if (detect_bot_block(html) or (snapshot is None and hint is None)) and self._browser.enabled:
                try:
                    html, final_url, snapshot, hint = await self._resolve_source_via_browser(stripped)
                except Exception:
                    pass
        except Exception:
            if self._browser.enabled:
                try:
                    html, final_url, snapshot, hint = await self._resolve_source_via_browser(stripped)
                except Exception:
                    pass

        if snapshot is not None:
            return SourceProduct(
                input_value=stripped,
                extracted_from_url=True,
                product_name=snapshot.title,
                normalized_name=normalize_product_name(snapshot.title),
                store_name=snapshot.store_name,
                product_url=snapshot.product_url,
                image_url=snapshot.image_url,
                price=snapshot.price,
                currency=snapshot.currency,
            )

        if hint is not None:
            if not self._has_meaningful_product_name(hint.title):
                return self._fallback_source_from_url(stripped, final_url)
            return SourceProduct(
                input_value=stripped,
                extracted_from_url=True,
                product_name=hint.title,
                normalized_name=normalize_product_name(hint.title),
                store_name=hint.store_name,
                product_url=hint.product_url,
                image_url=hint.image_url,
            )

        return self._fallback_source_from_url(stripped, final_url)

    def _url_guidance_failure(self, source_product: SourceProduct | None) -> MarketplaceFailure | None:
        if source_product is None or not source_product.extracted_from_url:
            return None

        input_url = source_product.input_value
        if self._is_supported_marketplace_url(input_url) and not self._is_supported_product_page_url(input_url):
            return MarketplaceFailure(
                marketplace='Source URL',
                reason=(
                    'Paste the exact product page, not a search, category, or store page. '
                    'Supported product links: Kaspi /shop/p/, Amazon /dp/, eBay /itm/, '
                    'AliExpress /item/, Wildberries detail.aspx, Ozon /product/.'
                ),
            )

        if not self._is_supported_marketplace_url(input_url) and source_product.price is None:
            return MarketplaceFailure(
                marketplace='Source URL',
                reason=(
                    'Supported links work best from Kaspi.kz, Amazon, eBay, AliExpress, Wildberries, and Ozon. '
                    'Paste a direct product page from one of those marketplaces.'
                ),
            )

        return None

    async def _resolve_source_via_browser(
        self,
        url: str,
    ) -> tuple[str | None, str, object | None, object | None]:
        browser_result = await self._browser.fetch(url)
        html = browser_result.html
        final_url = browser_result.final_url
        snapshot = extract_product_snapshot(html, final_url)
        hint = extract_product_hint(html, final_url) if snapshot is None else None
        return html, final_url, snapshot, hint

    def _fallback_source_from_url(self, input_url: str, final_url: str | None = None) -> SourceProduct:
        resolved_url = final_url or input_url
        source_for_name = input_url
        path_segments = [
            segment
            for segment in urlparse(source_for_name).path.split('/')
            if segment and segment.casefold() not in {'item', 'dp', 'gp', 'product', 'p'}
        ]

        fallback_name = ''
        for segment in reversed(path_segments):
            candidate = unquote(segment)
            candidate = re.sub(r'\.html?$', '', candidate, flags=re.IGNORECASE)
            candidate = re.sub(r'\b\d{6,}\b', ' ', candidate)
            candidate = re.sub(r'[_\-]+', ' ', candidate)
            candidate = re.sub(r'[^\w\s]+', ' ', candidate)
            candidate = ' '.join(candidate.split())
            if candidate and any(char.isalpha() for char in candidate):
                fallback_name = candidate
                break

        if not fallback_name:
            host = urlparse(input_url).netloc.replace('www.', '')
            fallback_name = f'Product from {host}'

        return SourceProduct(
            input_value=input_url,
            extracted_from_url=True,
            product_name=fallback_name,
            normalized_name=normalize_product_name(fallback_name),
            product_url=input_url,
            store_name=urlparse(input_url).netloc.replace('www.', ''),
        )

    def _can_search_from_source(self, source_product: SourceProduct | None, search_query: str) -> bool:
        if source_product is None:
            return bool(search_query.strip())
        if not source_product.extracted_from_url:
            return bool(search_query.strip())
        if source_product.price is not None:
            return True
        return self._has_meaningful_product_name(source_product.product_name)

    def _has_meaningful_product_name(self, value: str) -> bool:
        if value.startswith('Product from '):
            return False
        normalized = normalize_product_name(value)
        tokens = [token for token in normalized.split() if any(char.isalpha() for char in token)]
        if len(tokens) >= 2:
            return True
        if len(tokens) == 1 and any(char.isdigit() for char in tokens[0]):
            return True
        return False

    def _is_supported_marketplace_url(self, url: str) -> bool:
        host = urlparse(url).netloc.casefold().replace('www.', '')
        return any(
            domain in host
            for domain in (
                'kaspi.kz',
                'amazon.',
                'ebay.',
                'aliexpress.',
                'wildberries.',
                'ozon.',
            )
        )

    def _is_supported_product_page_url(self, url: str) -> bool:
        parsed = urlparse(url)
        host = parsed.netloc.casefold().replace('www.', '')
        path = parsed.path.casefold()

        if 'kaspi.kz' in host:
            return '/shop/p/' in path
        if 'amazon.' in host:
            return '/dp/' in path or '/gp/product/' in path
        if 'ebay.' in host:
            return '/itm/' in path
        if 'aliexpress.' in host:
            return '/item/' in path
        if 'wildberries.' in host:
            return '/catalog/' in path and '/detail.aspx' in path
        if 'ozon.' in host:
            return '/product/' in path
        return False

    def _collect_results(
        self,
        results: list[ScrapeResult],
        matched_query: str,
    ) -> tuple[list[MarketplaceOffer], list[MarketplaceFailure]]:
        offers: list[MarketplaceOffer] = []
        failures: list[MarketplaceFailure] = []

        for result in results:
            if result.error:
                failures.append(MarketplaceFailure(marketplace=result.marketplace, reason=result.error))
                continue

            for offer in result.offers:
                offers.append(
                    MarketplaceOffer(
                        marketplace=offer.marketplace,
                        title=offer.title,
                        normalized_title=offer.normalized_title,
                        price=offer.price,
                        currency=offer.currency,
                        price_text=offer.price_text,
                        product_url=offer.product_url,
                        image_url=offer.image_url,
                        in_stock=offer.in_stock,
                        extracted_at=datetime.now(timezone.utc),
                        similarity_score=offer.similarity_score,
                        matched_query=matched_query,
                        extraction_source=offer.extraction_source,
                    )
                )

        return self._dedupe_offers(offers), failures

    def _dedupe_offers(self, offers: list[MarketplaceOffer]) -> list[MarketplaceOffer]:
        sorted_offers = sorted(offers, key=lambda item: item.price)
        deduped: list[MarketplaceOffer] = []
        seen = set()
        for offer in sorted_offers:
            dedupe_key = (offer.marketplace, offer.product_url)
            if dedupe_key in seen:
                continue
            seen.add(dedupe_key)
            deduped.append(offer)
        return deduped

    def _source_offer(self, source_product: SourceProduct | None) -> MarketplaceOffer | None:
        if (
            source_product is None
            or source_product.price is None
            or source_product.product_url is None
        ):
            return None

        return MarketplaceOffer(
            marketplace=source_product.store_name or 'Source store',
            title=source_product.product_name,
            normalized_title=source_product.normalized_name,
            price=source_product.price,
            currency=source_product.currency,
            price_text=None,
            product_url=source_product.product_url,
            image_url=source_product.image_url,
            in_stock=None,
            extracted_at=datetime.now(timezone.utc),
            similarity_score=1.0,
            matched_query=source_product.product_name,
            extraction_source='product_page',
        )

    def _remove_source_marketplace_failures(
        self,
        failures: list[MarketplaceFailure],
        source_marketplace: str,
    ) -> list[MarketplaceFailure]:
        source_key = self._marketplace_key(source_marketplace)
        return [failure for failure in failures if self._marketplace_key(failure.marketplace) != source_key]

    def _marketplace_key(self, value: str) -> str:
        lowered = value.casefold()
        for known in ('amazon', 'ebay', 'aliexpress', 'kaspi', 'wildberries', 'ozon'):
            if known in lowered:
                return known
        return lowered

    def _recommend(
        self,
        source_product: SourceProduct | None,
        offers: list[MarketplaceOffer],
    ) -> str:
        if len(offers) <= 1:
            return 'wait'

        cheapest = min(offers, key=lambda offer: offer.price)
        if source_product and source_product.price is not None:
            if source_product.price <= cheapest.price * 1.02:
                return 'buy'
            return 'wait'

        prices = [offer.price for offer in offers]
        if len(prices) >= 3:
            market_median = median(prices)
            if cheapest.price <= market_median * 0.95:
                return 'buy'

        return 'wait'

    def _reason(
        self,
        source_product: SourceProduct | None,
        offers: list[MarketplaceOffer],
        cheapest: MarketplaceOffer | None,
        recommendation: str,
    ) -> str:
        if not offers or cheapest is None:
            return (
                'Not enough marketplaces returned verifiable live prices. '
                'Wait and try again later or use a more direct product page.'
            )

        if len(offers) == 1:
            return (
                f'Only {offers[0].marketplace} returned a verified live product price. '
                'Use a more direct product page or try again later for a broader comparison.'
            )

        if source_product and source_product.price is not None:
            delta = source_product.price - cheapest.price
            if delta <= 0:
                return (
                    f'The source store already matches or beats the cheapest verified live offer. '
                    f'Buying now is reasonable if shipping and seller quality also look good.'
                )
            return (
                f'The cheapest verified live offer is on {cheapest.marketplace}. '
                f'It is {delta:.2f} {cheapest.currency or ""} lower than the source price, '
                f'so waiting on the original store does not make sense right now.'
            ).strip()

        if recommendation == 'buy':
            return (
                f'{cheapest.marketplace} currently has the lowest verified live price among the checked marketplaces. '
                f'The spread is large enough to make buying now on that marketplace reasonable.'
            )

        return (
            f'{cheapest.marketplace} is the cheapest verified live option right now, '
            f'but the price gap across marketplaces is not wide enough to justify urgency yet.'
        )

    @property
    def ai(self) -> OpenAIChatService:
        return self._ai

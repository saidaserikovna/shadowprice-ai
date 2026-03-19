from __future__ import annotations

from .base import MarketplaceScraper, SearchCandidate


class AmazonScraper(MarketplaceScraper):
    name = 'Amazon'
    base_url = 'https://www.amazon.com'
    search_path = 'https://www.amazon.com/s?k={query}'
    prefers_browser = True

    def parse_candidates(self, html: str, final_url: str) -> list[SearchCandidate]:
        soup = self.soup(html)
        results: list[SearchCandidate] = []

        for card in soup.select('div.s-result-item[data-component-type="s-search-result"]'):
            title = self._text(
                card,
                [
                    '[data-cy="title-recipe"] a',
                    'a h2 span',
                    'h2 span',
                    '[role="heading"]',
                ],
            )
            url = self._attr(
                card,
                [
                    '[data-cy="title-recipe"] a',
                    'a[href*="/dp/"]',
                    'a.a-link-normal',
                ],
                'href',
            )
            price_text = self._text(
                card,
                [
                    '.a-price .a-offscreen',
                    '[data-cy="price-recipe"] .a-offscreen',
                    '[class*="price"] .a-offscreen',
                ],
            )
            image = self._attr(card, ['img.s-image'], 'src')
            if price_text is None:
                continue
            candidate = self._candidate(
                title=title,
                url=url,
                base_url=self.base_url,
                price_text=price_text,
                image_url=image,
            )
            if candidate:
                results.append(candidate)

        return results

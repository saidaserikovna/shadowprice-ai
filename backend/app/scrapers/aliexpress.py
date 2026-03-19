from __future__ import annotations

from .base import MarketplaceScraper, SearchCandidate


class AliExpressScraper(MarketplaceScraper):
    name = 'AliExpress'
    base_url = 'https://www.aliexpress.com'
    search_path = 'https://www.aliexpress.com/wholesale?SearchText={query}'
    prefers_browser = True

    def parse_candidates(self, html: str, final_url: str) -> list[SearchCandidate]:
        soup = self.soup(html)
        results: list[SearchCandidate] = []

        for link in soup.select('a[href*="/item/"]'):
            title = (
                link.get('title')
                or self._text(link, ['h1', 'h2', 'h3', 'span', 'div'])
                or link.get_text(' ', strip=True)
            )
            if not title or len(title) < 8:
                continue

            card = link
            for _ in range(3):
                if card.parent is None:
                    break
                card = card.parent

            price_text = self._text(
                card,
                [
                    '[class*="price-sale"]',
                    '[class*="price-current"]',
                    '[class*="price"]',
                ],
            )
            image = self._attr(card, ['img'], 'src') or self._attr(card, ['img'], 'data-src')
            candidate = self._candidate(
                title=title,
                url=link.get('href'),
                base_url=self.base_url,
                price_text=price_text,
                image_url=image,
            )
            if candidate:
                results.append(candidate)

        return results

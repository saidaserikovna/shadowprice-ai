from __future__ import annotations

from .base import MarketplaceScraper, SearchCandidate


class KaspiScraper(MarketplaceScraper):
    name = 'Kaspi.kz'
    base_url = 'https://kaspi.kz'
    search_path = 'https://kaspi.kz/shop/search/?text={query}'
    prefers_browser = True

    def parse_candidates(self, html: str, final_url: str) -> list[SearchCandidate]:
        soup = self.soup(html)
        results: list[SearchCandidate] = []

        for link in soup.select('a[href*="/shop/p/"]'):
            title = (
                self._text(link, ['.item-card__name', '[class*="item-card__name"]'])
                or link.get('title')
                or link.get_text(' ', strip=True)
            )
            if not title or len(title) < 6:
                continue

            card = link
            for _ in range(3):
                if card.parent is None:
                    break
                card = card.parent

            price_text = self._text(
                card,
                [
                    '.item-card__prices-price',
                    '[class*="item-card__prices-price"]',
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

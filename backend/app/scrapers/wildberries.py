from __future__ import annotations

from .base import MarketplaceScraper, SearchCandidate


class WildberriesScraper(MarketplaceScraper):
    name = 'Wildberries'
    base_url = 'https://www.wildberries.ru'
    search_path = 'https://www.wildberries.ru/catalog/0/search.aspx?search={query}'
    prefers_browser = True

    def parse_candidates(self, html: str, final_url: str) -> list[SearchCandidate]:
        soup = self.soup(html)
        results: list[SearchCandidate] = []

        for link in soup.select('a[href*="/catalog/"][href*="/detail.aspx"]'):
            title = (
                self._text(link, ['.product-card__name', '[class*="product-card__name"]'])
                or link.get('aria-label')
                or link.get_text(' ', strip=True)
            )
            if not title or len(title) < 6:
                continue

            card = link
            for _ in range(4):
                if card.parent is None:
                    break
                card = card.parent

            price_text = self._text(
                card,
                [
                    '.price__lower-price',
                    '[class*="lower-price"]',
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

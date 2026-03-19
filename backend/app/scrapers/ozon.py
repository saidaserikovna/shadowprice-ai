from __future__ import annotations

from .base import MarketplaceScraper, SearchCandidate


class OzonScraper(MarketplaceScraper):
    name = 'Ozon'
    base_url = 'https://www.ozon.ru'
    search_path = 'https://www.ozon.ru/search/?text={query}'
    prefers_browser = True

    def parse_candidates(self, html: str, final_url: str) -> list[SearchCandidate]:
        soup = self.soup(html)
        results: list[SearchCandidate] = []

        for link in soup.select('a[href*="/product/"]'):
            title = (
                link.get('title')
                or link.get('aria-label')
                or self._text(link, ['span', 'div'])
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
                    '[class*="tsHeadline"]',
                    '[class*="price"]',
                    'span',
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

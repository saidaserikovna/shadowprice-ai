from __future__ import annotations

from .base import MarketplaceScraper, SearchCandidate


class EbayScraper(MarketplaceScraper):
    name = 'eBay'
    base_url = 'https://www.ebay.com'
    search_path = 'https://www.ebay.com/sch/i.html?_nkw={query}'
    prefers_browser = True

    def parse_candidates(self, html: str, final_url: str) -> list[SearchCandidate]:
        soup = self.soup(html)
        results: list[SearchCandidate] = []

        for card in soup.select('li.s-item, .srp-results .s-item'):
            title = self._text(card, ['.s-item__title'])
            url = self._attr(card, ['a.s-item__link'], 'href')
            price_text = self._text(card, ['.s-item__price'])
            image = self._attr(card, ['img.s-item__image-img'], 'src')
            if title and 'shop on ebay' in title.casefold():
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

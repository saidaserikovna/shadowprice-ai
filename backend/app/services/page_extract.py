from __future__ import annotations

import json
import re
from dataclasses import dataclass
from html import unescape
from typing import Any, Iterable, Optional
from urllib.parse import urljoin, urlparse

from bs4 import BeautifulSoup, Tag


BOT_BLOCK_KEYWORDS = (
    'captcha',
    'verify you are human',
    'access denied',
    'access to this page has been denied',
    'robot check',
    'security challenge',
    'unusual traffic',
    'anti-bot',
    'доступ ограничен',
    'почти готово',
)


@dataclass
class ProductSnapshot:
    title: str
    price: float
    currency: str | None
    product_url: str
    image_url: str | None
    store_name: str
    in_stock: bool | None
    extraction_source: str


@dataclass
class ProductHint:
    title: str
    product_url: str
    image_url: str | None
    store_name: str


def detect_bot_block(html: str) -> bool:
    lowered = html.casefold()
    return any(keyword in lowered for keyword in BOT_BLOCK_KEYWORDS)


def parse_price_text(value: str | None) -> tuple[float | None, str | None]:
    if not value:
        return None, None

    text = unescape(value).strip()
    currency = extract_currency(text)

    cleaned = re.sub(r'[^\d,.\-]', '', text)
    if not cleaned:
        return None, currency

    if ',' in cleaned and '.' in cleaned:
        if cleaned.rfind(',') > cleaned.rfind('.'):
            cleaned = cleaned.replace('.', '').replace(',', '.')
        else:
            cleaned = cleaned.replace(',', '')
    elif ',' in cleaned:
        parts = cleaned.split(',')
        if len(parts) > 1 and len(parts[-1]) <= 2:
            cleaned = ''.join(parts[:-1]) + '.' + parts[-1]
        else:
            cleaned = cleaned.replace(',', '')
    elif re.match(r'^\d{1,3}(\.\d{3})+$', cleaned):
        cleaned = cleaned.replace('.', '')

    try:
        return float(cleaned), currency
    except ValueError:
        return None, currency


def extract_currency(value: str | None) -> str | None:
    if not value:
        return None

    text = value.upper()
    if '$' in value:
        return 'USD'
    if '€' in value:
        return 'EUR'
    if '£' in value:
        return 'GBP'
    if '₸' in value or 'KZT' in text:
        return 'KZT'
    if '₽' in value or 'RUB' in text:
        return 'RUB'
    if '¥' in value or 'JPY' in text or 'CNY' in text:
        return 'CNY'
    return text if len(text.strip()) == 3 else None


def extract_product_snapshot(html: str, base_url: str, store_hint: str | None = None) -> ProductSnapshot | None:
    soup = BeautifulSoup(html, 'lxml')
    product_node = _find_product_node(_extract_json_ld(soup))
    hint = _extract_product_hint_from_soup(
        soup,
        product_node,
        base_url,
        store_hint,
    )

    price, currency, in_stock = _extract_offer_details(soup, product_node)
    if hint and price is not None:
        return ProductSnapshot(
            title=hint.title,
            price=price,
            currency=currency,
            product_url=hint.product_url,
            image_url=hint.image_url,
            store_name=hint.store_name,
            in_stock=in_stock,
            extraction_source='product_page',
        )

    return None


def extract_product_hint(html: str, base_url: str, store_hint: str | None = None) -> ProductHint | None:
    soup = BeautifulSoup(html, 'lxml')
    product_node = _find_product_node(_extract_json_ld(soup))
    return _extract_product_hint_from_soup(
        soup,
        product_node,
        base_url,
        store_hint,
    )


def _extract_json_ld(soup: BeautifulSoup) -> list[Any]:
    blocks: list[Any] = []
    for script in soup.select('script[type="application/ld+json"]'):
        raw = script.get_text(strip=True)
        if not raw:
            continue
        try:
            blocks.append(json.loads(raw))
        except json.JSONDecodeError:
            continue
    return blocks


def _find_product_node(value: Any) -> dict[str, Any] | None:
    if isinstance(value, list):
        for item in value:
            found = _find_product_node(item)
            if found:
                return found
        return None

    if isinstance(value, dict):
        normalized = {str(key): item for key, item in value.items()}
        type_value = normalized.get('@type')
        types = set()
        if isinstance(type_value, str):
            types.add(type_value.casefold())
        elif isinstance(type_value, list):
            types |= {str(item).casefold() for item in type_value}

        if 'product' in types or ('name' in normalized and 'offers' in normalized):
            return normalized

        for nested in normalized.values():
            found = _find_product_node(nested)
            if found:
                return found
    return None


def _extract_offer_details(
    soup: BeautifulSoup,
    product_node: dict[str, Any] | None,
) -> tuple[float | None, str | None, bool | None]:
    offers = product_node.get('offers') if product_node else None
    offer = _first_offer(offers)

    offer_price = _string_value(offer.get('price') if offer else None)
    offer_low_price = _string_value(offer.get('lowPrice') if offer else None)
    product_price = _string_value(product_node.get('price') if product_node else None)

    for candidate in (
        offer_price,
        offer_low_price,
        product_price,
        _meta_content(soup, 'meta[property="product:price:amount"]'),
        _meta_content(soup, 'meta[property="og:price:amount"]'),
        _meta_content(soup, 'meta[itemprop="price"]'),
    ):
        price, parsed_currency = parse_price_text(candidate)
        if price is not None:
            currency = (
                _string_value(offer.get('priceCurrency') if offer else None)
                or _string_value(product_node.get('priceCurrency') if product_node else None)
                or _meta_content(soup, 'meta[property="product:price:currency"]')
                or _meta_content(soup, 'meta[itemprop="priceCurrency"]')
                or parsed_currency
            )
            availability = _string_value(offer.get('availability') if offer else None)
            in_stock = None
            if availability:
                availability_lower = availability.casefold()
                if 'instock' in availability_lower:
                    in_stock = True
                elif 'outofstock' in availability_lower:
                    in_stock = False
            return price, extract_currency(currency), in_stock

    common_price_selectors = [
        '[itemprop="price"]',
        '.a-price .a-offscreen',
        '[data-price]',
        '[class*="price"]',
    ]

    for selector in common_price_selectors:
        for node in soup.select(selector):
            content = node.get('content') or node.get_text(' ', strip=True)
            price, currency = parse_price_text(content)
            if price is not None:
                return price, currency, None

    return None, None, None


def _extract_product_hint_from_soup(
    soup: BeautifulSoup,
    product_node: dict[str, Any] | None,
    base_url: str,
    store_hint: str | None,
) -> ProductHint | None:
    title = _first_non_empty(
        _string_value(product_node.get('name') if product_node else None),
        soup.select_one('h1').get_text(' ', strip=True) if soup.select_one('h1') else None,
        _meta_content(soup, 'meta[property="og:title"]'),
        _meta_content(soup, 'meta[name="twitter:title"]'),
        _meta_content(soup, 'meta[itemprop="name"]'),
        soup.title.text.strip() if soup.title else None,
    )
    if not title:
        return None

    canonical_url = _canonical_url(soup, base_url)
    return ProductHint(
        title=_clean_title(title),
        product_url=canonical_url,
        image_url=_extract_image_url(soup, product_node, canonical_url),
        store_name=_extract_store_name(soup, product_node, store_hint, canonical_url),
    )


def _first_offer(value: Any) -> dict[str, Any] | None:
    if isinstance(value, list):
        for item in value:
            offer = _first_offer(item)
            if offer:
                return offer
        return None

    if isinstance(value, dict):
        return {str(key): item for key, item in value.items()}
    return None


def _extract_store_name(
    soup: BeautifulSoup,
    product_node: dict[str, Any] | None,
    store_hint: str | None,
    canonical_url: str,
) -> str:
    offer = _first_offer(product_node.get('offers') if product_node else None)
    seller = offer.get('seller') if offer else None
    seller_name = None
    if isinstance(seller, dict):
        seller_name = _string_value(seller.get('name'))

    brand = product_node.get('brand') if product_node else None
    brand_name = _string_value(brand.get('name')) if isinstance(brand, dict) else _string_value(brand)

    return _first_non_empty(
        seller_name,
        _meta_content(soup, 'meta[property="og:site_name"]'),
        store_hint,
        brand_name,
        _store_from_host(canonical_url),
    ) or 'Unknown store'


def _extract_image_url(
    soup: BeautifulSoup,
    product_node: dict[str, Any] | None,
    canonical_url: str,
) -> str | None:
    image = product_node.get('image') if product_node else None
    if isinstance(image, list) and image:
        image = image[0]

    candidate = _first_non_empty(
        _string_value(image),
        _meta_content(soup, 'meta[property="og:image"]'),
        _meta_content(soup, 'meta[name="twitter:image"]'),
    )
    if not candidate:
        return None
    return urljoin(canonical_url, candidate)


def _canonical_url(soup: BeautifulSoup, base_url: str) -> str:
    href = soup.select_one('link[rel="canonical"]')
    if href and href.get('href'):
        return urljoin(base_url, href['href'])
    return base_url


def _store_from_host(url: str) -> str:
    host = urlparse(url).netloc.replace('www.', '')
    first = host.split('.')[0]
    return first[:1].upper() + first[1:] if first else host


def _string_value(value: Any) -> str | None:
    if value is None:
        return None
    if isinstance(value, str):
        return value.strip() or None
    return str(value).strip() or None


def _meta_content(soup: BeautifulSoup, selector: str) -> str | None:
    node = soup.select_one(selector)
    if isinstance(node, Tag):
        content = node.get('content')
        return content.strip() if content else None
    return None


def _first_non_empty(*values: Optional[str]) -> str | None:
    for value in values:
        if value and value.strip():
            return value.strip()
    return None


def _clean_title(value: str) -> str:
    cleaned = re.sub(r'\s+', ' ', value).strip()
    cleaned = re.sub(r'^[A-Za-z0-9.-]+\s*:\s*', '', cleaned)
    cleaned = re.sub(r'\s*:\s*Electronics\s*$', '', cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(
        r'\s*\|\s*(Amazon(?:\.com)?|AliExpress|eBay|Kaspi(?: Магазин)?|Ozon|Wildberries)\s*$',
        '',
        cleaned,
        flags=re.IGNORECASE,
    )
    return cleaned.strip()

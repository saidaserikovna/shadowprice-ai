from __future__ import annotations

import re
from difflib import SequenceMatcher


_STOP_WORDS = {
    'buy',
    'shop',
    'store',
    'sale',
    'price',
    'official',
    'original',
    'amazon',
    'ebay',
    'aliexpress',
    'kaspi',
    'wildberries',
    'ozon',
    'electronics',
    'electronic',
    'shop',
    'com',
}

_ORDINAL_MAP = {
    '1st': '1',
    'first': '1',
    '2nd': '2',
    'second': '2',
    '3rd': '3',
    'third': '3',
    '4th': '4',
    'fourth': '4',
    '5th': '5',
    'fifth': '5',
}

_MODEL_TOKENS = {
    'pro',
    'max',
    'plus',
    'ultra',
    'mini',
    'lite',
    'se',
    'fe',
}

_ACCESSORY_TOKENS = {
    'case',
    'cover',
    'ear',
    'earbud',
    'earbuds',
    'earphone',
    'earphones',
    'earhook',
    'earhooks',
    'eartip',
    'eartips',
    'hook',
    'hooks',
    'pen',
    'protector',
    'replacement',
    'single',
    'skin',
    'sleeve',
    'strap',
    'straps',
    'tips',
}

_REFURBISHED_TOKENS = {
    'renewed',
    'refurbished',
    'used',
    'open',
    'box',
}


def _tokenize(value: str) -> list[str]:
    tokens = []
    for token in value.split():
        token = _ORDINAL_MAP.get(token, token)
        if token == 'generation':
            continue
        tokens.append(token)
    return tokens


def normalize_product_name(value: str) -> str:
    lowered = value.casefold()
    cleaned = re.sub(r'https?://\S+', ' ', lowered)
    cleaned = re.sub(r'[_|/\\\-]+', ' ', cleaned)
    cleaned = re.sub(r'[^\w\s]+', ' ', cleaned, flags=re.UNICODE)
    tokens = [token for token in _tokenize(cleaned) if token and token not in _STOP_WORDS]
    return ' '.join(tokens)


def similarity_score(target: str, candidate: str) -> float:
    normalized_target = normalize_product_name(target)
    normalized_candidate = normalize_product_name(candidate)

    if not normalized_target or not normalized_candidate:
        return 0.0

    target_tokens = set(normalized_target.split())
    candidate_tokens = set(normalized_candidate.split())

    token_overlap = len(target_tokens & candidate_tokens) / max(len(target_tokens), 1)
    sequence = SequenceMatcher(None, normalized_target, normalized_candidate).ratio()
    score = (token_overlap * 0.65) + (sequence * 0.35)

    target_models = target_tokens & _MODEL_TOKENS
    candidate_models = candidate_tokens & _MODEL_TOKENS
    if target_models and not target_models <= candidate_tokens:
        score -= 0.18
    if candidate_models and target_models and candidate_models != target_models:
        score -= 0.12

    target_numbers = {token for token in target_tokens if token.isdigit()}
    candidate_numbers = {token for token in candidate_tokens if token.isdigit()}
    if target_numbers and candidate_numbers and target_numbers.isdisjoint(candidate_numbers):
        score -= 0.2

    missing_tokens = target_tokens - candidate_tokens
    if missing_tokens:
        score -= min(0.2, 0.06 * len(missing_tokens))

    if (candidate_tokens & _ACCESSORY_TOKENS) and not (target_tokens & _ACCESSORY_TOKENS):
        score -= 0.28

    if (candidate_tokens & _REFURBISHED_TOKENS) and not (target_tokens & _REFURBISHED_TOKENS):
        score -= 0.14

    return round(max(0.0, min(1.0, score)), 4)


def looks_like_url(value: str) -> bool:
    return bool(re.match(r'^https?://', value.strip(), flags=re.IGNORECASE))

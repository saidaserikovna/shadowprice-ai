# ShadowPrice AI Backend

Real-time multi-marketplace comparison backend for the Flutter app.

## Features

- Accepts a product URL or product name
- Extracts real product data from the source page when a URL is provided
- Searches Kaspi, Amazon, eBay, AliExpress, Wildberries, and Ozon in parallel
- Returns only live extracted prices and links
- Provides a grounded buy/wait recommendation
- Supports an AI chat endpoint that only answers from real extracted data

## Setup

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
playwright install chromium
cp .env.example .env
uvicorn app.main:app --reload
```

By default the Flutter app expects the backend on `http://10.0.2.2:8000` for Android emulators.

## Online Deploy

This repo is prepared for a Docker-based Render deploy:

1. Push this project to GitHub.
2. Sign in to Render and create a new Blueprint or Web Service from the repo.
3. Use the root-level [`render.yaml`](../render.yaml) file.
4. After Render gives you a public URL like `https://shadowprice-ai-backend.onrender.com`, open the mobile app and set that URL in `Settings -> Backend Connection`.

The backend exposes a health check at `/healthz`.

## Environment

- `OPENAI_API_KEY`: enables the AI chat endpoint
- `SHADOWPRICE_OPENAI_MODEL`: defaults to `gpt-5.4-mini`
- `SHADOWPRICE_BROWSER_ENABLED`: enables Playwright fallback
- `SHADOWPRICE_BROWSER_HEADLESS`: controls browser mode

## Notes

- Marketplace HTML changes over time, so scraper selectors are isolated per marketplace.
- The backend never fabricates prices. If a marketplace cannot be verified, it is returned as a failure instead of an estimate.
- If Playwright browsers are not installed yet, the API still starts and falls back to direct HTTP requests. Protected marketplaces may return fewer results until `playwright install chromium` is run.

from __future__ import annotations

import asyncio
from dataclasses import dataclass

from ..config import Settings

try:
    from playwright.async_api import Browser, Error as PlaywrightError, async_playwright
except Exception:  # pragma: no cover - optional dependency import guard
    Browser = None  # type: ignore[assignment]
    PlaywrightError = Exception  # type: ignore[assignment]
    async_playwright = None  # type: ignore[assignment]


@dataclass
class BrowserFetchResult:
    html: str
    final_url: str


class BrowserManager:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._playwright = None
        self._browser: Browser | None = None
        self._lock = asyncio.Lock()
        self._startup_error: str | None = None

    @property
    def enabled(self) -> bool:
        return (
            self._settings.browser_enabled
            and async_playwright is not None
            and self._startup_error is None
        )

    @property
    def startup_error(self) -> str | None:
        return self._startup_error

    async def startup(self) -> None:
        if not self.enabled:
            return

        async with self._lock:
            if self._browser is not None:
                return
            try:
                self._playwright = await async_playwright().start()
                self._browser = await self._playwright.chromium.launch(
                    headless=self._settings.browser_headless,
                )
            except Exception as error:  # pragma: no cover - depends on host browser install
                self._startup_error = str(error)
                if self._playwright is not None:
                    await self._playwright.stop()
                    self._playwright = None
                self._browser = None

    async def shutdown(self) -> None:
        async with self._lock:
            if self._browser is not None:
                try:
                    await self._browser.close()
                except Exception:
                    pass
                self._browser = None
            if self._playwright is not None:
                try:
                    await self._playwright.stop()
                except Exception:
                    pass
                self._playwright = None

    async def fetch(self, url: str, wait_until: str = 'domcontentloaded') -> BrowserFetchResult:
        if not self.enabled:
            reason = self._startup_error or 'Browser fallback is disabled.'
            raise RuntimeError(reason)

        await self.startup()
        if self._browser is None:
            raise RuntimeError('Browser is not available.')

        context = await self._browser.new_context(
            user_agent=self._settings.user_agent,
            locale='en-US',
        )
        page = await context.new_page()
        try:
            response = await page.goto(
                url,
                wait_until=wait_until,
                timeout=int(self._settings.request_timeout * 1000),
            )
            if response is None:
                raise RuntimeError(f'No browser response while opening {url}')
            await page.wait_for_timeout(1200)
            return BrowserFetchResult(html=await page.content(), final_url=page.url)
        except PlaywrightError as error:
            raise RuntimeError(str(error)) from error
        finally:
            await context.close()

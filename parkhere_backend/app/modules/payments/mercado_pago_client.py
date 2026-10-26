"""Small Mercado Pago HTTP adapter.

The adapter deliberately has no SDK dependency.  It is only used when
PAYMENT_PROVIDER=mercado_pago and an access token is configured; homologation
continues to use the local mock provider.
"""
import asyncio
import json
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

from app.core.config import settings


class MercadoPagoError(RuntimeError):
    pass


class MercadoPagoClient:
    def __init__(self, access_token: str | None = None):
        self.access_token = access_token or settings.MERCADO_PAGO_ACCESS_TOKEN
        if not self.access_token:
            raise MercadoPagoError("MERCADO_PAGO_ACCESS_TOKEN não configurado")

    async def create_preference(self, payload: dict) -> dict:
        return await asyncio.to_thread(self._request, "POST", "/checkout/preferences", payload)

    async def create_order(self, payload: dict, idempotency_key: str) -> dict:
        """Create a Checkout Transparente order without handling card data here.

        Card number and CVV must be tokenized by the Mercado Pago mobile/web SDK;
        this adapter only receives the order result and never stores PAN/CVV.
        """
        return await asyncio.to_thread(
            self._request,
            "POST",
            "/v1/orders",
            payload,
            {"X-Idempotency-Key": idempotency_key},
        )

    async def get_order(self, order_id: str) -> dict:
        return await asyncio.to_thread(self._request, "GET", f"/v1/orders/{order_id}")

    async def get_payment(self, payment_id: str) -> dict:
        return await asyncio.to_thread(self._request, "GET", f"/v1/payments/{payment_id}")

    def _request(
        self,
        method: str,
        path: str,
        payload: dict | None = None,
        extra_headers: dict[str, str] | None = None,
    ) -> dict:
        body = json.dumps(payload).encode() if payload is not None else None
        headers = {
            "Authorization": f"Bearer {self.access_token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        }
        headers.update(extra_headers or {})
        request = Request(
            f"{settings.MERCADO_PAGO_API_BASE_URL.rstrip('/')}{path}",
            data=body,
            method=method,
            headers=headers,
        )
        try:
            with urlopen(request, timeout=15) as response:
                return json.loads(response.read().decode() or "{}")
        except (HTTPError, URLError, TimeoutError, ValueError) as exc:
            raise MercadoPagoError(f"Falha na comunicação com Mercado Pago: {exc}") from exc

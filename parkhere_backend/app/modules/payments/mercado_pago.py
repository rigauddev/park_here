"""Transport for the first Mercado Pago integration stage.

Not enabled by the payment routes until reconciliation and partner OAuth exist.
Credentials stay server-side; callers persist and reuse the idempotency key.
"""

import asyncio
import json
import math
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


class MercadoPagoError(Exception):
    """Sanitized provider error, without credentials or payer data."""


class MercadoPagoClient:
    def __init__(self, access_token: str, timeout: float = 15):
        if not access_token:
            raise ValueError("Mercado Pago access token is required")
        self.access_token = access_token
        self.timeout = timeout

    async def create_pix(
        self, *, amount: float, payer_email: str,
        external_reference: str, idempotency_key: str,
    ) -> dict:
        if not math.isfinite(amount) or round(amount, 2) <= 0:
            raise ValueError("Payment amount must be finite and positive")
        if not payer_email or not external_reference or not idempotency_key:
            raise ValueError("Payer, reference and idempotency key are required")
        return await asyncio.to_thread(
            self._request, "POST", "/v1/payments",
            {
                "transaction_amount": round(amount, 2),
                "payment_method_id": "pix",
                "payer": {"email": payer_email},
                "external_reference": external_reference,
            },
            idempotency_key,
        )

    async def get_payment(self, payment_id: str) -> dict:
        if not payment_id.isascii() or not payment_id.isdecimal():
            raise ValueError("Invalid provider payment ID")
        return await asyncio.to_thread(
            self._request, "GET", f"/v1/payments/{payment_id}", None, None,
        )

    def _request(self, method, path, payload, idempotency_key):
        headers = {
            "Authorization": f"Bearer {self.access_token}",
            "Content-Type": "application/json",
        }
        if idempotency_key:
            headers["X-Idempotency-Key"] = idempotency_key
        request = Request(
            f"https://api.mercadopago.com{path}",
            data=json.dumps(payload).encode() if payload is not None else None,
            headers=headers, method=method,
        )
        try:
            with urlopen(request, timeout=self.timeout) as response:
                result = json.load(response)
                if not isinstance(result, dict) or "id" not in result:
                    raise MercadoPagoError("Invalid Mercado Pago response")
                return result
        except HTTPError as error:
            raise MercadoPagoError(f"Mercado Pago returned HTTP {error.code}") from None
        except (URLError, TimeoutError, OSError):
            raise MercadoPagoError("Mercado Pago unavailable; reconcile before retrying") from None
        except (ValueError, UnicodeError):
            raise MercadoPagoError("Invalid Mercado Pago response") from None

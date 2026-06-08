"""Paymob Accept integration — mirrors Easy Shope platform subscription flow."""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
from typing import Any
from urllib.parse import urlencode

import requests
from fastapi import HTTPException, status

from app.settings import settings

PAYMOB_INTENTION_URL = "https://accept.paymob.com/v1/intention/"


def _encryption_key() -> bytes:
    return hashlib.sha256(settings.jwt_secret.encode("utf-8")).digest()


def encode_secret(value: dict[str, Any]) -> str:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM

    key = _encryption_key()
    iv = hashlib.sha256(settings.jwt_secret.encode() + b"iv").digest()[:12]
    aes = AESGCM(key)
    plaintext = json.dumps(value, ensure_ascii=False).encode("utf-8")
    encrypted = aes.encrypt(iv, plaintext, None)
    return "v1:" + base64.urlsafe_b64encode(iv + encrypted).decode("ascii")


def decode_secret(value: str) -> dict[str, Any]:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM

    if value.startswith("v1:"):
        raw = base64.urlsafe_b64decode(value[3:].encode("ascii"))
        iv, encrypted = raw[:12], raw[12:]
        aes = AESGCM(_encryption_key())
        plaintext = aes.decrypt(iv, encrypted, None)
        return json.loads(plaintext.decode("utf-8"))
    return json.loads(base64.b64decode(value).decode("utf-8"))


def paymob_checkout_url(public_key: str, client_secret: str) -> str:
    params = urlencode({"publicKey": public_key, "clientSecret": client_secret})
    return f"https://accept.paymob.com/unifiedcheckout/?{params}"


def is_likely_paymob_public_key(value: str | None) -> bool:
    key = str(value or "").strip()
    if not key:
        return False
    return bool(
        __import__("re").search(r"(^|_)pk(_|l_|t_|test_|live_)", key, __import__("re").I)
        or key.lower().startswith(("pkt_", "pkl_"))
    )


def assert_paymob_public_key(public_key: str | None) -> None:
    if not is_likely_paymob_public_key(public_key):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Paymob Public Key غير صحيح. من Paymob > Developers > API Keys انسخ Public Key "
                "(يبدأ غالبًا بـ pk أو egy_pk) وليس API Token أو Secret."
            ),
        )


def paymob_error_message(payload: Any) -> str:
    if not payload or not isinstance(payload, dict):
        return "Paymob rejected the payment request"
    direct = payload.get("message") or payload.get("detail") or payload.get("error")
    if isinstance(direct, str):
        return direct
    parts: list[str] = []
    for key, val in payload.items():
        if isinstance(val, list):
            parts.append(f"{key}: {', '.join(str(v) for v in val)}")
        elif isinstance(val, str):
            parts.append(f"{key}: {val}")
        elif isinstance(val, dict):
            parts.append(f"{key}: {paymob_error_message(val)}")
    return " | ".join(parts) or "Paymob rejected the payment request"


def _paymob_field(obj: dict[str, Any], path: str) -> Any:
    if path == "order.id" and obj.get("order") is not None and not isinstance(obj.get("order"), dict):
        return obj.get("order")
    current: Any = obj
    for key in path.split("."):
        if not isinstance(current, dict):
            return None
        current = current.get(key)
    return current


def paymob_hmac_matches(obj: dict[str, Any], hmac_secret: str, received_hmac: str) -> bool:
    if not hmac_secret:
        return True
    if not received_hmac:
        return False
    fields = [
        "amount_cents",
        "created_at",
        "currency",
        "error_occured",
        "has_parent_transaction",
        "id",
        "integration_id",
        "is_3d_secure",
        "is_auth",
        "is_capture",
        "is_refunded",
        "is_standalone_payment",
        "is_voided",
        "order.id",
        "owner",
        "pending",
        "source_data.pan",
        "source_data.sub_type",
        "source_data.type",
        "success",
    ]
    message = "".join(str(_paymob_field(obj, f) or "") for f in fields)
    expected = hmac.new(hmac_secret.encode("utf-8"), message.encode("utf-8"), hashlib.sha512).hexdigest()
    received = received_hmac.lower()
    if len(expected) != len(received):
        return False
    return hmac.compare_digest(expected, received)


def parse_subscription_payment_reference(reference: str) -> int | None:
    if not reference.startswith("subscription_payment:"):
        return None
    parts = reference.split(":")
    if len(parts) < 2:
        return None
    try:
        return int(parts[1])
    except ValueError:
        return None


def paymob_transaction_state(obj: dict[str, Any]) -> dict[str, Any]:
    success = obj.get("success") is True or obj.get("success") == "true"
    pending = obj.get("pending") is True or obj.get("pending") == "true"
    tx_id = str(obj.get("id") or obj.get("transaction_id") or "")
    return {"success": success, "pending": pending, "transaction_id": tx_id}


def split_name(value: str) -> tuple[str, str]:
    parts = [p for p in value.strip().split() if p]
    if not parts:
        return "Office", "Owner"
    return parts[0], " ".join(parts[1:]) or "Owner"


def create_paymob_intention(
    *,
    secret_key: str,
    public_config: dict[str, Any],
    amount_cents: int,
    item_name: str,
    item_description: str,
    billing: dict[str, str],
    special_reference: str,
    notification_url: str,
    redirection_url: str,
) -> dict[str, Any]:
    card_id = int(public_config.get("cardIntegrationId") or 0)
    if card_id <= 0:
        raise HTTPException(status_code=400, detail="Card Integration ID is not configured")
    currency = str(public_config.get("currency") or "EGP").upper()
    payload = {
        "amount": amount_cents,
        "currency": currency,
        "payment_methods": [card_id],
        "items": [
            {
                "name": item_name[:50],
                "amount": amount_cents,
                "description": item_description[:200],
                "quantity": 1,
            }
        ],
        "billing_data": {
            "first_name": billing.get("first_name", "Office"),
            "last_name": billing.get("last_name", "Owner"),
            "phone_number": billing.get("phone", "01000000000"),
            "email": billing.get("email", "office@example.com"),
            "country": "EG",
            "city": "Cairo",
            "street": "NA",
            "building": "NA",
            "apartment": "NA",
            "floor": "NA",
        },
        "special_reference": special_reference,
        "notification_url": notification_url,
        "redirection_url": redirection_url,
        "expiration": 3600,
    }
    response = requests.post(
        PAYMOB_INTENTION_URL,
        headers={"Authorization": f"Token {secret_key}", "Content-Type": "application/json"},
        json=payload,
        timeout=30,
    )
    data = response.json() if response.content else {}
    if not response.ok or not data.get("client_secret"):
        raise HTTPException(status_code=400, detail=paymob_error_message(data))
    return data

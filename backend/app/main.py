from __future__ import annotations

import base64
import binascii
import json
from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal
from functools import lru_cache
import re
from typing import Any, Literal
from uuid import uuid4

import httpx
from fastapi import Depends, FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, ConfigDict, Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class _JsonEncoder(json.JSONEncoder):
    """JSON encoder that understands Decimal (Postgres numeric columns)."""

    def default(self, o: Any) -> Any:
        if isinstance(o, Decimal):
            return float(o)
        return super().default(o)


class Settings(BaseSettings):
    supabase_url: str = "https://ceqxnujtapdkhomhiiby.supabase.co"
    supabase_anon_key: str = "sb_publishable_ze1rjVQKXci6LgelzDG1oA_ydGUBSF1"
    supabase_service_role_key: str = ""
    cors_origins: str = "http://localhost:3000,http://localhost:8080"
    auth_redirect_url: str = "http://192.168.8.101:8000/auth/confirmed"
    auth_recovery_redirect_url: str = "http://192.168.8.101:8000/auth/recovery"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    @property
    def origins(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()


# Short-lived caches so repeated authenticated calls don't re-verify the JWT
# and re-fetch the shop row from Supabase on every request.
_user_cache: dict[str, dict[str, Any]] = {}
_shop_cache: dict[str, dict[str, Any]] = {}


SHOP_CONTACT_FIELDS = (
    "contact_email",
    "facebook",
    "instagram",
    "tiktok",
    "whatsapp",
    "calls",
)


class ShopRegistration(BaseModel):
    shop_name: str = Field(min_length=1, max_length=160)
    owner_name: str = Field(min_length=1, max_length=160)
    email: str
    password: str = Field(min_length=8, max_length=128)
    phone: str = Field(default="", max_length=40)
    location: str = Field(min_length=1, max_length=160)
    business_type: str = Field(min_length=1, max_length=100)
    contact_email: str = Field(default="", max_length=254)
    facebook: str = Field(default="", max_length=120)
    instagram: str = Field(default="", max_length=120)
    tiktok: str = Field(default="", max_length=120)
    whatsapp: str = Field(default="", max_length=120)
    calls: str = Field(default="", max_length=120)

    @field_validator("email")
    @classmethod
    def validate_email(cls, value: str) -> str:
        normalized = value.strip().lower()
        if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", normalized):
            raise ValueError("Enter a valid email address.")
        return normalized


class LoginRequest(BaseModel):
    email: str
    password: str = Field(min_length=1, max_length=128)

    @field_validator("email")
    @classmethod
    def validate_email(cls, value: str) -> str:
        normalized = value.strip().lower()
        if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", normalized):
            raise ValueError("Enter a valid email address.")
        return normalized


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=1)


class PasswordResetRequest(BaseModel):
    email: str

    @field_validator("email")
    @classmethod
    def validate_email(cls, value: str) -> str:
        normalized = value.strip().lower()
        if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", normalized):
            raise ValueError("Enter a valid email address.")
        return normalized


class PasswordUpdate(BaseModel):
    password: str = Field(min_length=8, max_length=128)


class ProductCreate(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    category: str = Field(min_length=1, max_length=100)
    sub_category: str = Field(default="", max_length=100)
    sku: str = Field(min_length=1, max_length=80)
    size: str = Field(default="", max_length=40)
    color: str = Field(default="", max_length=80)
    cost: Decimal = Field(ge=0, max_digits=12, decimal_places=2)
    price: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    quantity: int = Field(ge=0)
    supplier_name: str = Field(default="", max_length=160)


class ProductUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str | None = Field(default=None, min_length=1, max_length=160)
    category: str | None = Field(default=None, min_length=1, max_length=100)
    sub_category: str | None = Field(default=None, max_length=100)
    sku: str | None = Field(default=None, min_length=1, max_length=80)
    size: str | None = Field(default=None, max_length=40)
    color: str | None = Field(default=None, max_length=80)
    cost: Decimal | None = Field(default=None, ge=0, max_digits=12, decimal_places=2)
    price: Decimal | None = Field(default=None, gt=0, max_digits=12, decimal_places=2)
    quantity: int | None = Field(default=None, ge=0)
    supplier_name: str | None = Field(default=None, max_length=160)


class ProductImageUpload(BaseModel):
    content_type: Literal["image/jpeg", "image/png", "image/webp"]
    image_base64: str = Field(min_length=1, max_length=7_000_000)


class SupplierCreate(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    contact_name: str = Field(default="", max_length=160)
    phone: str = Field(default="", max_length=40)
    email: str = Field(default="", max_length=254)
    address: str = Field(default="", max_length=240)
    notes: str = Field(default="", max_length=1000)


class SupplierUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str | None = Field(default=None, min_length=1, max_length=160)
    contact_name: str | None = Field(default=None, max_length=160)
    phone: str | None = Field(default=None, max_length=40)
    email: str | None = Field(default=None, max_length=254)
    address: str | None = Field(default=None, max_length=240)
    notes: str | None = Field(default=None, max_length=1000)


class SaleItem(BaseModel):
    product_id: str
    quantity: int = Field(gt=0)
    size: str | None = None
    color: str | None = None


SALE_TYPES = ("Online", "Walk-in")


class ExpenseCreate(BaseModel):
    category: str = Field(min_length=1, max_length=80)
    amount: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    note: str = Field(default="", max_length=240)
    payment_method: str = Field(default="Cash Drawer", max_length=80)
    spent_on: date | None = None


class ExpenseUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    category: str | None = Field(default=None, min_length=1, max_length=80)
    amount: Decimal | None = Field(default=None, gt=0, max_digits=12, decimal_places=2)
    note: str | None = Field(default=None, max_length=240)
    payment_method: str | None = Field(default=None, max_length=80)
    spent_on: date | None = None


class EmployeeCreate(BaseModel):
    display_name: str = Field(min_length=1, max_length=160)
    email: str
    password: str = Field(min_length=8, max_length=128)

    @field_validator("email")
    @classmethod
    def validate_email(cls, value: str) -> str:
        normalized = value.strip().lower()
        if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", normalized):
            raise ValueError("Enter a valid email address.")
        return normalized


class LaybyPayment(BaseModel):
    amount: Decimal = Field(gt=0, max_digits=12, decimal_places=2)


class SaleCreate(BaseModel):
    discount_percent: Decimal = Field(default=Decimal(0), ge=0, le=100)
    discount_type: Literal["percent", "value"] = "percent"
    discount_value: Decimal = Field(
        default=Decimal(0), ge=0, max_digits=12, decimal_places=2
    )
    payment_method: str = Field(min_length=1, max_length=80)
    sale_type: Literal["Online", "Walk-in"] = "Walk-in"
    items: list[SaleItem] = Field(min_length=1)
    layby_deposit: Decimal = Field(default=Decimal(0), ge=0, max_digits=12, decimal_places=2)
    customer_name: str = Field(default="", max_length=160)
    customer_phone: str = Field(default="", max_length=40)


class ShopUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str | None = Field(default=None, min_length=1, max_length=160)
    owner_name: str | None = Field(default=None, min_length=1, max_length=160)
    phone: str | None = Field(default=None, max_length=40)
    location: str | None = Field(default=None, min_length=1, max_length=160)
    contact_email: str | None = Field(default=None, max_length=254)
    facebook: str | None = Field(default=None, max_length=120)
    instagram: str | None = Field(default=None, max_length=120)
    tiktok: str | None = Field(default=None, max_length=120)
    whatsapp: str | None = Field(default=None, max_length=120)
    calls: str | None = Field(default=None, max_length=120)


security = HTTPBearer(auto_error=False)
app = FastAPI(title="Malonda Yanga API", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=get_settings().origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def _configuration() -> tuple[str, str]:
    config = get_settings()
    url = config.supabase_url.rstrip("/")
    key = config.supabase_anon_key.strip()
    if not url.startswith("https://") or not url.endswith(".supabase.co"):
        raise HTTPException(
            status_code=503,
            detail="Configure SUPABASE_URL with the Supabase project URL.",
        )
    if not key or key.startswith("sb_secret_"):
        raise HTTPException(
            status_code=503,
            detail="Configure SUPABASE_ANON_KEY with a publishable/anon key.",
        )
    return url, key


def _service_role_key() -> str:
    """Returns the Supabase service role key required for admin auth endpoints.

    /auth/v1/admin/* endpoints (create/delete admin users) require the
    service_role key, not the anon key and not a user's access token. The anon
    key is intentionally rejected here because it cannot administer auth users.
    Both the new secret keys (sb_secret_...) and the legacy service_role JWT
    (eyJ...) are accepted.
    """
    config = get_settings()
    key = config.supabase_service_role_key.strip()
    if not key or not (key.startswith("sb_secret_") or key.startswith("eyJ")):
        raise HTTPException(
            status_code=503,
            detail=(
                "Configure SUPABASE_SERVICE_ROLE_KEY with the Supabase service "
                "role key (sb_secret_... or the legacy eyJ... JWT) to create "
                "employee logins."
            ),
        )
    return key


def _storage_admin_jwt() -> str:
    """Returns a service_role JWT usable against the Storage API, if present.

    Supabase Storage validates the Authorization header as a JWT and rejects
    the new sb_secret_... API keys with "Invalid Compact JWS". Only a legacy
    service_role JWT (eyJ...) can bypass storage RLS, so it is used when the
    configured key has that form; otherwise uploads fall back to the signed-in
    user's access token and the storage policies.
    """
    key = get_settings().supabase_service_role_key.strip()
    return key if key.startswith("eyJ") else ""


async def supabase_request(
    method: str,
    path: str,
    *,
    token: str | None = None,
    params: dict[str, str] | None = None,
    body: Any = None,
    admin: bool = False,
) -> Any:
    url, key = _configuration()
    headers = {
        "apikey": key,
        "Authorization": f"Bearer {token or key}",
    }
    # Admin auth endpoints (/auth/v1/admin/*) require the service role key,
    # not the anon key and not the signed-in user's access token.
    if admin:
        service_key = _service_role_key()
        headers = {
            "apikey": service_key,
            "Authorization": f"Bearer {service_key}",
        }
    if method in {"POST", "PATCH", "DELETE"}:
        headers["Prefer"] = "return=representation"

    content: bytes | None = None
    if body is not None:
        # Pydantic Decimal fields (cost, price, etc.) are not JSON serializable
        # by the stdlib encoder, so serialize them explicitly as numbers.
        content = json.dumps(
            body, ensure_ascii=False, separators=(",", ":"), cls=_JsonEncoder
        ).encode("utf-8")
        headers["Content-Type"] = "application/json"

    try:
        async with httpx.AsyncClient(timeout=20) as client:
            response = await client.request(
                method,
                f"{url}/{path.lstrip('/')}",
                headers=headers,
                params=params,
                content=content,
            )
    except httpx.TimeoutException as error:
        raise HTTPException(
            status_code=504,
            detail="Supabase did not respond in time.",
        ) from error
    except httpx.RequestError as error:
        raise HTTPException(
            status_code=503,
            detail="Could not connect to Supabase.",
        ) from error

    if response.is_error:
        try:
            detail = response.json()
        except ValueError:
            detail = response.text
        if isinstance(detail, dict):
            detail = (
                detail.get("msg")
                or detail.get("message")
                or detail.get("error_description")
                or detail.get("details")
                or "Supabase request failed."
            )
        raise HTTPException(
            status_code=response.status_code,
            detail=str(detail),
        )
    if not response.content:
        return None
    try:
        return response.json()
    except ValueError as error:
        raise HTTPException(
            status_code=502,
            detail="Supabase returned an invalid response.",
        ) from error


async def _ensure_public_bucket(bucket: str) -> None:
    """Best-effort: creates the storage bucket or makes it public.

    Bucket admin calls need a legacy service_role JWT; the new sb_secret_...
    keys are rejected by Storage. Failures are logged and ignored so the
    upload itself still runs with the caller's token and the bucket/policies
    created by backend/supabase/schema.sql.
    """
    if not _storage_admin_jwt():
        return
    try:
        await supabase_request(
            "PUT",
            f"/storage/v1/bucket/{bucket}",
            admin=True,
            body={"public": True},
        )
        return
    except HTTPException as error:
        print(f"Storage bucket update failed for '{bucket}': "
              f"{error.status_code} {error.detail}", flush=True)
    try:
        await supabase_request(
            "POST",
            "/storage/v1/bucket",
            admin=True,
            body={"id": bucket, "name": bucket, "public": True},
        )
    except HTTPException as error:
        # Another request may have created it between the PUT and POST.
        if error.status_code not in (400, 409):
            print(f"Storage bucket create failed for '{bucket}': "
                  f"{error.status_code} {error.detail}", flush=True)


async def supabase_upload(
    path: str,
    *,
    token: str,
    content: bytes,
    content_type: str,
) -> None:
    url, key = _configuration()
    service_jwt = _storage_admin_jwt()
    if service_jwt:
        # A legacy service_role JWT is the only key Storage accepts for
        # bypassing storage.objects RLS.
        headers = {
            "apikey": service_jwt,
            "Authorization": f"Bearer {service_jwt}",
            "Content-Type": content_type,
            "x-upsert": "true",
        }
    else:
        # New secret keys are not JWTs, so the user's access token is the only
        # credential Storage will verify; RLS is enforced by the storage
        # policies in backend/supabase/schema.sql.
        headers = {
            "apikey": key,
            "Authorization": f"Bearer {token}",
            "Content-Type": content_type,
            "x-upsert": "true",
        }
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            response = await client.post(
                f"{url}/storage/v1/object/{path.lstrip('/')}",
                headers=headers,
                content=content,
            )
    except httpx.TimeoutException as error:
        raise HTTPException(
            status_code=504,
            detail="Supabase Storage did not respond in time.",
        ) from error
    except httpx.RequestError as error:
        raise HTTPException(
            status_code=503,
            detail="Could not connect to Supabase Storage.",
        ) from error
    if response.is_error:
        try:
            detail = response.json()
        except ValueError:
            detail = response.text
        # Log the raw storage error so storage misconfigurations (wrong
        # bucket name, RLS rejection, MIME rules) are visible in the server
        # console instead of surfacing as an opaque 400.
        print(f"Supabase Storage upload failed for '{path}': "
              f"{response.status_code} {detail}", flush=True)
        if isinstance(detail, dict):
            detail = detail.get("message") or detail.get("error") or "Image upload failed."
        raise HTTPException(status_code=response.status_code, detail=str(detail))


async def current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
) -> dict[str, Any]:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=401, detail="Sign in to continue.")

    # Short-lived cache: each API call previously re-verified the JWT with a
    # /auth/v1/user round-trip to Supabase, which tripled latency on every
    # request. Tokens are stable for their lifetime, so a 60s per-token cache
    # is safe and keeps consecutive page loads snappy.
    cached = _user_cache.get(credentials.credentials)
    if cached is not None:
        return cached
    try:
        user = await supabase_request(
            "GET",
            "/auth/v1/user",
            token=credentials.credentials,
        )
    except HTTPException as error:
        # Supabase reports expired/malformed JWTs as 401 or 403 (e.g.
        # error_code "bad_jwt"). Always surface those as 401 so clients
        # know to refresh the session instead of treating it as a
        # permissions problem.
        if error.status_code in (401, 403):
            raise HTTPException(status_code=401, detail="Session expired. Sign in again.") from error
        raise
    if not isinstance(user, dict) or not user.get("id"):
        raise HTTPException(status_code=401, detail="Supabase returned no user.")
    if len(_user_cache) > 512:
        _user_cache.clear()
    _user_cache[credentials.credentials] = user
    return user


def _session_response(
    payload: dict[str, Any],
    shop: dict[str, Any] | None,
    role: str | None = None,
) -> dict[str, Any]:
    user = payload.get("user") or payload
    session = payload.get("access_token") is not None
    return {
        "user": {"id": user.get("id"), "email": user.get("email"), "role": role},
        "shop": shop,
        "access_token": payload.get("access_token"),
        "refresh_token": payload.get("refresh_token"),
        "requires_email_confirmation": not session,
    }


async def _shop_for_user(user: dict[str, Any], token: str) -> dict[str, Any]:
    # Cache the shop row per user for a short window — the shop rarely changes
    # and this removes a Supabase round-trip from every authenticated request.
    cached = _shop_cache.get(user["id"])
    if cached is not None:
        return cached
    # Owner path: the shop this user owns.
    rows = await supabase_request(
        "GET",
        "/rest/v1/shops",
        token=token,
        params={
            "select": "*",
            "owner_id": f"eq.{user['id']}",
            "limit": "1",
        },
    )
    if rows:
        if len(_shop_cache) > 512:
            _shop_cache.clear()
        _shop_cache[user["id"]] = rows[0]
        return rows[0]
    # Employee path: the shop linked through the invite metadata (set when the
    # owner created the employee login) or the shop_users row. Shops are
    # owner-only under RLS, so read the full row with the service role; that
    # gives employees the real company name, logo and contacts for headers and
    # receipts instead of a bare id.
    metadata = user.get("user_metadata") or {}
    shop_id = metadata.get("shop_id")
    if not shop_id:
        rows = await supabase_request(
            "GET",
            "/rest/v1/shop_users",
            token=token,
            params={
                "select": "shop_id",
                "user_id": f"eq.{user['id']}",
                "limit": "1",
            },
        )
        if rows:
            shop_id = rows[0].get("shop_id")
    if shop_id:
        shop: dict[str, Any] = {"id": shop_id}
        try:
            owned = await supabase_request(
                "GET",
                "/rest/v1/shops",
                admin=True,
                params={
                    "select": "*",
                    "id": f"eq.{shop_id}",
                    "limit": "1",
                },
            )
        except HTTPException as error:
            print(
                "Employee shop lookup failed (check SUPABASE_SERVICE_ROLE_KEY): "
                f"{error.status_code} {error.detail}",
                flush=True,
            )
            owned = []
        if owned:
            shop = owned[0]
        if len(_shop_cache) > 512:
            _shop_cache.clear()
        _shop_cache[user["id"]] = shop
        return shop
    # Owner registration flow: create the shop from signup metadata.
    required = ("shop_name", "owner_name", "location", "business_type")
    if any(not metadata.get(key) for key in required):
        raise HTTPException(
            status_code=404,
            detail="No shop is linked to this account. Register a shop first.",
        )
    created = await supabase_request(
        "POST",
        "/rest/v1/shops",
        token=token,
        params={"select": "*"},
        body={
            "owner_id": user["id"],
            "name": metadata["shop_name"],
            "owner_name": metadata["owner_name"],
            "phone": metadata.get("phone") or "",
            "location": metadata["location"],
            "business_type": metadata["business_type"],
            **{
                field: metadata.get(field) or ""
                for field in SHOP_CONTACT_FIELDS
            },
        },
    )
    if not created:
        raise HTTPException(status_code=502, detail="Supabase did not create the shop.")
    # Record the owner as a shop member so role resolution always finds them.
    # Use the service role so this works even if RLS policies are not yet applied.
    try:
        await supabase_request(
            "POST",
            "/rest/v1/shop_users",
            admin=True,
            body={
                "shop_id": created[0]["id"],
                "user_id": user["id"],
                "role": "owner",
                "display_name": metadata["owner_name"],
            },
        )
    except HTTPException as error:
        # Row may already exist (backfill/migration); role resolution falls back
        # to the shop-ownership lookup below. Surface the reason so a bad
        # service role key is visible instead of silently losing the row.
        print(
            "Could not record the owner in shop_users "
            f"({error.status_code}): {error.detail}",
            flush=True,
        )
    return created[0]


async def _owned_shop(user: dict[str, Any], token: str) -> dict[str, Any]:
    return await _shop_for_user(user, token)


async def _table(
    method: str,
    table: str,
    token: str,
    *,
    params: dict[str, str] | None = None,
    body: Any = None,
) -> Any:
    return await supabase_request(
        method,
        f"/rest/v1/{table}",
        token=token,
        params=params,
        body=body,
    )


def _bearer_token(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
) -> str:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=401, detail="Sign in to continue.")
    return credentials.credentials


async def _user_role(user: dict[str, Any], token: str) -> str | None:
    """Resolves the signed-in user's role (owner | employee)."""
    rows = await supabase_request(
        "GET",
        "/rest/v1/shop_users",
        token=token,
        params={
            "select": "role",
            "user_id": f"eq.{user['id']}",
            "limit": "1",
        },
    )
    if rows:
        role = rows[0].get("role")
        print(f"[DEBUG] _user_role: found shop_users row for user {user['id']}, role={role}")
        return role
    # Fallback: if the user owns a shop, they're an owner. Query with the
    # user's own token first (the shops RLS policy lets owners read their own
    # shop), then with the service role, and never let a missing/revoked
    # SUPABASE_SERVICE_ROLE_KEY break sign-in.
    params = {
        "select": "id",
        "owner_id": f"eq.{user['id']}",
        "limit": "1",
    }
    try:
        owned = await supabase_request(
            "GET", "/rest/v1/shops", token=token, params=params
        )
    except HTTPException:
        owned = []
    if not owned:
        try:
            owned = await supabase_request(
                "GET", "/rest/v1/shops", admin=True, params=params
            )
        except HTTPException as error:
            print(
                "Shop ownership fallback failed (check "
                f"SUPABASE_SERVICE_ROLE_KEY): {error.status_code} {error.detail}",
                flush=True,
            )
            owned = []
    if owned:
        print(f"[DEBUG] _user_role: user {user['id']} owns shop {owned[0]['id']}, returning owner")
        return "owner"
    metadata = user.get("user_metadata") or {}
    role = metadata.get("role")
    # Final fallback: if user has any shop in metadata, they're an owner.
    if not role and metadata.get("shop_id"):
        print(f"[DEBUG] _user_role: user {user['id']} has shop_id in metadata, returning owner")
        return "owner"
    print(f"[DEBUG] _user_role: user {user['id']} no role found, metadata={metadata}")
    return role


async def current_user_role(
    user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
) -> str:
    role = await _user_role(user, token)
    return role or "employee"


async def require_owner(role: str = Depends(current_user_role)) -> None:
    if role != "owner":
        raise HTTPException(
            status_code=403, detail="Shop owner access required."
        )


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/auth/confirmed", response_class=HTMLResponse)
async def auth_confirmed() -> str:
    return """<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Email confirmation</title>
  </head>
  <body style="font: 16px system-ui, sans-serif; max-width: 34rem; margin: 15vh auto; padding: 1rem; color: #17211b">
    <h1>Email confirmation link processed</h1>
    <p>Return to Malonda Yanga and sign in with your email and password.</p>
  </body>
</html>"""


@app.get("/auth/recovery", response_class=HTMLResponse)
async def auth_recovery() -> str:
    return """<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Reset password</title>
  </head>
  <body style="font: 16px system-ui, sans-serif; max-width: 34rem; margin: 12vh auto; padding: 1rem; color: #17211b">
    <h1>Choose a new password</h1>
    <form id="reset-form">
      <label for="password">New password (at least 8 characters)</label><br>
      <input id="password" type="password" minlength="8" required style="box-sizing: border-box; width: 100%; margin: .75rem 0; padding: .8rem">
      <button style="padding: .7rem 1rem">Update password</button>
    </form>
    <p id="status" role="status"></p>
    <script>
      const statusText = document.getElementById('status');
      document.getElementById('reset-form').addEventListener('submit', async (event) => {
        event.preventDefault();
        const accessToken = new URLSearchParams(location.hash.slice(1)).get('access_token');
        if (!accessToken) {
          statusText.textContent = 'This reset link is invalid or expired. Request a new one in the app.';
          return;
        }
        try {
          const response = await fetch('/auth/password', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${accessToken}`
            },
            body: JSON.stringify({ password: document.getElementById('password').value })
          });
          const result = await response.json();
          if (!response.ok) throw new Error(result.detail || 'Could not update password.');
          history.replaceState(null, '', location.pathname);
          document.getElementById('reset-form').remove();
          statusText.textContent = 'Password updated. Return to Malonda Yanga and sign in.';
        } catch (error) {
          statusText.textContent = error.message || 'Could not update password.';
        }
      });
    </script>
  </body>
</html>"""


@app.post("/auth/register")
async def register(data: ShopRegistration) -> dict[str, Any]:
    payload = await supabase_request(
        "POST",
        "/auth/v1/signup",
        params={"redirect_to": get_settings().auth_redirect_url},
        body={
            "email": data.email,
            "password": data.password,
            "data": {
                "shop_name": data.shop_name,
                "owner_name": data.owner_name,
                "phone": data.phone,
                "location": data.location,
                "business_type": data.business_type,
                "contact_email": data.contact_email,
                "facebook": data.facebook,
                "instagram": data.instagram,
                "tiktok": data.tiktok,
                "whatsapp": data.whatsapp,
                "calls": data.calls,
                "role": "owner",
            },
        },
    )
    if not isinstance(payload, dict) or not payload.get("user", payload).get("id"):
        raise HTTPException(status_code=502, detail="Supabase did not return a registered user.")
    user = payload.get("user") or payload
    shop = None
    token = payload.get("access_token")
    if token:
        shop = await _shop_for_user(user, token)
        role = await _user_role(user, token)
    else:
        role = None
    return _session_response(payload, shop, role)


@app.post("/auth/password/reset")
async def request_password_reset(data: PasswordResetRequest) -> dict[str, bool]:
    await supabase_request(
        "POST",
        "/auth/v1/recover",
        params={"redirect_to": get_settings().auth_recovery_redirect_url},
        body={"email": data.email},
    )
    return {"sent": True}


@app.post("/auth/password")
async def update_password(
    data: PasswordUpdate,
    _user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
) -> dict[str, bool]:
    await supabase_request(
        "PUT",
        "/auth/v1/user",
        token=token,
        body={"password": data.password},
    )
    return {"updated": True}


async def _shared_email_login(email: str, password: str) -> dict[str, Any] | None:
    """Signs in a staff member who shares the company email with the owner.

    Each staff auth account has its own internal address (see
    ``_unique_auth_email``). Try every staff account registered under the
    shared address with the submitted password and return the first session.
    """
    try:
        rows = await supabase_request(
            "GET",
            "/rest/v1/shop_users",
            admin=True,
            params={
                "select": "login_email,auth_email",
                "role": "eq.employee",
                "login_email": f"eq.{email}",
            },
        )
    except HTTPException:
        return None
    for row in rows or []:
        auth_email = str(row.get("auth_email") or "").strip()
        if not auth_email or auth_email == email:
            continue
        try:
            payload = await supabase_request(
                "POST",
                "/auth/v1/token",
                params={"grant_type": "password"},
                body={"email": auth_email, "password": password},
            )
        except HTTPException:
            continue
        if isinstance(payload, dict) and payload.get("user"):
            return payload
    return None


def _staff_auth_email(login_email: str) -> str:
    """Builds a unique internal auth address for a staff login.

    Supabase only stores one account per email, so staff sharing the company
    email get a ``+staff-…`` tagged address while still signing in with the
    plain company email.
    """
    local, _, domain = login_email.partition("@")
    return f"{local}+staff-{uuid4().hex[:10]}@{domain}"


@app.post("/auth/login")
async def login(data: LoginRequest) -> dict[str, Any]:
    try:
        payload = await supabase_request(
            "POST",
            "/auth/v1/token",
            params={"grant_type": "password"},
            body={"email": data.email, "password": data.password},
        )
    except HTTPException as error:
        # Staff can sign in with the shared company email. Their auth accounts
        # live under a unique internal address, so retry those accounts with
        # the submitted password before rejecting the sign-in.
        payload = await _shared_email_login(data.email, data.password)
        if payload is None:
            raise error
    if not isinstance(payload, dict) or not payload.get("user"):
        raise HTTPException(status_code=502, detail="Supabase did not return a signed-in user.")
    shop = await _shop_for_user(payload["user"], payload["access_token"])
    role = await _user_role(payload["user"], payload["access_token"])
    return _session_response(payload, shop, role)


@app.post("/auth/refresh")
async def refresh(data: RefreshRequest) -> dict[str, Any]:
    payload = await supabase_request(
        "POST",
        "/auth/v1/token",
        params={"grant_type": "refresh_token"},
        body={"refresh_token": data.refresh_token},
    )
    if not isinstance(payload, dict) or not payload.get("user"):
        raise HTTPException(status_code=502, detail="Supabase did not refresh the session.")
    return _session_response(payload, None)


@app.get("/auth/me")
async def me(
    user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
    role: str = Depends(current_user_role),
) -> dict[str, Any]:
    return {
        "user": {"id": user["id"], "email": user.get("email"), "role": role},
        "shop": await _shop_for_user(user, token),
    }


@app.get("/products")
async def products(
    search: str | None = None,
    user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
) -> list[dict[str, Any]]:
    shop = await _owned_shop(user, token)
    params = {
        "select": "*",
        "shop_id": f"eq.{shop['id']}",
        "order": "created_at.desc",
    }
    if search and search.strip():
        params["name"] = f"ilike.*{search.strip()}*"
    return await _table("GET", "products", token, params=params)


@app.post("/products")
async def create_product(
    data: ProductCreate,
    user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
) -> dict[str, Any]:
    shop = await _owned_shop(user, token)
    rows = await _table(
        "POST",
        "products",
        token,
        params={"select": "*"},
        body={**data.model_dump(mode="json"), "shop_id": shop["id"]},
    )
    if not rows:
        raise HTTPException(status_code=502, detail="Supabase did not save the product.")
    return rows[0]


@app.patch("/products/{product_id}")
async def update_product(
    product_id: str,
    data: ProductUpdate,
    user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
) -> dict[str, Any]:
    shop = await _owned_shop(user, token)
    updates = data.model_dump(exclude_unset=True)
    if not updates:
        raise HTTPException(status_code=422, detail="Provide at least one product field.")
    rows = await _table(
        "PATCH",
        "products",
        token,
        params={
            "id": f"eq.{product_id}",
            "shop_id": f"eq.{shop['id']}",
            "select": "*",
        },
        body=updates,
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Product not found.")
    return rows[0]


@app.delete("/products/{product_id}")
async def delete_product(
    product_id: str,
    user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
) -> dict[str, bool]:
    shop = await _owned_shop(user, token)
    rows = await _table(
        "DELETE",
        "products",
        token,
        params={
            "id": f"eq.{product_id}",
            "shop_id": f"eq.{shop['id']}",
            "select": "id",
        },
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Product not found.")
    return {"deleted": True}


@app.put("/products/{product_id}/image")
async def upload_product_image(
    product_id: str,
    data: ProductImageUpload,
    user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
) -> dict[str, str]:
    shop = await _owned_shop(user, token)
    products = await _table(
        "GET",
        "products",
        token,
        params={
            "select": "id",
            "id": f"eq.{product_id}",
            "shop_id": f"eq.{shop['id']}",
            "limit": "1",
        },
    )
    if not products:
        raise HTTPException(status_code=404, detail="Product not found.")
    try:
        image = base64.b64decode(data.image_base64, validate=True)
    except (binascii.Error, ValueError) as error:
        raise HTTPException(status_code=422, detail="The product image is invalid.") from error
    if len(image) > 5 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Product images must be 5 MB or smaller.")

    extension = {
        "image/jpeg": "jpg",
        "image/png": "png",
        "image/webp": "webp",
    }[data.content_type]
    object_path = f"{shop['id']}/{product_id}.{extension}"
    await supabase_upload(
        f"product-images/{object_path}",
        token=token,
        content=image,
        content_type=data.content_type,
    )
    config = get_settings()
    image_url = (
        f"{config.supabase_url.rstrip('/')}/storage/v1/object/public/"
        f"product-images/{object_path}"
    )
    try:
        rows = await _table(
            "PATCH",
            "products",
            token,
            params={
                "id": f"eq.{product_id}",
                "shop_id": f"eq.{shop['id']}",
                "select": "id",
            },
            body={"image_url": image_url},
        )
    except HTTPException as error:
        # A 400 from PostgREST here almost always means the live database
        # is missing the products.image_url column (migration not run yet),
        # even though the file itself landed in the bucket successfully.
        # Make that obvious instead of a generic 400.
        detail_text = str(error.detail)
        if error.status_code == 400 and "image_url" in detail_text:
            print(
                "Missing products.image_url column: run "
                "backend/supabase/schema.sql in the Supabase SQL editor.",
                flush=True,
            )
            raise HTTPException(
                status_code=500,
                detail=(
                    "The image was saved to the bucket, but the products "
                    "table has no image_url column. Run the latest "
                    "backend/supabase/schema.sql migration in Supabase."
                ),
            ) from error
        raise
    if not rows:
        raise HTTPException(status_code=404, detail="Product not found.")
    return {"image_url": image_url}


"""30-day sales performance plus the most recent stock movements (sales) for
one product. Powers the "Sales Performance" and "Recent Stock History"
sections of the inventory report page.
"""
@app.get("/products/{product_id}/sales-history")
async def product_sales_history(
    product_id: str,
    days: int = Query(default=30, ge=1, le=365),
    user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
) -> dict[str, Any]:
    shop = await _owned_shop(user, token)
    shop_filter = {"shop_id": f"eq.{shop['id']}"}

    product_rows = await _table(
        "GET",
        "products",
        token,
        params={
            "select": "id,name,category,sub_category,quantity",
            "id": f"eq.{product_id}",
            **shop_filter,
        },
    )
    if not product_rows:
        raise HTTPException(status_code=404, detail="Product not found.")
    stock = int(product_rows[0].get("quantity") or 0)

    since = datetime.now(timezone.utc) - timedelta(days=days)
    sales = await _table(
        "GET",
        "sales",
        token,
        params={
            "select": "id,sold_at,payment_method,sale_type,total",
            **shop_filter,
            "sold_at": f"gte.{since.isoformat()}",
            "order": "sold_at.desc",
        },
    )
    sales_by_id = {str(sale["id"]): sale for sale in sales}
    sale_ids = list(sales_by_id)
    lines: list[dict[str, Any]] = []
    if sale_ids:
        lines = await _table(
            "GET",
            "sale_items",
            token,
            params={
                "select": "sale_id,product_id,quantity,unit_price,unit_cost",
                "product_id": f"eq.{product_id}",
                "sale_id": f"in.({','.join(sale_ids)})",
            },
        )

    product_row = product_rows[0]
    sold = 0
    revenue = 0.0
    history: list[dict[str, Any]] = []
    for line in lines:
        sale = sales_by_id.get(str(line["sale_id"]))
        if sale is None:
            continue
        quantity = int(line["quantity"])
        price = float(line["unit_price"])
        sold += quantity
        revenue += price * quantity
        history.append(
            {
                "sale_id": str(line["sale_id"]),
                "sold_at": sale["sold_at"],
                "payment_method": sale["payment_method"],
                "sale_type": sale["sale_type"],
                "quantity": quantity,
                "unit_price": price,
                # Product details so the client can render what was sold
                # without a second request.
                "product_name": product_row.get("name") or "",
                "category": product_row.get("category") or "",
                "sub_category": product_row.get("sub_category") or "",
            }
        )

    history.sort(key=lambda entry: str(entry["sold_at"]), reverse=True)
    daily_run_rate = sold / days
    runway_days = int(stock / daily_run_rate) if daily_run_rate > 0 else None

    return {
        "product_id": product_id,
        "stock": stock,
        "window_days": days,
        "sold": sold,
        "revenue": round(revenue, 2),
        "daily_run_rate": round(daily_run_rate, 2),
        "runway_days": runway_days,
        "history": history[:8],
    }


@app.get("/suppliers")
async def suppliers(
    user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
) -> list[dict[str, Any]]:
    shop = await _owned_shop(user, token)
    return await _table(
        "GET",
        "suppliers",
        token,
        params={
            "select": "*",
            "shop_id": f"eq.{shop['id']}",
            "order": "name.asc",
        },
    )


@app.post("/suppliers")
async def create_supplier(
    data: SupplierCreate,
    user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
) -> dict[str, Any]:
    shop = await _owned_shop(user, token)
    rows = await _table(
        "POST",
        "suppliers",
        token,
        params={"select": "*"},
        body={**data.model_dump(), "name": data.name.strip(), "shop_id": shop["id"]},
    )
    if not rows:
        raise HTTPException(status_code=502, detail="Supabase did not save the supplier.")
    return rows[0]


@app.patch("/suppliers/{supplier_id}")
async def update_supplier(
    supplier_id: str,
    data: SupplierUpdate,
    user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
) -> dict[str, Any]:
    shop = await _owned_shop(user, token)
    updates = data.model_dump(exclude_unset=True)
    if not updates:
        raise HTTPException(status_code=422, detail="Provide at least one supplier field.")
    if "name" in updates and updates["name"] is not None:
        updates["name"] = updates["name"].strip()
    rows = await _table(
        "PATCH",
        "suppliers",
        token,
        params={
            "id": f"eq.{supplier_id}",
            "shop_id": f"eq.{shop['id']}",
            "select": "*",
        },
        body=updates,
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Supplier not found.")
    return rows[0]


@app.delete("/suppliers/{supplier_id}")
async def delete_supplier(
    supplier_id: str,
    user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
) -> dict[str, bool]:
    shop = await _owned_shop(user, token)
    rows = await _table(
        "DELETE",
        "suppliers",
        token,
        params={"id": f"eq.{supplier_id}", "shop_id": f"eq.{shop['id']}", "select": "id"},
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Supplier not found.")
    return {"deleted": True}


@app.post("/sales")
async def create_sale(
    data: SaleCreate,
    user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
) -> dict[str, Any]:
    shop = await _owned_shop(user, token)
    sale = await supabase_request(
        "POST",
        "/rest/v1/rpc/create_shop_sale",
        token=token,
        body={
            "p_shop_id": shop["id"],
            "p_discount_percent": str(data.discount_percent),
            "p_discount_type": data.discount_type,
            "p_discount_value": str(data.discount_value),
            "p_payment_method": data.payment_method,
            "p_sale_type": data.sale_type,
            "p_items": [item.model_dump(exclude_none=True) for item in data.items],
            "p_layby_deposit": str(data.layby_deposit),
            "p_customer_name": data.customer_name.strip(),
            "p_customer_phone": data.customer_phone.strip(),
        },
    )
    if not isinstance(sale, dict):
        raise HTTPException(status_code=502, detail="Supabase did not save the sale.")
    return sale


@app.delete("/sales/{sale_id}")
async def delete_sale(
    sale_id: str,
    user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
) -> dict[str, bool]:
    """Removes a sale and returns every item's quantity to inventory.

    Stock is deducted when a sale is recorded, so deleting a wrong sale must
    put those units back. Products that were deleted meanwhile are skipped
    (their sale_items row has a null product_id).
    """
    shop = await _owned_shop(user, token)
    sale_rows = await _table(
        "GET",
        "sales",
        token,
        params={
            "id": f"eq.{sale_id}",
            "shop_id": f"eq.{shop['id']}",
            "select": "id",
            "limit": "1",
        },
    )
    if not sale_rows:
        raise HTTPException(status_code=404, detail="Sale not found.")
    items = await _table(
        "GET",
        "sale_items",
        token,
        params={"sale_id": f"eq.{sale_id}", "select": "product_id,quantity"},
    )
    sold: dict[str, int] = {}
    for item in items or []:
        product_id = item.get("product_id")
        if not product_id:
            continue
        try:
            quantity = int(item.get("quantity") or 0)
        except (TypeError, ValueError):
            continue
        if quantity > 0:
            sold[str(product_id)] = sold.get(str(product_id), 0) + quantity
    for product_id, quantity in sold.items():
        product_rows = await supabase_request(
            "GET",
            "/rest/v1/products",
            admin=True,
            params={
                "id": f"eq.{product_id}",
                "shop_id": f"eq.{shop['id']}",
                "select": "quantity",
                "limit": "1",
            },
        )
        if not product_rows:
            continue
        try:
            current = int(product_rows[0].get("quantity") or 0)
        except (TypeError, ValueError):
            current = 0
        await supabase_request(
            "PATCH",
            "/rest/v1/products",
            admin=True,
            params={
                "id": f"eq.{product_id}",
                "shop_id": f"eq.{shop['id']}",
                "select": "id",
            },
            body={"quantity": current + quantity},
        )
    rows = await _table(
        "DELETE",
        "sales",
        token,
        params={"id": f"eq.{sale_id}", "shop_id": f"eq.{shop['id']}", "select": "id"},
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Sale not found.")
    return {"deleted": True}


@app.get("/laybys")
async def list_laybys(
    user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
) -> list[dict[str, Any]]:
    shop = await _owned_shop(user, token)
    rows = await _table(
        "GET",
        "sales",
        token,
        params={
            "shop_id": f"eq.{shop['id']}",
            "layby_balance": "gt.0",
            "layby_settled": "is.false",
            "order": "sold_at.desc",
            "select": "*",
        },
    )
    return rows


@app.get("/laybys/history")
async def layby_history(
    user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
) -> list[dict[str, Any]]:
    """Every layby sale (open and settled) with its payment history attached."""
    shop = await _owned_shop(user, token)
    sales = await _table(
        "GET",
        "sales",
        token,
        params={
            "shop_id": f"eq.{shop['id']}",
            "payment_method": "eq.Layby",
            "order": "sold_at.desc",
            "select": "*",
        },
    )
    if not sales:
        return []
    sale_ids = [str(sale["id"]) for sale in sales]
    try:
        payments = await _table(
            "GET",
            "layby_payments",
            token,
            params={
                "select": "id,sale_id,amount,paid_at",
                "sale_id": f"in.({','.join(sale_ids)})",
                "order": "paid_at.asc",
            },
        )
    except HTTPException as error:
        # A missing layby_payments table (schema.sql never applied) must not
        # break the whole History tab — show the sales with no payment rows.
        if error.status_code == 404:
            payments = []
        else:
            raise
    payments_by_sale: dict[str, list[dict[str, Any]]] = {}
    for payment in payments:
        payments_by_sale.setdefault(str(payment["sale_id"]), []).append(payment)
    return [
        {**sale, "payments": payments_by_sale.get(str(sale["id"]), [])}
        for sale in sales
    ]


@app.post("/laybys/{sale_id}/payments")
async def pay_layby_endpoint(
    sale_id: str,
    data: LaybyPayment,
    user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
) -> dict[str, Any]:
    await _owned_shop(user, token)
    try:
        updated = await supabase_request(
            "POST",
            "/rest/v1/rpc/pay_layby",
            token=token,
            body={
                "p_sale_id": sale_id,
                "p_amount": str(data.amount),
            },
        )
    except HTTPException as error:
        # PostgREST surfaces plpgsql exceptions and missing table privileges
        # as 400s. Translate the common ones into actionable messages —
        # notably a missing UPDATE grant on sales, which used to surface as
        # an opaque "Sale not found"-style failure.
        detail = str(error.detail or "")
        lowered = detail.lower()
        if error.status_code == 400 and "permission denied" in lowered:
            if "update" in lowered or "sales" in lowered:
                raise HTTPException(
                    status_code=500,
                    detail=(
                        "The database is missing the UPDATE grant on the "
                        "sales table. Run the latest "
                        "backend/supabase/schema.sql in the Supabase SQL "
                        "editor and retry."
                    ),
                ) from error
            raise HTTPException(
                status_code=500,
                detail=(
                    "The database rejected the payment for lack of table "
                    "privileges. Re-run backend/supabase/schema.sql in the "
                    "Supabase SQL editor."
                ),
            ) from error
        if error.status_code == 400 and "sale not found" in lowered:
            raise HTTPException(
                status_code=404,
                detail="That layby sale no longer exists or belongs to another shop.",
            ) from error
        if error.status_code == 400 and "not an open layby" in lowered:
            raise HTTPException(
                status_code=409,
                detail="This sale is already fully paid.",
            ) from error
        raise
    if not isinstance(updated, dict):
        raise HTTPException(status_code=502, detail="Supabase did not record the payment.")
    return updated


def _zambia_boundary(day: date) -> str:
    local = datetime.combine(day, time.min, tzinfo=timezone(timedelta(hours=2)))
    return local.astimezone(timezone.utc).isoformat()


@app.get("/dashboard")
async def dashboard(
    user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
) -> dict[str, Any]:
    shop = await _owned_shop(user, token)
    today = datetime.now(timezone(timedelta(hours=2))).date()
    filters = {"shop_id": f"eq.{shop['id']}"}
    product_rows = await _table(
        "GET",
        "products",
        token,
        params={"select": "id,quantity", **filters},
    )
    sale_rows = await _table(
        "GET",
        "sales",
        token,
        params={
            "select": "total",
            **filters,
            "and": (
                f"(sold_at.gte.{_zambia_boundary(today)},"
                f"sold_at.lt.{_zambia_boundary(today + timedelta(days=1))})"
            ),
        },
    )
    return {
        "product_count": len(product_rows),
        "stock_count": sum(int(product["quantity"]) for product in product_rows),
        "low_stock_count": sum(int(product["quantity"]) <= 5 for product in product_rows),
        "today_sales": sum(float(sale["total"]) for sale in sale_rows),
    }


@app.get("/reports")
async def reports(
    start_date: date = Query(),
    end_date: date = Query(),
    user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
    role: str = Depends(current_user_role),
) -> dict[str, Any]:
    if end_date < start_date:
        raise HTTPException(status_code=422, detail="End date must not precede start date.")
    shop = await _owned_shop(user, token)
    shop_filter = {"shop_id": f"eq.{shop['id']}"}
    after_end = end_date + timedelta(days=1)
    sales = await _table(
        "GET",
        "sales",
        token,
        params={
            "select": "*",
            **shop_filter,
            "and": (
                f"(sold_at.gte.{_zambia_boundary(start_date)},"
                f"sold_at.lt.{_zambia_boundary(after_end)})"
            ),
            "order": "sold_at.asc",
        },
    )
    sale_ids = [str(sale["id"]) for sale in sales]
    lines: list[dict[str, Any]] = []
    if sale_ids:
        lines = await _table(
            "GET",
            "sale_items",
            token,
            params={
                "select": "sale_id,product_id,product_name,quantity,unit_price,unit_cost",
                "sale_id": f"in.({','.join(sale_ids)})",
            },
        )
    products = await _table(
        "GET",
        "products",
        token,
        params={
            "select": "id,name,category,sub_category,quantity",
            **shop_filter,
        },
    )
    products_by_id = {str(product["id"]): product for product in products}
    daily_totals: dict[str, float] = {}
    payment_totals: dict[str, float] = {}
    product_totals: dict[str, dict[str, Any]] = {}
    total_sales = 0.0
    total_cost = 0.0
    total_discounts = 0.0

    for sale in sales:
        amount = float(sale["total"])
        total_discounts += float(sale.get("discount") or 0)
        local_day = datetime.fromisoformat(
            str(sale["sold_at"]).replace("Z", "+00:00")
        ).astimezone(timezone(timedelta(hours=2))).date().isoformat()
        daily_totals[local_day] = daily_totals.get(local_day, 0) + amount
        method = str(sale["payment_method"])
        payment_totals[method] = payment_totals.get(method, 0) + amount
        total_sales += amount

    # Attach the sold product details (name / category / sub category) to
    # every sale so the client can show what was sold in the sales log
    # without extra requests.
    items_by_sale: dict[str, list[dict[str, Any]]] = {}
    for line in lines:
        items_by_sale.setdefault(str(line["sale_id"]), []).append(line)
    sales = [
        {
            **sale,
            "items": [
                {
                    "product_id": str(line.get("product_id") or ""),
                    "product_name": line.get("product_name") or "",
                    "quantity": int(line["quantity"]),
                    "category": (
                        products_by_id.get(str(line.get("product_id") or ""))
                        or {}
                    ).get("category") or "",
                    "sub_category": (
                        products_by_id.get(str(line.get("product_id") or ""))
                        or {}
                    ).get("sub_category") or "",
                }
                for line in items_by_sale.get(str(sale["id"]), [])
            ],
        }
        for sale in sales
    ]

    for line in lines:
        # product_id becomes NULL once the referenced product is deleted;
        # report those lines under their recorded product_name instead.
        raw_product_id = line.get("product_id")
        if raw_product_id is None:
            product_id = f"deleted:{line['product_name']}"
        else:
            product_id = str(raw_product_id)
        product = products_by_id.get(product_id)
        quantity = int(line["quantity"])
        price = float(line["unit_price"])
        cost = float(line["unit_cost"])
        summary = product_totals.setdefault(
            product_id,
            {
                "product_id": product_id,
                "name": (product or {}).get("name") or line["product_name"],
                "category": (product or {}).get("category") or "",
                "sub_category": (product or {}).get("sub_category") or "",
                "stock": (product or {}).get("quantity") or 0,
                "quantity": 0,
                "revenue": 0.0,
            },
        )
        summary["quantity"] += quantity
        summary["revenue"] += price * quantity
        total_cost += cost * quantity

    # Expenses are owner-only under RLS, so employees read them with the
    # service role; otherwise their report would never subtract expenses from
    # the net profit.
    expenses = await supabase_request(
        "GET",
        "/rest/v1/expenses",
        token=token,
        admin=role != "owner",
        params={
            "select": "category,amount",
            "shop_id": f"eq.{shop['id']}",
            "and": (
                f"(spent_on.gte.{start_date},spent_on.lte.{end_date})"
            ),
        },
    )
    expense_by_category: dict[str, float] = {}
    for expense in expenses:
        category = str(expense.get("category") or "Other")
        expense_by_category[category] = (
            expense_by_category.get(category, 0.0) + float(expense["amount"])
        )
    total_expenses = round(sum(expense_by_category.values()), 2)
    gross_profit = round(total_sales - total_cost, 2)

    return {
        "sales": sales,
        "items": lines,
        "total_sales": total_sales,
        "total_cost": total_cost,
        "total_discounts": round(total_discounts, 2),
        "gross_profit": gross_profit,
        "total_expenses": total_expenses,
        "expense_breakdown": expense_by_category,
        "net_profit": round(gross_profit - total_expenses, 2),
        "sale_count": len(sales),
        "payment_totals": payment_totals,
        "daily_totals": [
            {"date": day, "total": total}
            for day, total in sorted(daily_totals.items())
        ],
        "top_products": sorted(
            product_totals.values(),
            key=lambda product: product["revenue"],
            reverse=True,
        ),
    }


@app.get("/settings")
async def settings(
    user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
) -> dict[str, Any]:
    return await _owned_shop(user, token)


@app.patch("/settings")
async def update_settings(
    data: ShopUpdate,
    user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
) -> dict[str, Any]:
    updates = data.model_dump(exclude_unset=True)
    if not updates:
        raise HTTPException(status_code=422, detail="Provide at least one shop setting.")
    shop = await _owned_shop(user, token)
    rows = await _table(
        "PATCH",
        "shops",
        token,
        params={"id": f"eq.{shop['id']}", "select": "*"},
        body=updates,
    )
    if not rows:
        raise HTTPException(status_code=502, detail="Supabase did not update shop settings.")
    _shop_cache[user["id"]] = rows[0]  # keep cache in sync with the update
    return rows[0]


@app.put("/settings/logo")
async def upload_shop_logo(
    data: ProductImageUpload,
    user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
    _: None = Depends(require_owner),
) -> dict[str, str]:
    shop = await _owned_shop(user, token)
    try:
        image = base64.b64decode(data.image_base64, validate=True)
    except (binascii.Error, ValueError) as error:
        raise HTTPException(status_code=422, detail="The logo image is invalid.") from error
    if len(image) > 5 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Logos must be 5 MB or smaller.")

    extension = {
        "image/jpeg": "jpg",
        "image/png": "png",
        "image/webp": "webp",
    }[data.content_type]
    object_path = f"{shop['id']}/logo.{extension}"
    object_key = f"shop-logos/{object_path}"
    await _ensure_public_bucket("shop-logos")
    await supabase_upload(
        object_key,
        token=token,
        content=image,
        content_type=data.content_type,
    )
    config = get_settings()
    logo_url = (
        f"{config.supabase_url.rstrip('/')}/storage/v1/object/public/"
        f"shop-logos/{object_path}"
    )
    try:
        rows = await supabase_request(
            "PATCH",
            "/rest/v1/shops",
            token=token,
            params={"id": f"eq.{shop['id']}", "select": "*"},
            body={"logo_url": logo_url},
        )
    except HTTPException as error:
        if error.status_code == 400 and "logo_url" in str(error.detail):
            raise HTTPException(
                status_code=500,
                detail=(
                    "The logo was saved to the bucket, but the shops table has "
                    "no logo_url column. Run the latest backend/supabase/schema.sql "
                    "migration in Supabase."
                ),
            ) from error
        raise
    if not rows:
        raise HTTPException(status_code=404, detail="Shop not found.")
    _shop_cache[user["id"]] = rows[0]
    return {"logo_url": logo_url}


EXPENSE_CATEGORIES = (
    "Salaries", "Rent", "Food", "Transport", "Utilities", "GRZ Taxes", "Other"
)


@app.get("/expenses")
async def list_expenses(
    start_date: date = Query(),
    end_date: date = Query(),
    user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
    _: None = Depends(require_owner),
) -> list[dict[str, Any]]:
    shop = await _owned_shop(user, token)
    return await _table(
        "GET",
        "expenses",
        token,
        params={
            "select": "*",
            "shop_id": f"eq.{shop['id']}",
            "and": f"(spent_on.gte.{start_date},spent_on.lte.{end_date})",
            "order": "spent_on.desc",
        },
    )


@app.post("/expenses")
async def create_expense(
    data: ExpenseCreate,
    user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
    _: None = Depends(require_owner),
) -> dict[str, Any]:
    shop = await _owned_shop(user, token)
    rows = await _table(
        "POST",
        "expenses",
        token,
        params={"select": "*"},
        body={
            "shop_id": shop["id"],
            "category": data.category,
            "amount": str(data.amount),
            "note": data.note.strip(),
            "payment_method": data.payment_method.strip(),
            "spent_on": (data.spent_on or date.today()).isoformat(),
        },
    )
    if not rows:
        raise HTTPException(status_code=502, detail="Supabase did not save the expense.")
    return rows[0]


@app.patch("/expenses/{expense_id}")
async def update_expense(
    expense_id: str,
    data: ExpenseUpdate,
    user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
    _: None = Depends(require_owner),
) -> dict[str, Any]:
    shop = await _owned_shop(user, token)
    updates = data.model_dump(exclude_unset=True, mode="json")
    if "payment_method" in updates and updates["payment_method"] is not None:
        updates["payment_method"] = updates["payment_method"].strip()
    if not updates:
        raise HTTPException(status_code=422, detail="Provide at least one expense field.")
    rows = await _table(
        "PATCH",
        "expenses",
        token,
        params={"id": f"eq.{expense_id}", "shop_id": f"eq.{shop['id']}", "select": "*"},
        body=updates,
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Expense not found.")
    return rows[0]


@app.delete("/expenses/{expense_id}")
async def delete_expense(
    expense_id: str,
    user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
    _: None = Depends(require_owner),
) -> dict[str, bool]:
    shop = await _owned_shop(user, token)
    rows = await _table(
        "DELETE",
        "expenses",
        token,
        params={"id": f"eq.{expense_id}", "shop_id": f"eq.{shop['id']}", "select": "id"},
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Expense not found.")
    return {"deleted": True}


@app.get("/employees")
async def list_employees(
    user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
    _: None = Depends(require_owner),
) -> list[dict[str, Any]]:
    """Employees of this shop (shop_users rows joined with their shop)."""
    shop = await _owned_shop(user, token)
    return await _table(
        "GET",
        "shop_users",
        token,
        params={
            "select": "id,user_id,role,display_name,login_email,created_at",
            "shop_id": f"eq.{shop['id']}",
            "order": "created_at.asc",
        },
    )


@app.post("/employees")
async def create_employee(
    data: EmployeeCreate,
    user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
    _: None = Depends(require_owner),
) -> dict[str, Any]:
    """Creates a Supabase auth user with the employee role for this shop.

    Staff may reuse the company email used by the owner, so when Supabase
    rejects the address as already registered the login is created under a
    unique internal address and still signs in with the company email.
    """
    shop = await _owned_shop(user, token)

    async def _create(auth_email: str) -> dict[str, Any]:
        return await supabase_request(
            "POST",
            "/auth/v1/admin/users",
            admin=True,
            body={
                "email": auth_email,
                "password": data.password,
                "email_confirm": True,
                "user_metadata": {
                    "shop_id": shop["id"],
                    "role": "employee",
                    "display_name": data.display_name,
                    "login_email": data.email,
                },
            },
        )

    auth_email = data.email
    try:
        payload = await _create(auth_email)
    except HTTPException as error:
        if error.status_code >= 500:
            raise
        auth_email = _staff_auth_email(data.email)
        payload = await _create(auth_email)
    if not isinstance(payload, dict) or not payload.get("id"):
        raise HTTPException(status_code=502, detail="Supabase did not create the employee.")
    rows = await _table(
        "POST",
        "shop_users",
        token,
        params={"select": "*"},
        body={
            "shop_id": shop["id"],
            "user_id": payload["id"],
            "role": "employee",
            "display_name": data.display_name,
            "login_email": data.email,
            "auth_email": auth_email,
        },
    )
    if not rows:
        raise HTTPException(status_code=502, detail="Supabase did not save the employee.")
    return rows[0]


@app.delete("/employees/{employee_id}")
async def delete_employee(
    employee_id: str,
    user: dict[str, Any] = Depends(current_user),
    token: str = Depends(_bearer_token),
    _: None = Depends(require_owner),
) -> dict[str, bool]:
    shop = await _owned_shop(user, token)
    rows = await _table(
        "GET",
        "shop_users",
        token,
        params={
            "select": "id,user_id",
            "id": f"eq.{employee_id}",
            "shop_id": f"eq.{shop['id']}",
            "role": "eq.employee",
            "limit": "1",
        },
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Employee not found.")
    try:
        await supabase_request(
            "DELETE",
            f"/auth/v1/admin/users/{rows[0]['user_id']}",
            admin=True,
        )
    except HTTPException:
        pass  # keep the row removal authoritative even if auth cleanup fails
    await _table(
        "DELETE",
        "shop_users",
        token,
        params={"id": f"eq.{employee_id}", "shop_id": f"eq.{shop['id']}", "select": "id"},
    )
    return {"deleted": True}

import unittest
from unittest.mock import patch

from fastapi.testclient import TestClient

from backend.app import main


USER_ID = "00000000-0000-0000-0000-000000000099"
SHOP_ID = "00000000-0000-0000-0000-000000000010"
PRODUCT_ID = "00000000-0000-0000-0000-000000000001"

USER = {
    "id": USER_ID,
    "email": "owner@example.com",
    "user_metadata": {
        "shop_name": "Test Shop",
        "owner_name": "Test Owner",
        "location": "Lusaka",
        "business_type": "Boutique",
    },
}
SHOP = {
    "id": SHOP_ID,
    "owner_id": USER_ID,
    "name": "Test Shop",
    "owner_name": "Test Owner",
    "phone": "",
    "location": "Lusaka",
    "business_type": "Boutique",
}


class ApiTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(main.app)
        main.app.dependency_overrides[main.current_user] = lambda: USER
        main.app.dependency_overrides[main._bearer_token] = lambda: "test-token"

    def tearDown(self) -> None:
        main.app.dependency_overrides.clear()
        self.client.close()

    def test_health_does_not_require_supabase_credentials(self) -> None:
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "ok"})

    def test_auth_confirmation_page_prompts_user_to_return_to_app(self) -> None:
        response = self.client.get("/auth/confirmed")
        self.assertEqual(response.status_code, 200)
        self.assertIn("text/html", response.headers["content-type"])
        self.assertIn("Return to Malonda Yanga", response.text)

    def test_password_recovery_page_accepts_new_password(self) -> None:
        response = self.client.get("/auth/recovery")
        self.assertEqual(response.status_code, 200)
        self.assertIn("/auth/password", response.text)
        self.assertIn("Update password", response.text)

    def test_register_handles_email_confirmation_without_session(self) -> None:
        async def fake_request(method, path, **kwargs):
            self.assertEqual(path, "/auth/v1/signup")
            self.assertEqual(
                kwargs["params"]["redirect_to"],
                main.get_settings().auth_redirect_url,
            )
            self.assertEqual(kwargs["body"]["data"]["shop_name"], "Test Shop")
            return {"id": USER_ID, "email": "owner@example.com"}

        with patch.object(main, "supabase_request", side_effect=fake_request):
            response = self.client.post(
                "/auth/register",
                json={
                    "shop_name": "Test Shop",
                    "owner_name": "Test Owner",
                    "email": "owner@example.com",
                    "password": "secure-pass-123",
                    "location": "Lusaka",
                    "business_type": "Boutique",
                },
            )

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()["requires_email_confirmation"])
        self.assertIsNone(response.json()["shop"])

    def test_login_returns_session_and_shop(self) -> None:
        async def fake_request(method, path, **kwargs):
            if path == "/auth/v1/token":
                return {
                    "user": USER,
                    "access_token": "access",
                    "refresh_token": "refresh",
                }
            if path == "/rest/v1/shops":
                self.assertEqual(kwargs["token"], "access")
                return [SHOP]
            self.fail(f"Unexpected Supabase request: {path}")

        with patch.object(main, "supabase_request", side_effect=fake_request):
            response = self.client.post(
                "/auth/login",
                json={"email": "owner@example.com", "password": "secure-pass-123"},
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["shop"]["id"], SHOP_ID)
        self.assertEqual(response.json()["access_token"], "access")
        self.assertFalse(response.json()["requires_email_confirmation"])

    def test_supplier_create_scopes_insert_to_signed_in_shop(self) -> None:
        async def fake_request(method, path, **kwargs):
            if path == "/rest/v1/shops":
                return [SHOP]
            if path == "/rest/v1/suppliers":
                self.assertEqual(method, "POST")
                self.assertEqual(kwargs["body"]["shop_id"], SHOP_ID)
                self.assertEqual(kwargs["body"]["name"], "Textile House")
                return [{"id": "supplier-id", **kwargs["body"]}]
            self.fail(f"Unexpected Supabase request: {path}")

        with patch.object(main, "supabase_request", side_effect=fake_request):
            response = self.client.post(
                "/suppliers",
                json={
                    "name": "  Textile House  ",
                    "contact_name": "A. Supplier",
                    "phone": "+260 97 000 0000",
                },
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["name"], "Textile House")
        self.assertEqual(response.json()["shop_id"], SHOP_ID)

    def test_supplier_update_and_delete_are_shop_scoped(self) -> None:
        async def fake_request(method, path, **kwargs):
            if path == "/rest/v1/shops":
                return [SHOP]
            if path == "/rest/v1/suppliers":
                self.assertEqual(kwargs["params"]["shop_id"], f"eq.{SHOP_ID}")
                if method == "PATCH":
                    self.assertEqual(kwargs["body"]["phone"], "+260 97 000 0001")
                    return [{"id": "supplier-id", "phone": "+260 97 000 0001"}]
                if method == "DELETE":
                    return [{"id": "supplier-id"}]
            self.fail(f"Unexpected Supabase request: {method} {path}")

        with patch.object(main, "supabase_request", side_effect=fake_request):
            updated = self.client.patch(
                "/suppliers/supplier-id",
                json={"phone": "+260 97 000 0001"},
            )
            deleted = self.client.delete("/suppliers/supplier-id")

        self.assertEqual(updated.status_code, 200)
        self.assertEqual(deleted.status_code, 200)
        self.assertTrue(deleted.json()["deleted"])

    def test_product_image_upload_is_scoped_to_owned_product(self) -> None:
        image_url = (
            f"{main.get_settings().supabase_url}/storage/v1/object/public/"
            f"product-images/{SHOP_ID}/{PRODUCT_ID}.png"
        )

        async def fake_request(method, path, **kwargs):
            if path == "/rest/v1/shops":
                return [SHOP]
            if path == "/rest/v1/products" and method == "GET":
                return [{"id": PRODUCT_ID}]
            if path == "/rest/v1/products" and method == "PATCH":
                self.assertEqual(kwargs["body"]["image_url"], image_url)
                return [{"id": PRODUCT_ID}]
            self.fail(f"Unexpected Supabase request: {method} {path}")

        async def fake_upload(path, **kwargs):
            self.assertEqual(path, f"product-images/{SHOP_ID}/{PRODUCT_ID}.png")
            self.assertEqual(kwargs["content"], b"test-image")

        with (
            patch.object(main, "supabase_request", side_effect=fake_request),
            patch.object(main, "supabase_upload", side_effect=fake_upload),
        ):
            response = self.client.put(
                f"/products/{PRODUCT_ID}/image",
                json={
                    "content_type": "image/png",
                    "image_base64": "dGVzdC1pbWFnZQ==",
                },
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["image_url"], image_url)

    def test_create_sale_uses_transactional_supabase_rpc(self) -> None:
        async def fake_request(method, path, **kwargs):
            if path == "/rest/v1/shops":
                return [SHOP]
            if path == "/rest/v1/rpc/create_shop_sale":
                self.assertEqual(kwargs["body"]["p_shop_id"], SHOP_ID)
                self.assertEqual(kwargs["body"]["p_items"][0]["product_id"], PRODUCT_ID)
                return {
                    "id": "sale-id",
                    "subtotal": 240,
                    "discount": 24,
                    "total": 216,
                    "payment_method": "Cash",
                }
            self.fail(f"Unexpected Supabase request: {path}")

        with patch.object(main, "supabase_request", side_effect=fake_request):
            response = self.client.post(
                "/sales",
                json={
                    "discount_percent": 10,
                    "payment_method": "Cash",
                    "items": [{"product_id": PRODUCT_ID, "quantity": 2}],
                },
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["total"], 216)

    def test_delete_sale_is_scoped_to_signed_in_shop(self) -> None:
        async def fake_request(method, path, **kwargs):
            if path == "/rest/v1/shops":
                return [SHOP]
            if path == "/rest/v1/sales":
                self.assertEqual(method, "DELETE")
                self.assertEqual(kwargs["params"]["id"], "eq.sale-id")
                self.assertEqual(kwargs["params"]["shop_id"], f"eq.{SHOP_ID}")
                return [{"id": "sale-id"}]
            self.fail(f"Unexpected Supabase request: {method} {path}")

        with patch.object(main, "supabase_request", side_effect=fake_request):
            response = self.client.delete("/sales/sale-id")

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()["deleted"])

    def test_reports_aggregate_selected_shop_sales_and_cost(self) -> None:
        async def fake_request(method, path, **kwargs):
            if path == "/rest/v1/shops":
                return [SHOP]
            if path == "/rest/v1/sales":
                return [
                    {
                        "id": "sale-id",
                        "sold_at": "2026-11-09T08:00:00+00:00",
                        "total": 240,
                        "discount": 24,
                        "payment_method": "Cash",
                    }
                ]
            if path == "/rest/v1/sale_items":
                return [
                    {
                        "sale_id": "sale-id",
                        "product_id": PRODUCT_ID,
                        "product_name": "T-Shirt",
                        "quantity": 2,
                        "unit_price": 120,
                        "unit_cost": 80,
                    }
                ]
            if path == "/rest/v1/products":
                return [
                    {
                        "id": PRODUCT_ID,
                        "name": "T-Shirt",
                        "category": "T-Shirts",
                        "quantity": 8,
                    }
                ]
            if path == "/rest/v1/expenses":
                return []
            self.fail(f"Unexpected Supabase request: {path}")

        with patch.object(main, "supabase_request", side_effect=fake_request):
            response = self.client.get(
                "/reports",
                params={"start_date": "2026-11-09", "end_date": "2026-11-09"},
            )

        self.assertEqual(response.status_code, 200)
        report = response.json()
        self.assertEqual(report["total_sales"], 240)
        self.assertEqual(report["total_cost"], 160)
        self.assertEqual(report["total_discounts"], 24)
        self.assertEqual(report["net_profit"], 80)
        self.assertEqual(report["top_products"][0]["quantity"], 2)

    def test_login_rejects_malformed_email(self) -> None:
        response = self.client.post(
            "/auth/login",
            json={"email": "not-an-email", "password": "secure-pass-123"},
        )
        self.assertEqual(response.status_code, 422)


if __name__ == "__main__":
    unittest.main()

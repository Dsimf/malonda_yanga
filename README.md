# Malonda Yanga

Malonda Yanga is a Flutter shop-management app backed by a FastAPI service and
Supabase Auth/Postgres.

## Configure Supabase

1. Create a Supabase project and enable **Authentication → Providers → Email**.
2. Run [`backend/supabase/schema.sql`](backend/supabase/schema.sql) in the
   Supabase SQL Editor. It creates the shop, product, supplier, sale, and
   sale-item tables, enables row-level security, adds owner-only policies, and installs the
   transactional `create_shop_sale` function. If you already created these
   tables, run the script again to add/update its policies and function; it
   does not drop tables or sale records.
3. Copy `backend/.env.example` to `backend/.env` and set your project URL and
   publishable (or legacy anon) key from **Project Settings → API**. Use the
   project root URL, not a `/rest/v1` URL. The service-role/secret key is not
   needed by this app and must never be placed in Flutter or committed.
4. In **Authentication → URL Configuration → Redirect URLs**, add
   `http://192.168.8.101:8000/auth/confirmed` and
   `http://192.168.8.101:8000/auth/recovery`. The backend uses these as the
   defaults for `AUTH_REDIRECT_URL` and `AUTH_RECOVERY_REDIRECT_URL`; if you
   override them in `backend/.env`, allow those exact URLs. This is the
   laptop's current Wi-Fi IP; if it changes, update both places. The recovery
   page accepts a new password from the Supabase recovery link.

## Start the Python API

From the project root in PowerShell:

```powershell
Set-Location backend
Copy-Item .env.example .env
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python -m uvicorn app.main:app --reload --host 0.0.0.0
```

Keep this terminal open while using the app. Check the API at
`http://localhost:8000/health`; interactive API docs are at
`http://localhost:8000/docs`.

## Run Flutter

From another terminal at the project root. Android builds default to
`http://192.168.8.101:8000` for the current development Wi-Fi network; desktop
builds default to `http://localhost:8000`:

```powershell
flutter run
```

For Android, change that default to your computer's current LAN IP when it
changes. Or set it when running Flutter, and keep both devices on the same
network:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000
```

Replace the example address with the computer's actual LAN IP. Configure
`CORS_ORIGINS` in the backend environment to include the Flutter web
development origin when using a browser.

New shop registration uses email and password. If email confirmation is
enabled in Supabase, the confirmation email redirects to the configured API
confirmation page instead of `localhost`. After confirming, return to the app
and sign in. Links already sent before this redirect was configured may still
point to the old URL; register again or resend the confirmation after applying
the new configuration. If the pending account prevents registering with the
same email, use Supabase's resend-confirmation option or another email for
testing. The backend verifies each Supabase access token;
database requests use the signed-in user's token and are restricted by RLS.

On Windows, enable Developer Mode if Flutter reports that plugin symlink
support is required, and ensure Git for Windows is installed and available on
`PATH`.

## Run tests

From the project root:

```powershell
backend\.venv\Scripts\python.exe -m unittest backend.tests.test_api
flutter test
```

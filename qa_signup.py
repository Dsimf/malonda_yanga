import json, urllib.request

BASE = "https://ceqxnujtapdkhomhiiby.supabase.co"
KEY = "sb_publishable_ze1rjVQKXci6LgelzDG1oA_ydGUBSF1"

email = "qa.e2e.direct.1794991900@gmail.com"
r = urllib.request.Request(BASE + "/auth/v1/signup", data=json.dumps({
    "email": email, "password": "QaPass12345!",
    "data": {"shop_name": "QA Direct Shop", "owner_name": "QA Tester",
             "location": "Lusaka", "business_type": "Retail", "phone": "0977000000"},
}).encode(), method="POST")
r.add_header("apikey", KEY)
r.add_header("Content-Type", "application/json")
try:
    with urllib.request.urlopen(r, timeout=60) as resp:
        out = json.loads(resp.read())
except urllib.error.HTTPError as e:
    print("STATUS", e.code, e.read().decode()[:300]); raise SystemExit(1)

tok = out.get("access_token")
print("HAS_SESSION:", tok is not None, "| email_confirmed:", (out.get("user") or {}).get("email_confirmed_at") is not None)
if tok:
    open("qa_token.txt", "w").write(tok)
    print("TOKEN_SAVED")

import json, urllib.request, sys, time

BASE = "https://malonda-yanga.onrender.com"
# Temporary shared test account (email-confirmed) OR pass email/password on argv
EMAIL = sys.argv[1] if len(sys.argv) > 2 else None
PASSWORD = sys.argv[2] if len(sys.argv) > 2 else None
if not EMAIL:
    EMAIL = input("email: ").strip()
    PASSWORD = input("password: ").strip()

def req(method, path, token=None, payload=None):
    body = json.dumps(payload).encode() if payload is not None else None
    r = urllib.request.Request(BASE + path, data=body, method=method)
    r.add_header("Content-Type", "application/json")
    if token:
        r.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(r, timeout=90) as resp:
            return resp.status, json.loads(resp.read() or b"null")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"null")

status, login = req("POST", "/auth/login", payload={"email": EMAIL, "password": PASSWORD})
tok = (login or {}).get("access_token")
if not tok:
    print("LOGIN:", status, json.dumps(login)[:300]); sys.exit("No token")
print("LOGIN OK")
open("qa_token.txt", "w").write(tok)

status, me = req("GET", "/auth/me", token=tok)
print("ME:", status, json.dumps(me)[:300])

status, prod = req("POST", "/products", token=tok, payload={
    "name": "QA T-Shirt", "sku": f"QA-{int(time.time())}", "category": "T-Shirts", "price": 120, "cost": 80, "quantity": 50,
})
print("CREATE PRODUCT:", status, json.dumps(prod)[:300])
pid = (prod or {}).get("id")
if not pid:
    sys.exit("No product id")

status, sale = req("POST", "/sales", token=tok, payload={
    "discount_percent": 0, "discount_type": "percent", "discount_value": 0,
    "payment_method": "Cash", "sale_type": "Walk-in",
    "items": [{"product_id": pid, "quantity": 2}],
})
print("CREATE SALE:", status, json.dumps(sale)[:300])

today = time.strftime("%Y-%m-%d")
status, report = req("GET", f"/reports?start_date={today}&end_date={today}", token=tok)
if status == 200:
    keys = ["total_sales","total_cost","sale_count","gross_profit","net_profit","payment_totals","daily_totals","top_products"]
    print("REPORT:", status, json.dumps({k: report.get(k) for k in keys}))
else:
    print("REPORT:", status, json.dumps(report)[:300])

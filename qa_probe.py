import json, urllib.request

BASE = "https://ceqxnujtapdkhomhiiby.supabase.co"
KEY = "sb_publishable_ze1rjVQKXci6LgelzDG1oA_ydGUBSF1"
TOKEN = open("qa_token.txt").read().strip()
SHOP = "4efa98c2-eea3-400d-b0d8-e3e1434dab48"
PROD = "3f401124-eb02-411a-8908-03f5d86a5af8"

def rpc(args):
    r = urllib.request.Request(BASE + "/rest/v1/rpc/create_shop_sale",
        data=json.dumps(args).encode(), method="POST")
    r.add_header("apikey", KEY)
    r.add_header("Authorization", "Bearer " + TOKEN)
    r.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(r, timeout=60) as resp:
            return resp.status, resp.read().decode()[:200]
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:400]

# Probe A: the old 4-arg signature (shop, discount_percent, payment_method, items)
print("A(4 args):", rpc({"p_shop_id": SHOP, "p_discount_percent": 0,
    "p_payment_method": "Cash", "p_items": [{"product_id": PROD, "quantity": 1}]}))
# Probe B: old + layby/customer (7 args)
print("B(7 args):", rpc({"p_shop_id": SHOP, "p_discount_percent": 0,
    "p_payment_method": "Cash", "p_items": [{"product_id": PROD, "quantity": 1}],
    "p_layby_deposit": 0, "p_customer_name": "", "p_customer_phone": ""}))

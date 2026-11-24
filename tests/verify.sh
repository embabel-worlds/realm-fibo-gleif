#!/bin/sh
# The battery for realm-fibo-gleif: every view, re-checked against GLEIF and OFAC directly.
#
#   APPLIANCE=http://127.0.0.1:11043 AUTH=user:pass sh tests/verify.sh
#
# GLEIF and OFAC's list service are open and keyless; no source key is needed. The anchors are
# Apple Inc. (HWUPKR0MPOU8FGXBT394), its Irish subsidiary Apple Operations International
# (549300G81RQKP7XW2N18) and the watch list in reference/counterparties.yml.
#
#   L1  every view answers by name (the LEI views on the anchors above)
#   L2  subsidiaries, the chain's top and the consolidation record equal GLEIF's own answers;
#       the watch list's expected exposures hold
#   L3  cost: a direct-subsidiary read is at most two GLEIF calls, and a repeat is free
#
# The last line is exactly `ALL CHECKS PASS` when everything holds; any failure exits 1.
exec python3 - "$@" <<'PY'
import base64, json, os, sys, urllib.request

APPLIANCE = os.environ.get("APPLIANCE", "http://127.0.0.1:11043").rstrip("/")
AUTH = os.environ.get("AUTH") or os.environ.get("EMBABEL_AUTH") or sys.exit("set AUTH=user:pass")
HDR = {"Authorization": "Basic " + base64.b64encode(AUTH.encode()).decode(), "Content-Type": "application/json"}
GLEIF = "https://api.gleif.org/api/v1/lei-records/"
APPLE, AOI = "HWUPKR0MPOU8FGXBT394", "549300G81RQKP7XW2N18"
fail = 0

def check(name, ok, detail=""):
    global fail
    print(("  ok   " if ok else "  FAIL ") + name + (("  (" + str(detail) + ")") if detail != "" else ""))
    if not ok: fail = 1

def invoke(name, args=None):
    req = urllib.request.Request(APPLIANCE + "/api/v1/views/%s/invoke" % name,
                                 json.dumps({"args": args or {}}).encode(), HDR, method="POST")
    with urllib.request.urlopen(req, timeout=600) as r:
        v = json.load(r)
    if v.get("status") != "SUCCEEDED":
        raise SystemExit("view %s: %s %s" % (name, v.get("status"), json.dumps(v.get("error"))))
    return v

def calls(env): return (env.get("metrics") or {}).get("externalCalls")

def gleif(path):
    try:
        with urllib.request.urlopen(GLEIF + path, timeout=60) as r: return json.load(r)
    except urllib.error.HTTPError as e:
        if e.code == 404: return None
        raise

print("== L3: cost (measured first, while the cache may still be cold) ==")
sub1 = invoke("SubsidiariesOf", {"lei": APPLE})
check("SubsidiariesOf(Apple) costs at most two GLEIF calls (the entity, one page of children)",
      calls(sub1) is not None and calls(sub1) <= 2, "%s calls" % calls(sub1))
sub2 = invoke("SubsidiariesOf", {"lei": APPLE})
check("a repeat is answered from the cache", calls(sub2) == 0, "%s calls" % calls(sub2))

print("== L1: every view answers by name ==")
V = {}
for name, args in [("ControlChainOf", {"lei": AOI}), ("ConsolidationEvidenceOf", {"lei": AOI}),
                   ("SubsidiariesOf", {"lei": APPLE}), ("SanctionsExposureOf", {"lei": AOI}),
                   ("CounterpartyExposure", {}), ("CounterpartyControlChains", {})]:
    V[name] = invoke(name, args).get("data") or []
    check("%s answers" % name, len(V[name]) > 0, "%d rows" % len(V[name]))

print("== L2: GLEIF itself agrees ==")
kids = []
page = 1
while True:
    d = gleif("%s/direct-children?page%%5Bsize%%5D=200&page%%5Bnumber%%5D=%d" % (APPLE, page))
    kids += [x["id"] for x in (d or {}).get("data") or []]
    if not d or page >= d["meta"]["pagination"]["lastPage"]: break
    page += 1
check("Apple's direct subsidiaries = GLEIF's direct-children", sorted(r["lei"] for r in V["SubsidiariesOf"]) == sorted(kids),
      "%d vs %d" % (len(V["SubsidiariesOf"]), len(kids)))
top = (gleif(AOI + "/ultimate-parent") or {}).get("data", {}).get("id")
chain = V["ControlChainOf"][0]
check("the chain's top = GLEIF's ultimate parent", chain["ultimateParentLei"] == top, "%s vs %s" % (chain["ultimateParentLei"], top))
rel = (gleif(AOI + "/direct-parent-relationship") or {}).get("data", {}).get("attributes", {})
ev = V["ConsolidationEvidenceOf"][0]
check("the consolidation record names GLEIF's direct parent",
      ev["consolidatedBy"] == rel.get("relationship", {}).get("endNode", {}).get("id"), ev["consolidatedBy"])
check("its corroboration level = GLEIF's", ev["corroboration"] == rel.get("registration", {}).get("corroborationLevel"), ev["corroboration"])
exp = {r["lei"]: r["exposed"] for r in V["CounterpartyExposure"]}
check("Apple Operations International is clean", exp.get(AOI) is False, exp.get(AOI))
check("Rosneft Deutschland is exposed (its parent's GLEIF names are OFAC aliases)", exp.get("391200PKEUF3Y2NUMW25") is True,
      exp.get("391200PKEUF3Y2NUMW25"))
check("both watch-list views cover the same counterparties",
      sorted(exp) == sorted(r["lei"] for r in V["CounterpartyControlChains"]))

if fail:
    print("FAILED"); sys.exit(1)
print("ALL CHECKS PASS")
PY

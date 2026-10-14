"""Minimal App Store Connect API client (stdlib + openssl). Never prints the key or the token."""
import base64, json, os, subprocess, sys, time, urllib.request, urllib.error

KEY_ID = "SWPDDR9U3Z"
KEY_PATH = os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8")
ISSUER = os.environ.get("ASC_ISSUER_ID")  # None for individual keys
BASE = "https://api.appstoreconnect.apple.com"


def b64(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def der_to_raw(der: bytes) -> bytes:
    # ECDSA DER (SEQUENCE of two INTEGERs) -> r||s, 32 bytes each
    i = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)
    assert der[i] == 0x02
    rl = der[i + 1]; r = der[i + 2:i + 2 + rl]; i += 2 + rl
    assert der[i] == 0x02
    sl = der[i + 1]; s = der[i + 2:i + 2 + sl]
    return r.lstrip(b"\0").rjust(32, b"\0") + s.lstrip(b"\0").rjust(32, b"\0")


def token() -> str:
    header = {"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}
    payload = {"aud": "appstoreconnect-v1", "exp": int(time.time()) + 15 * 60}
    if ISSUER:
        payload["iss"] = ISSUER
    else:
        payload["sub"] = "user"
    signing = f"{b64(json.dumps(header).encode())}.{b64(json.dumps(payload).encode())}"
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", KEY_PATH],
                         input=signing.encode(), capture_output=True, check=True).stdout
    return f"{signing}.{b64(der_to_raw(der))}"


def call(method, path, body=None, raw_url=None, headers=None, data=None):
    url = raw_url or (BASE + path)
    h = dict(headers or {})
    if not raw_url:
        h["Authorization"] = f"Bearer {token()}"
    if body is not None:
        data = json.dumps(body).encode(); h["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, method=method, headers=h)
    try:
        with urllib.request.urlopen(req) as r:
            txt = r.read()
            return r.status, (json.loads(txt) if txt and not raw_url else txt)
    except urllib.error.HTTPError as e:
        txt = e.read()
        try: return e.code, json.loads(txt)
        except Exception: return e.code, txt.decode(errors="replace")[:500]


VERSION_ID = "d1dd9500-b8d7-41b5-b6f0-01ada5d246d5"
SHOTS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "app-store-assets", "screenshots")
SETS = {"APP_IPHONE_67": "iphone", "APP_IPAD_PRO_3GEN_129": "ipad"}
FILES = ["01-library.png", "02-recorder.png", "03-player.png"]


def ok(st, j, what):
    if st >= 300:
        sys.exit(f"FAILED {what}: {st} {json.dumps(j)[:700]}")
    return j


def upload_one(set_id, path):
    import hashlib
    data = open(path, "rb").read()
    name = os.path.basename(path)
    j = ok(*call("POST", "/v1/appScreenshots", {"data": {
        "type": "appScreenshots",
        "attributes": {"fileName": name, "fileSize": len(data)},
        "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}}}),
        f"reserve {name}")["data"]
    for op in j["attributes"]["uploadOperations"]:
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        hdrs = {h["name"]: h["value"] for h in op["requestHeaders"]}
        st, r = call(op["method"], None, raw_url=op["url"], headers=hdrs, data=chunk)
        ok(st, r, f"put chunk {name}")
    ok(*call("PATCH", f"/v1/appScreenshots/{j['id']}", {"data": {
        "type": "appScreenshots", "id": j["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}}),
       f"commit {name}")
    return j["id"]


def upload_all():
    locs = ok(*call("GET", f"/v1/appStoreVersions/{VERSION_ID}/appStoreVersionLocalizations?limit=50"),
              "list localizations")["data"]
    wanted = {"es-ES", "de-DE", "it", "pt-BR", "en-US", "fr-FR"}
    for loc in locs:
        code = loc["attributes"]["locale"]
        if code not in wanted:
            continue
        sets = ok(*call("GET", f"/v1/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets"),
                  f"list sets {code}")["data"]
        by_type = {s["attributes"]["screenshotDisplayType"]: s["id"] for s in sets}
        for dtype, folder in SETS.items():
            sid = by_type.get(dtype)
            if not sid:
                sid = ok(*call("POST", "/v1/appScreenshotSets", {"data": {
                    "type": "appScreenshotSets", "attributes": {"screenshotDisplayType": dtype},
                    "relationships": {"appStoreVersionLocalization": {"data": {
                        "type": "appStoreVersionLocalizations", "id": loc["id"]}}}}}),
                    f"create set {code} {dtype}")["data"]["id"]
                print(f"{code} {dtype}: set created")
            existing = ok(*call("GET", f"/v1/appScreenshotSets/{sid}/appScreenshots"),
                          f"list shots {code} {dtype}")["data"]
            if existing:
                print(f"{code} {dtype}: already has {len(existing)} screenshots, skipped")
                continue
            for f in FILES:
                upload_one(sid, os.path.join(SHOTS, folder, f))
            print(f"{code} {dtype}: uploaded {len(FILES)}")


def report():
    locs = ok(*call("GET", f"/v1/appStoreVersions/{VERSION_ID}/appStoreVersionLocalizations?limit=50"),
              "list localizations")["data"]
    for loc in locs:
        sets = ok(*call("GET", f"/v1/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets"),
                  "sets")["data"]
        for s in sets:
            shots = ok(*call("GET", f"/v1/appScreenshotSets/{s['id']}/appScreenshots"), "shots")["data"]
            states = [x["attributes"]["assetDeliveryState"]["state"] for x in shots]
            print(loc["attributes"]["locale"], s["attributes"]["screenshotDisplayType"], states)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "ping"
    if cmd == "upload":
        upload_all()
    elif cmd == "report":
        report()
    elif cmd == "inspect":
        for label, path in [
            ("version", f"/v1/appStoreVersions/{VERSION_ID}"),
            ("appInfo", "/v1/appInfos/879ef6f4-75e9-425d-aca9-89f8a741c19e?include=primaryCategory,ageRatingDeclaration"),
            ("availability", "/v1/apps/6822712814/appAvailabilityV2?include=territoryAvailabilities&limit[territoryAvailabilities]=3"),
        ]:
            st, j = call("GET", path)
            print("==", label, st)
            if isinstance(j, dict):
                d = j.get("data", j)
                print(json.dumps(d.get("attributes", d.get("errors", d)) if isinstance(d, dict) else d, indent=1)[:900])
                for inc in j.get("included", [])[:4]:
                    print("  inc", inc["type"], inc["id"], json.dumps(inc.get("attributes", {}))[:700])
    elif cmd == "agecheck":
        st, j = call("GET", "/v1/appInfos/879ef6f4-75e9-425d-aca9-89f8a741c19e/ageRatingDeclaration")
        print(st, json.dumps(j.get("data", j).get("attributes", j), indent=0)[:2500] if isinstance(j, dict) else j)
        st, j = call("GET", "/v1/appInfos/879ef6f4-75e9-425d-aca9-89f8a741c19e?fields[appInfos]=primaryCategory,secondaryCategory")
        print(st, json.dumps(j.get("data", j).get("relationships", j))[:600] if isinstance(j, dict) else j)
        st, j = call("GET", "/v1/appCategories?filter[platforms]=IOS&limit=50")
        print(st, [c["id"] for c in j.get("data", [])] if isinstance(j, dict) else j)
        st, j = call("GET", "/v1/apps/6822712814/appPriceSchedule")
        print("price", st)
    elif cmd == "copyright":
        st, j = call("PATCH", f"/v1/appStoreVersions/{VERSION_ID}", {"data": {"type": "appStoreVersions", "id": VERSION_ID,
            "attributes": {"copyright": "2026 David Rodríguez"}}})
        print(st, json.dumps(j.get("data", j).get("attributes", j) if isinstance(j, dict) else j)[:400])
    elif cmd == "category":
        for c in ("PRODUCTIVITY", "UTILITIES"):
            st, j = call("GET", f"/v1/appCategories/{c}")
            print(c, st)
            if st >= 300: sys.exit(json.dumps(j)[:400])
        st, j = call("PATCH", "/v1/appInfos/879ef6f4-75e9-425d-aca9-89f8a741c19e", {"data": {"type": "appInfos",
            "id": "879ef6f4-75e9-425d-aca9-89f8a741c19e", "relationships": {
            "primaryCategory": {"data": {"type": "appCategories", "id": "PRODUCTIVITY"}},
            "secondaryCategory": {"data": {"type": "appCategories", "id": "UTILITIES"}}}}})
        print(st, json.dumps(j)[:400] if st >= 300 else "ok")
    elif cmd == "age":
        none = "NONE"
        attrs = {k: none for k in ["alcoholTobaccoOrDrugUseOrReferences", "contests", "gamblingSimulated", "gunsOrOtherWeapons",
                 "horrorOrFearThemes", "matureOrSuggestiveThemes", "medicalOrTreatmentInformation", "profanityOrCrudeHumor",
                 "sexualContentGraphicAndNudity", "sexualContentOrNudity", "violenceCartoonOrFantasy", "violenceRealistic",
                 "violenceRealisticProlongedGraphicOrSadistic"]}
        attrs.update({k: False for k in ["gambling", "lootBox", "messagingAndChat", "parentalControls", "advertising",
                      "unrestrictedWebAccess", "userGeneratedContent", "ageAssurance", "healthOrWellnessTopics"]})
        i = "879ef6f4-75e9-425d-aca9-89f8a741c19e"
        st, j = call("PATCH", f"/v1/ageRatingDeclarations/{i}", {"data": {"type": "ageRatingDeclarations", "id": i, "attributes": attrs}})
        print(st, json.dumps(j)[:900] if st >= 300 else "ok")
        if st < 300:
            print(json.dumps(j["data"]["attributes"]))
    elif cmd == "content-rights":
        st, j = call("PATCH", "/v1/apps/6822712814", {"data": {"type": "apps", "id": "6822712814",
            "attributes": {"contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"}}})
        print(st, json.dumps(j)[:600] if st >= 300 else j["data"]["attributes"].get("contentRightsDeclaration"))
    elif cmd == "submit-create":
        st, j = call("POST", "/v1/reviewSubmissions", {"data": {"type": "reviewSubmissions",
            "attributes": {"platform": "IOS"},
            "relationships": {"app": {"data": {"type": "apps", "id": "6822712814"}}}}})
        print(st, json.dumps(j)[:600] if st >= 300 else j["data"]["id"])
    elif cmd == "submit-item":
        sub = sys.argv[2]
        st, j = call("POST", "/v1/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems",
            "relationships": {"reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub}},
                              "appStoreVersion": {"data": {"type": "appStoreVersions", "id": VERSION_ID}}}}})
        print(st, json.dumps(j)[:900] if st >= 300 else j["data"]["id"])
    elif cmd == "submit-send":
        sub = sys.argv[2]
        st, j = call("PATCH", f"/v1/reviewSubmissions/{sub}", {"data": {"type": "reviewSubmissions", "id": sub,
            "attributes": {"submitted": True}}})
        print(st, json.dumps(j)[:900] if st >= 300 else j["data"]["attributes"]["state"])
    elif cmd == "builds":
        st, j = call("GET", "/v1/builds?filter[app]=6822712814&limit=5&sort=-uploadedDate")
        print(st, [(b["id"], b["attributes"]["version"], b["attributes"]["processingState"],
                    b["attributes"].get("usesNonExemptEncryption")) for b in j["data"]] if st < 300 else j)
    elif cmd == "attach":
        st, j = call("PATCH", f"/v1/appStoreVersions/{VERSION_ID}/relationships/build",
                     {"data": {"type": "builds", "id": "447b85eb-940f-4bf7-9704-668cdabb4f3b"}})
        print(st, json.dumps(j)[:600] if st >= 300 else "ok")
    elif cmd == "review":
        notes = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "review-notes.txt")).read().strip()
        attrs = {"contactFirstName": "David", "contactLastName": "Rodríguez", "contactPhone": "+34618635420",
                 "contactEmail": "drodriguez1703@gmail.com", "demoAccountRequired": False, "notes": notes}
        st, j = call("GET", f"/v1/appStoreVersions/{VERSION_ID}/appStoreReviewDetail")
        existing = j.get("data") if st < 300 and isinstance(j, dict) else None
        if existing:
            st, j = call("PATCH", f"/v1/appStoreReviewDetails/{existing['id']}", {"data": {
                "type": "appStoreReviewDetails", "id": existing["id"], "attributes": attrs}})
        else:
            st, j = call("POST", "/v1/appStoreReviewDetails", {"data": {"type": "appStoreReviewDetails",
                "attributes": attrs, "relationships": {"appStoreVersion": {"data": {
                    "type": "appStoreVersions", "id": VERSION_ID}}}}})
        print(st, json.dumps(j)[:600] if st >= 300 else "ok")
    elif cmd == "avail":
        st, j = call("GET", "/v1/territories?limit=200")
        ids = [t["id"] for t in j["data"]]
        print("territories", st, len(ids))
        inc = [{"type": "territoryAvailabilities", "id": f"${{t{n}}}", "attributes": {"available": True},
                "relationships": {"territory": {"data": {"type": "territories", "id": t}}}} for n, t in enumerate(ids)]
        body = {"data": {"type": "appAvailabilities", "attributes": {"availableInNewTerritories": True},
                "relationships": {"app": {"data": {"type": "apps", "id": "6822712814"}},
                "territoryAvailabilities": {"data": [{"type": "territoryAvailabilities", "id": x["id"]} for x in inc]}}},
                "included": inc}
        st, j = call("POST", "/v2/appAvailabilities", body)
        print(st, json.dumps(j)[:900] if st >= 300 else "ok")
    else:
        st, j = call("GET", "/v1/apps/6822712814?fields[apps]=name,bundleId")
        print(st, json.dumps(j.get("data", j), indent=1)[:600] if isinstance(j, dict) else j)

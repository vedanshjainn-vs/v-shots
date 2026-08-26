#!/usr/bin/env python3
"""
V Shots — AppLovin MAX setup automation (Phase 5)

Creates/verifies the MAX app + ad units + Google (AdMob) network wiring via
the AppLovin Management API, so the owner does NOT have to click through the
dashboard manually.

CREDENTIALS (server-side ONLY — never bundled into the app, never in .env):
  APPLOVIN_MAX_MANAGEMENT_KEY  Management API key (Account → General → Keys)
  or APPLOVIN_MAX_REPORT_KEY   Report/Management key with write permission

REQUIRED ENV:
  VSHOTS_ANDROID_PACKAGE   (default: com.vshots.live)
  VSHOTS_MAX_APP_NAME      (default: V Shots)

OPTIONAL ENV (connect the owner's AdMob demand through MAX's Google network):
  ADMOB_APP_ID             Google AdMob app ID (ca-app-pub-...~...)
  ADMOB_UNIT_NATIVE        NEW AdMob native ad unit (required for Google fill)
  ADMOB_UNIT_INTERSTITIAL  NEW AdMob interstitial ad unit
  ADMOB_UNIT_REWARDED      NEW AdMob rewarded ad unit
  ADMOB_UNIT_BANNER        NEW AdMob banner ad unit
  TEST_DEVICE_ID           AAID to register as a MAX test device

NOTES / BOUNDARIES (reported honestly):
  • The Management API creates ONE ad unit per app/platform/ad-format.
    V Shots uses ONE native unit for all four native placements
    (HOME/DISCOVERY/LIBRARY/SEARCH — AppLovin's own recommendation: a single
    unit per format; the app passes a per-request `placement` name for
    granular reporting). If you want separate native units later, create
    them in the dashboard UI (not possible via API).
  • A new MAX app may need account/app approval before live fill; TEST
    devices (added here) receive test ads immediately.
  • The SDK KEY (client key) is read from the dashboard (Account → General
    → Keys) — it is printed here for convenience if already known in env
    (APPLOVIN_MAX_SDK_KEY is accepted read-only and echoed, never written).

Usage:
  python3 scripts/max_setup.py
  # then set the GitHub secrets APPLOVIN_MAX_SDK_KEY + the unit IDs shown.
"""

import json
import os
import sys
import urllib.request

API_BASE = "https://o.applovin.com/mediation/v1"
PACKAGE = os.environ.get("VSHOTS_ANDROID_PACKAGE", "com.vshots.live")
APP_NAME = os.environ.get("VSHOTS_MAX_APP_NAME", "V Shots")

# (unit name, ad_type) — one unit per format (API allows one per format).
UNITS = [
    ("VSHOTS_HOME_NATIVE_01", "native"),          # all native placements
    ("VSHOTS_INTERSTITIAL_SESSION_BREAK_01", "interstitial"),
    ("VSHOTS_REWARDED_FEATURE_01", "rewarded_video"),
    ("VSHOTS_BANNER_HOME_01", "banner"),
]

# ad_type → env key of the NEW AdMob unit to attach via the Google network
ADMOB_UNIT_ENV = {
    "native": "ADMOB_UNIT_NATIVE",
    "interstitial": "ADMOB_UNIT_INTERSTITIAL",
    "rewarded_video": "ADMOB_UNIT_REWARDED",
    "banner": "ADMOB_UNIT_BANNER",
}


def key() -> str:
    k = (
        os.environ.get("APPLOVIN_MAX_MANAGEMENT_KEY")
        or os.environ.get("APPLOVIN_MAX_REPORT_KEY")
        or ""
    ).strip()
    if not k:
        sys.exit(
            "ERROR: set APPLOVIN_MAX_MANAGEMENT_KEY (or APPLOVIN_MAX_REPORT_KEY) "
            "in the environment. These are SERVER credentials — never put them "
            "in the app or .env."
        )
    return k


def req(method: str, path: str, body=None):
    url = f"{API_BASE}{path}"
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {key()}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(r, timeout=30) as resp:
            raw = resp.read().decode()
            return resp.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, {"raw": raw}


def find_app():
    status, data = req("GET", f"/app?package={PACKAGE}")
    if status != 200:
        return None
    for app in data or []:
        if app.get("package") == PACKAGE:
            return app
    return None


def find_unit(app_id: str, name: str, ad_type: str):
    status, data = req("GET", f"/ad_unit?app_id={app_id}")
    if status != 200:
        return None
    for u in data or []:
        if u.get("name") == name and u.get("ad_type") == ad_type:
            return u
    return None


def main():
    # 1) App
    app = find_app()
    if app:
        print(f"• MAX app exists: {app.get('name')} (id={app.get('id')})")
    else:
        status, data = req(
            "POST",
            "/app",
            {"name": APP_NAME, "package": PACKAGE, "os": "android"},
        )
        if status not in (200, 201):
            sys.exit(f"ERROR creating MAX app: HTTP {status}: {data}")
        app = data
        print(f"• MAX app created: {app.get('name')} (id={app.get('id')})")
    app_id = app["id"]

    admob_app_id = os.environ.get("ADMOB_APP_ID", "").strip()

    # 2) Ad units (one per format) + Google network wiring
    created = {}
    for name, ad_type in UNITS:
        unit = find_unit(app_id, name, ad_type)
        if unit:
            print(f"• ad unit exists: {name} ({ad_type}) id={unit.get('id')}")
        else:
            status, data = req(
                "POST",
                "/ad_unit",
                {"app_id": app_id, "name": name, "ad_type": ad_type},
            )
            if status not in (200, 201):
                sys.exit(f"ERROR creating ad unit {name}: HTTP {status}: {data}")
            unit = data
            print(f"• ad unit created: {name} ({ad_type}) id={unit.get('id')}")
        created[ad_type] = unit

        # 3) Google (AdMob) network on this unit (optional but needed for
        #    Google demand). The owner must create NEW AdMob units for MAX.
        admob_unit = os.environ.get(ADMOB_UNIT_ENV[ad_type], "").strip()
        if admob_app_id and admob_unit:
            settings = {
                "ad_network_settings": {
                    "google": {
                        "enabled": True,
                        "admob_app_id": admob_app_id,
                        "admob_id": admob_unit,
                    }
                }
            }
            status, data = req(
                "POST", f"/ad_unit/{unit['id']}", settings
            )
            if status in (200, 201):
                print(f"  • Google network attached to {name} (AdMob unit {admob_unit})")
            else:
                print(
                    f"  ! Google network attach failed for {name}: "
                    f"HTTP {status}: {data} — attach manually in dashboard."
                )
        else:
            print(f"  • Google network: skipped (set ADMOB_APP_ID + ADMOB_UNIT_* to enable)")

    # 4) Test device (MAX serves TEST ads to registered devices immediately)
    test_device = os.environ.get("TEST_DEVICE_ID", "").strip()
    if test_device:
        status, data = req(
            "POST",
            "/test_device",
            {
                "name": "v-shots-owner-test-device",
                "device_id": test_device,
                "disabled": False,
                "network": "APPLOVIN_NETWORK",
            },
        )
        if status in (200, 201):
            print(f"• test device registered: {test_device[:8]}…")
        else:
            print(f"! test device registration failed: HTTP {status}: {data}")
    else:
        print(
            "• test device: skipped — run the app once on your phone, grab the "
            "AAID from the MAX log (verbose logging is ON in debug builds), "
            "re-run with TEST_DEVICE_ID=<aaid>, or add it in the dashboard."
        )

    # 5) Output for the owner → GitHub secrets (client-safe values only)
    print("\n════════════════════════════════════════════════════════════")
    print("DONE. Set these GitHub secrets (Settings → Secrets → Actions):")
    print("════════════════════════════════════════════════════════════")
    sdk_key = os.environ.get("APPLOVIN_MAX_SDK_KEY", "").strip()
    print(f"  APPLOVIN_MAX_SDK_KEY                      = {sdk_key or '<from dashboard: Account → General → Keys>'}")
    native = created.get("native", {})
    inter = created.get("interstitial", {})
    rew = created.get("rewarded_video", {})
    ban = created.get("banner", {})
    # All four native placement keys accept the single native unit
    # (per-request `placement` name differentiates reporting).
    for env_key in (
        "APPLOVIN_MAX_UNIT_HOME_NATIVE_01",
        "APPLOVIN_MAX_UNIT_DISCOVERY_NATIVE_01",
        "APPLOVIN_MAX_UNIT_PLAYER_NATIVE_01",
    ):
        print(f"  {env_key:42s} = {native.get('id', '<native unit id>')}")
    print("  {:42s} = {}".format("APPLOVIN_MAX_UNIT_LIBRARY_NATIVE_01", native.get('id', '<native unit id>')))
    print("  {:42s} = {}".format("APPLOVIN_MAX_UNIT_SEARCH_NATIVE_01", native.get('id', '<native unit id>')))
    print(f"  APPLOVIN_MAX_UNIT_INTERSTITIAL_SESSION_BREAK_01 = {inter.get('id', '<interstitial unit id>')}")
    print(f"  APPLOVIN_MAX_UNIT_REWARDED_FEATURE_01          = {rew.get('id', '<rewarded unit id>')}")
    print(f"  APPLOVIN_MAX_UNIT_BANNER_HOME_01               = {ban.get('id', '<banner unit id>')}")
    print(
        "\nDo NOT put APPLOVIN_MAX_MANAGEMENT_KEY / REPORT_KEY / EVENT_KEY in "
        "GitHub secrets used by the app build — they are server-side only."
    )


if __name__ == "__main__":
    main()

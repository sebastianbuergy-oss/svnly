#!/usr/bin/env python3
"""Fail safely unless the Apple team has an enabled iPhone test device."""

from __future__ import annotations

import urllib.parse

from enable_apple_sign_in import create_token, request


def main() -> None:
    token = create_token()
    query = urllib.parse.urlencode(
        {
            "filter[platform]": "IOS",
            "filter[status]": "ENABLED",
            "fields[devices]": "deviceClass,status",
            "limit": "200",
        }
    )
    devices = request("GET", f"/devices?{query}", token).get("data", [])
    iphones = [
        device
        for device in devices
        if device.get("attributes", {}).get("deviceClass") == "IPHONE"
    ]
    if not iphones:
        raise RuntimeError(
            "IPHONE_UDID_REGISTRATION_REQUIRED: No enabled iPhone is registered "
            "for this Apple Developer team."
        )
    print(
        f"Apple Developer Portal contains {len(iphones)} enabled iPhone test "
        "device(s); no UDID is written to the build log."
    )


if __name__ == "__main__":
    main()

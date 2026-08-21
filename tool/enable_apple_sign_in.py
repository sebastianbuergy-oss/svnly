#!/usr/bin/env python3
"""Idempotently configure Sign in with Apple as a primary App ID."""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request

import jwt


API_ROOT = "https://api.appstoreconnect.apple.com/v1"
CAPABILITY_TYPE = "APPLE_ID_AUTH"
REQUIRED_SETTINGS = [
    {
        "key": "APPLE_ID_AUTH_APP_CONSENT",
        "options": [{"key": "PRIMARY_APP_CONSENT"}],
    }
]


def resolve_secret(name: str) -> str:
    value = os.environ.get(name, "")
    if value.startswith("@file:"):
        with open(value[6:], encoding="utf-8") as secret_file:
            return secret_file.read()
    if value.startswith("@env:"):
        return resolve_secret(value[5:])
    if "BEGIN PRIVATE KEY" in value and "\\n" in value:
        return value.replace("\\n", "\n")
    if not value:
        raise RuntimeError(f"Required Codemagic integration value {name} is missing")
    return value


def create_token() -> str:
    issuer_id = resolve_secret("APP_STORE_CONNECT_ISSUER_ID")
    key_id = resolve_secret("APP_STORE_CONNECT_KEY_IDENTIFIER")
    private_key = resolve_secret("APP_STORE_CONNECT_PRIVATE_KEY")
    now = int(time.time())
    return jwt.encode(
        {"iss": issuer_id, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
        private_key,
        algorithm="ES256",
        headers={"kid": key_id, "typ": "JWT"},
    )


def request(method: str, path: str, token: str, body: dict | None = None) -> dict:
    data = None if body is None else json.dumps(body).encode("utf-8")
    http_request = urllib.request.Request(
        f"{API_ROOT}{path}",
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(http_request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        details = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(
            f"Apple capability request failed ({error.code} {error.reason}): {details}"
        ) from error


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: enable_apple_sign_in.py BUNDLE_ID_RESOURCE_ID")

    bundle_resource_id = sys.argv[1]
    token = create_token()

    capabilities = request(
        "GET",
        f"/bundleIds/{bundle_resource_id}/bundleIdCapabilities",
        token,
    ).get("data", [])
    existing = next(
        (
            capability
            for capability in capabilities
            if capability.get("attributes", {}).get("capabilityType") == CAPABILITY_TYPE
        ),
        None,
    )

    if existing and existing.get("attributes", {}).get("settings") == REQUIRED_SETTINGS:
        print("Sign in with Apple is already configured as a primary App ID.")
        return

    attributes = {"settings": REQUIRED_SETTINGS}
    if existing:
        capability_id = existing["id"]
        payload = {
            "data": {
                "type": "bundleIdCapabilities",
                "id": capability_id,
                "attributes": attributes,
            }
        }
        request("PATCH", f"/bundleIdCapabilities/{capability_id}", token, payload)
        print("Updated Sign in with Apple primary App ID configuration.")
        return

    attributes["capabilityType"] = CAPABILITY_TYPE
    payload = {
        "data": {
            "type": "bundleIdCapabilities",
            "attributes": attributes,
            "relationships": {
                "bundleId": {
                    "data": {"type": "bundleIds", "id": bundle_resource_id}
                }
            },
        }
    }
    request("POST", "/bundleIdCapabilities", token, payload)
    print("Enabled Sign in with Apple as a primary App ID.")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Put the latest processed SVNLY build in an internal TestFlight group."""

from __future__ import annotations

import os
import urllib.parse

from enable_apple_sign_in import create_token, request


GROUP_NAME = "SVNLY Internal"


def query(parameters: dict[str, str]) -> str:
    return urllib.parse.urlencode(parameters)


def relationship_contains(path: str, resource_id: str, token: str) -> bool:
    resources = request("GET", path, token).get("data", [])
    return any(resource.get("id") == resource_id for resource in resources)


def add_relationship(path: str, resource_type: str, resource_id: str, token: str) -> None:
    payload = {"data": [{"type": resource_type, "id": resource_id}]}
    request("POST", path, token, payload)


def main() -> None:
    app_id = os.environ.get("APP_STORE_APPLE_ID", "").strip()
    if not app_id:
        raise RuntimeError("APP_STORE_APPLE_ID is required")

    token = create_token()

    builds = request(
        "GET",
        "/builds?"
        + query(
            {
                "filter[app]": app_id,
                "filter[processingState]": "VALID",
                "sort": "-uploadedDate",
                "limit": "1",
                "fields[builds]": "version,uploadedDate,processingState,expired",
            }
        ),
        token,
    ).get("data", [])
    if not builds:
        raise RuntimeError("No processed SVNLY TestFlight build was found")
    build = builds[0]
    build_id = build["id"]
    build_number = build.get("attributes", {}).get("version", "unknown")

    groups = request(
        "GET",
        f"/apps/{app_id}/betaGroups?"
        + query({"limit": "200", "fields[betaGroups]": "name,isInternalGroup"}),
        token,
    ).get("data", [])
    group = next(
        (
            item
            for item in groups
            if item.get("attributes", {}).get("name") == GROUP_NAME
            and item.get("attributes", {}).get("isInternalGroup") is True
        ),
        None,
    )
    if group is None:
        group_payload = {
            "data": {
                "type": "betaGroups",
                "attributes": {
                    "name": GROUP_NAME,
                    "isInternalGroup": True,
                    "hasAccessToAllBuilds": False,
                    "feedbackEnabled": True,
                },
                "relationships": {
                    "app": {"data": {"type": "apps", "id": app_id}}
                },
            }
        }
        group = request("POST", "/betaGroups", token, group_payload)["data"]
        print(f"Created internal TestFlight group {GROUP_NAME}.")
    group_id = group["id"]

    group_builds_path = f"/betaGroups/{group_id}/relationships/builds"
    if not relationship_contains(group_builds_path, build_id, token):
        add_relationship(group_builds_path, "builds", build_id, token)
        print(f"Added TestFlight build {build_number} to {GROUP_NAME}.")
    else:
        print(f"TestFlight build {build_number} is already assigned to {GROUP_NAME}.")

    users = request(
        "GET",
        "/users?"
        + query(
            {
                "limit": "200",
                "fields[users]": "username,firstName,lastName,roles,allAppsVisible",
            }
        ),
        token,
    ).get("data", [])
    account_holder = next(
        (
            user
            for user in users
            if "ACCOUNT_HOLDER" in user.get("attributes", {}).get("roles", [])
        ),
        None,
    )
    if account_holder is None:
        raise RuntimeError("No App Store Connect Account Holder was found")

    account = account_holder.get("attributes", {})
    email = str(account.get("username") or "").strip()
    if not email:
        raise RuntimeError("The Account Holder does not have an Apple Account username")

    testers = request(
        "GET",
        "/betaTesters?"
        + query(
            {
                "filter[email]": email,
                "limit": "1",
                "fields[betaTesters]": "email,firstName,lastName,state",
            }
        ),
        token,
    ).get("data", [])
    if testers:
        tester = testers[0]
    else:
        tester_payload = {
            "data": {
                "type": "betaTesters",
                "attributes": {
                    "email": email,
                    "firstName": account.get("firstName") or "SVNLY",
                    "lastName": account.get("lastName") or "Tester",
                },
                "relationships": {
                    "betaGroups": {
                        "data": [{"type": "betaGroups", "id": group_id}]
                    }
                },
            }
        }
        tester = request("POST", "/betaTesters", token, tester_payload)["data"]
        print("Created the Account Holder's TestFlight tester record.")

    tester_id = tester["id"]
    group_testers_path = f"/betaGroups/{group_id}/relationships/betaTesters"
    if not relationship_contains(group_testers_path, tester_id, token):
        add_relationship(group_testers_path, "betaTesters", tester_id, token)
        print("Added the Account Holder to the internal TestFlight group.")
    else:
        print("The Account Holder is already in the internal TestFlight group.")

    print(
        f"Internal TestFlight distribution is ready for SVNLY build {build_number} "
        f"(build resource {build_id})."
    )


if __name__ == "__main__":
    main()

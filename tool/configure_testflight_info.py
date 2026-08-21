#!/usr/bin/env python3
"""Populate SVNLY TestFlight contact metadata from this Apple team."""

from __future__ import annotations

import os
import urllib.parse

from enable_apple_sign_in import create_token, request


APP_DESCRIPTION = (
    "SVNLY ist eine Video-Community für spontane Momente, tägliche Challenges "
    "und authentische Begegnungen."
)
BETA_AGREEMENT = """SVNLY Beta-Testvereinbarung / Beta Testing Agreement

Diese Vorabversion von SVNLY wird ausschließlich zu Testzwecken bereitgestellt. Sie kann Fehler enthalten, sich ohne Ankündigung ändern oder zeitweise nicht verfügbar sein. Verlasse dich nicht auf die App für Notfälle oder sicherheitskritische Zwecke. Behandle nicht öffentlich veröffentlichte Funktionen und Materialien vertraulich. Teile nur Inhalte, für die du die erforderlichen Rechte und Einwilligungen besitzt, und beachte die SVNLY-Nutzungsbedingungen, Community-Richtlinien und Datenschutzerklärung. Testdaten können zurückgesetzt werden.

This prerelease version of SVNLY is provided solely for testing. It may contain errors, change without notice, or be temporarily unavailable. Do not rely on it for emergencies or safety-critical use. Keep non-public features and materials confidential. Share only content for which you have the necessary rights and consents, and follow the SVNLY Terms, Community Guidelines, and Privacy Policy. Test data may be reset. Use is also subject to Apple's TestFlight terms."""


def complete_review_contact(attributes: dict) -> bool:
    required = (
        "contactFirstName",
        "contactLastName",
        "contactPhone",
        "contactEmail",
    )
    return all(str(attributes.get(field) or "").strip() for field in required)


def main() -> None:
    target_app_id = os.environ.get("APP_STORE_APPLE_ID", "").strip()
    if not target_app_id:
        raise RuntimeError("APP_STORE_APPLE_ID is required")

    token = create_token()
    query = urllib.parse.urlencode(
        {
            "limit": "200",
            "fields[apps]": "name,bundleId,primaryLocale",
        }
    )
    apps = request("GET", f"/apps?{query}", token).get("data", [])

    source_attributes = None
    for app in apps:
        if app.get("id") == target_app_id:
            continue
        details = request(
            "GET", f"/apps/{app['id']}/betaAppReviewDetail", token
        ).get("data", {})
        attributes = details.get("attributes", {})
        if complete_review_contact(attributes):
            source_attributes = attributes
            break

    if source_attributes is None:
        raise RuntimeError(
            "No existing app has complete TestFlight review contact information"
        )

    target_details = request(
        "GET", f"/apps/{target_app_id}/betaAppReviewDetail", token
    ).get("data", {})
    target_detail_id = target_details.get("id")
    if not target_detail_id:
        raise RuntimeError("SVNLY beta app review detail resource was not found")

    review_attributes = {
        field: source_attributes[field]
        for field in (
            "contactFirstName",
            "contactLastName",
            "contactPhone",
            "contactEmail",
        )
    }
    review_attributes["demoAccountRequired"] = False
    review_payload = {
        "data": {
            "type": "betaAppReviewDetails",
            "id": target_detail_id,
            "attributes": review_attributes,
        }
    }
    request(
        "PATCH",
        f"/betaAppReviewDetails/{target_detail_id}",
        token,
        review_payload,
    )

    agreement = request(
        "GET", f"/apps/{target_app_id}/betaLicenseAgreement", token
    ).get("data")
    if agreement:
        agreement_id = agreement["id"]
        agreement_payload = {
            "data": {
                "type": "betaLicenseAgreements",
                "id": agreement_id,
                "attributes": {"agreementText": BETA_AGREEMENT},
            }
        }
        request(
            "PATCH",
            f"/betaLicenseAgreements/{agreement_id}",
            token,
            agreement_payload,
        )
    else:
        agreement_payload = {
            "data": {
                "type": "betaLicenseAgreements",
                "attributes": {"agreementText": BETA_AGREEMENT},
                "relationships": {
                    "app": {"data": {"type": "apps", "id": target_app_id}}
                },
            }
        }
        request("POST", "/betaLicenseAgreements", token, agreement_payload)

    localizations = request(
        "GET", f"/apps/{target_app_id}/betaAppLocalizations", token
    ).get("data", [])
    localization = next(
        (
            item
            for item in localizations
            if item.get("attributes", {}).get("locale") == "de-DE"
        ),
        localizations[0] if localizations else None,
    )
    localization_attributes = {
        "feedbackEmail": source_attributes["contactEmail"],
        "description": APP_DESCRIPTION,
        "privacyPolicyUrl": (
            "https://svnly.sebastian-buergy.chatgpt.site/privacy"
        ),
    }
    if localization:
        localization_id = localization["id"]
        localization_payload = {
            "data": {
                "type": "betaAppLocalizations",
                "id": localization_id,
                "attributes": localization_attributes,
            }
        }
        request(
            "PATCH",
            f"/betaAppLocalizations/{localization_id}",
            token,
            localization_payload,
        )
    else:
        localization_attributes["locale"] = "de-DE"
        localization_payload = {
            "data": {
                "type": "betaAppLocalizations",
                "attributes": localization_attributes,
                "relationships": {
                    "app": {"data": {"type": "apps", "id": target_app_id}}
                },
            }
        }
        request("POST", "/betaAppLocalizations", token, localization_payload)

    print(
        "SVNLY TestFlight contact, beta agreement, and localized information "
        "are complete."
    )


if __name__ == "__main__":
    main()

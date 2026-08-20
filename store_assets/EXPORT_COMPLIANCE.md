# Export Compliance (Draft)

SVNLY uses only standard encryption supplied by Apple/Flutter networking and service SDKs for HTTPS/TLS, authentication and secure local storage. It does not implement a proprietary cryptographic algorithm or provide encryption as its primary function.

Expected App Store Connect answer: the app uses encryption, but only exempt standard encryption. Confirm the final binary’s SDK inventory and the applicable U.S./Swiss export rules before selecting the exemption. `ITSAppUsesNonExemptEncryption` should be set only after that confirmation; it is not asserted here without owner/legal review.

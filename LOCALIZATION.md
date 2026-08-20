# Localization

V1 ships English and German. Device locale selects copy with English as fallback. Challenges contain independently authored `title_en`, `title_de`, `description_en` and `description_de`; the generator validates that both languages exist and prevents duplicate/banned prompts.

Product constants such as the seven-second duration, one-take rule and technical retry wording must remain semantically identical in both languages. Dates/times are displayed locally, while challenge issuance and streak calculations remain UTC/server-authoritative.

Before adding another locale, add supported locale metadata, translate all feature/error/legal/store copy, run layout/accessibility review at large text sizes and extend tests for fallback and critical rule wording.

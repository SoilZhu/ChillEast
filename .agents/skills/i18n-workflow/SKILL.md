---
name: i18n-workflow
description: Guidelines and procedures for maintaining multilingual keys and localizing Flutter widgets in ChillEast.
---

# ChillEast i18n Workflow & Runbook

This skill guides the extraction and maintenance of internationalized strings in ChillEast.

## When to Use
Use this workflow whenever you add new user-facing screens, modify existing text, or extract hardcoded strings into multilingual resources.

## Step-by-Step Procedure

1. **Check and define keys in ARB files**:
   - Primary Chinese template: `lib/l10n/app_zh.arb`
   - English resource: `lib/l10n/app_en.arb`
   - Keep keys camelCase and descriptive (e.g., `notificationSettings`, `saveChanges`).
   - If parameterized, declare placeholders in the `@<key>` block in `app_zh.arb`.

2. **Generate Dart localizations**:
   Run:
   ```bash
   flutter gen-l10n
   ```

3. **Use in UI**:
   - Import `core/utils/l10n_extension.dart`.
   - Access via `context.l10n.<key>`.

4. **Use in Non-UI / Background Services**:
   - Import `l10n/app_localizations.dart`.
   - Access via `lookupAppLocalizations(currentLocale).<key>`.

5. **Verify**:
   Run the test suite:
   ```bash
   flutter test test/core/state/locale_provider_test.dart
   ```

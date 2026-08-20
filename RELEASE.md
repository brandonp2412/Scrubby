# Releasing Scrubby

1. Update `version` in `pubspec.yaml` and add user-facing notes to the GitHub
   release.
2. Run the checks in `CONTRIBUTING.md`, review dependency updates, and confirm
   third-party asset rights and notices.
3. Create a protected, annotated `vX.Y.Z` tag from the reviewed commit.
4. Create and publish the matching GitHub release. The release workflows build
   Android and Windows Store packages, attach checksums and artifacts to the
   release, publish the Android bundle to Google Play when configured, and
   publish the MSIX to Microsoft Store.
5. Verify the signer and checksum before distributing an artifact outside a
   store. Complete each store's current privacy and foreground-service
   declarations.
6. Confirm the asset and third-party notice records are current, and verify
   that the release contains no local build, browser-session, credential, or
   household data.

## Required GitHub repository secrets

- `ANDROID_KEYSTORE_BASE64`: base64-encoded Android upload keystore.
- `ANDROID_KEYSTORE_PASSWORD`: keystore password.
- `ANDROID_KEY_ALIAS`: upload-key alias.
- `ANDROID_KEY_PASSWORD`: upload-key password.
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`: service-account JSON permitted to upload
  the Android bundle to Google Play (optional; the release still builds and
  attaches the AAB without it).
- `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, and `SELLER_ID`:
  Microsoft Store API credentials used only by the Windows Store deployment
  job.

The Android workflow fails rather than publishing an unsigned artifact if any
required Android signing secret is missing. Windows Store publishing only runs
for a published `v*` GitHub release (or an explicitly requested manual retry).

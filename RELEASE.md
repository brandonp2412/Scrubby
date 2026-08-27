# Releasing Scrubby

Scrubby follows the same automatic release model as FitBook.

A push to `main` runs the full quality, screenshot, and Patrol test suite. If those checks pass, GitHub Actions:

1. increments the patch version and build number in `pubspec.yaml`;
2. increments the MSIX patch version;
3. generates release notes from commits since the previous tag;
4. commits the generated version, screenshots, and release metadata;
5. creates and pushes a tag matching the version, such as `1.0.1`;
6. builds signed Android APK/AAB artifacts, Linux and Windows packages, an MSIX package, checksums, and an SBOM;
7. creates the matching GitHub Release and attaches the built artifacts;
8. publishes to Google Play when its service-account secret is configured; and
9. publishes the MSIX to Microsoft Store when its Store credentials are configured.

Pull requests run the verification jobs but do not bump the version or create a release.

## Required GitHub repository secrets

Android signing requires:

- `ANDROID_KEYSTORE_BASE64`: base64-encoded Android upload keystore.
- `ANDROID_KEYSTORE_PASSWORD`: keystore password.
- `ANDROID_KEY_ALIAS`: upload-key alias.
- `ANDROID_KEY_PASSWORD`: upload-key password.

Google Play publishing additionally uses:

- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`: service-account JSON permitted to upload the Android bundle. If omitted, the GitHub Release is still built and published.

Microsoft Store publishing additionally uses:

- `AZURE_TENANT_ID`
- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`
- `SELLER_ID`

If the Store credentials are omitted, the GitHub Release and Windows artifacts are still produced.

The release build fails rather than producing Android release artifacts when the required Android signing secrets are absent.

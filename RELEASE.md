# Releasing Scrubby

1. Update `version` in `pubspec.yaml` and add user-facing notes to the GitHub
   release.
2. Run the checks in `CONTRIBUTING.md`, review dependency updates, and confirm
   third-party asset rights and notices.
3. Create a protected, annotated `vX.Y.Z` tag from the reviewed commit.
4. Create and publish the matching GitHub release. The release workflow builds
   the Android App Bundle, its SHA-256 checksum, a dependency inventory, and an
   SBOM, then uploads them to that release.
5. Verify the AAB signer and checksum before submitting it to a store. Complete
   that store's current privacy and foreground-service declarations.

## Required GitHub repository secrets

- `ANDROID_KEYSTORE_BASE64`: base64-encoded Android upload keystore.
- `ANDROID_KEYSTORE_PASSWORD`: keystore password.
- `ANDROID_KEY_ALIAS`: upload-key alias.
- `ANDROID_KEY_PASSWORD`: upload-key password.

The workflow fails rather than publishing an unsigned artifact if any signing
secret is missing.

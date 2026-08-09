# Contributing to Scrubby

Thanks for helping improve Scrubby. Please open an issue before starting a
substantial change so the work can be discussed first.

## Local development

Use Flutter 3.44.8 and a JDK 17 installation. Then run:

```sh
flutter pub get
flutter analyze
flutter test
flutter build web --release
flutter build appbundle --release
```

Android release builds are unsigned unless `android/key.properties` is present.
That file must never be committed. Create it locally with:

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

Use an Android upload key created and retained by the project owner. Verify the
resulting AAB is signed with that key before submitting it to a store.

## Pull requests

Keep changes focused, include tests for behaviour changes, and ensure the
quality checks above pass. Do not include credentials, Home Assistant exports,
or personally identifiable screenshots in a pull request.

## Developer Certificate of Origin

By contributing, you certify that you have the right to submit the work under
the repository's license. Sign commits off with `git commit -s`; this adds a
`Signed-off-by` line and records that certification.

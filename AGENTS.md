# Android Device Installation

- For physical Android device installs, do not use `flutter run` or `flutter install`.
- Build the APK first, then install or update it with `adb install -r <path-to.apk>` so the existing app data is preserved.
- If `adb install -r` fails because of a signing-key mismatch, version downgrade, or another install error, report the failure and do not uninstall the existing app unless explicitly asked.

# Required Flutter Completion Checks

- Before considering any work complete, run all of the following and ensure they pass:
  1. `dart format .`
  2. `flutter analyze`
  3. `flutter test`
- If the repository pins Flutter in a local `flutter/` SDK or submodule, use the pinned equivalents: `flutter/bin/dart format .`, `flutter/bin/flutter analyze`, and `flutter/bin/flutter test`.
- Do not report work as completed while any of these checks are failing. Fix failures caused by the work; if a required check cannot be run, explicitly report why.

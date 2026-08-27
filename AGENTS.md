# Required Flutter Completion Checks

- Before considering any work complete, run all of the following and ensure they pass:
  1. `dart format .`
  2. `flutter analyze`
  3. `flutter test`
- If the repository pins Flutter in a local `flutter/` SDK or submodule, use the pinned equivalents: `flutter/bin/dart format .`, `flutter/bin/flutter analyze`, and `flutter/bin/flutter test`.
- Do not report work as completed while any of these checks are failing. Fix failures caused by the work; if a required check cannot be run, explicitly report why.

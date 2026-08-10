# Third-party notices

Scrubby includes or depends on the following third-party software. The exact
resolved versions are recorded in [pubspec.lock](pubspec.lock). License files
are also present in each package published to the Dart package repository.

## Direct Dart and Flutter dependencies

| Package | Resolved version | License | Copyright / source |
| --- | ---: | --- | --- |
| cupertino_icons | 1.0.9 | MIT | Vladimir Kharlampidi; [package](https://pub.dev/packages/cupertino_icons) |
| flutter_local_notifications | 22.2.0 | BSD 3-Clause | Michael Bui; [package](https://pub.dev/packages/flutter_local_notifications) |
| flutter_background_service | 5.1.0 | MIT | Eka Setiawan Saputra; [package](https://pub.dev/packages/flutter_background_service) |
| flutter_secure_storage | 9.2.4 | BSD 3-Clause | German Saprykin; [package](https://pub.dev/packages/flutter_secure_storage) |
| http | 1.6.0 | BSD 3-Clause | Dart project authors; [package](https://pub.dev/packages/http) |
| material_symbols_icons | 4.2960.0 | Apache 2.0 | Material Symbols; [package](https://pub.dev/packages/material_symbols_icons) |
| web_socket_channel | 3.0.3 | BSD 3-Clause | Dart project authors; [package](https://pub.dev/packages/web_socket_channel) |
| flutter_lints | 6.0.0 | BSD 3-Clause | Flutter Authors; development dependency; [package](https://pub.dev/packages/flutter_lints) |

Flutter's bundled framework, Dart SDK, transitive packages, and platform
plugins are covered by the generated Flutter `NOTICES` file in built
artifacts. The release workflow also publishes a CycloneDX SBOM so consumers
can identify the complete resolved dependency graph.

When redistributing a built application, retain this file, the generated
Flutter notices, and the applicable notices shipped by each platform package.

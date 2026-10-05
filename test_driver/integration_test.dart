import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async => await integrationDriver(
  onScreenshot: (name, image, [args]) async {
    final deviceType = Platform.environment['SCRUBBY_DEVICE_TYPE'];
    if (deviceType == null || deviceType.isEmpty) {
      throw 'SCRUBBY_DEVICE_TYPE must be set.';
    }
    final isIos = Platform.environment['SCRUBBY_IS_IOS'];

    final isWeb =
        Platform.environment['FLUTTER_WEB'] == 'true' ||
        args?.toString().contains('chrome') == true ||
        args?.toString().contains('web') == true ||
        Platform.environment['FLUTTER_DRIVER_DEVICE'] == 'chrome' ||
        Platform.environment['FLUTTER_DRIVER_DEVICE']?.contains('chrome') ==
            true;

    File imgFile;
    if (isWeb) {
      imgFile = await File(
        'fastlane/screenshots/$deviceType-$name.png',
      ).create(recursive: true);
    } else if (isIos != null) {
      imgFile = await File(
        'fastlane/screenshots/$deviceType-$name.png',
      ).create(recursive: true);
    } else {
      imgFile = await File(
        'fastlane/metadata/android/en-US/images/$deviceType/$name.png',
      ).create(recursive: true);
    }
    await imgFile.writeAsBytes(image);
    return true;
  },
  writeResponseOnFailure: true,
);

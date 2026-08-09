# Scrubby

Scrubby is a focused Flutter companion for robot vacuums connected to Home Assistant. It turns the generic vacuum entity controls into a calm, purpose-built interface for starting a clean, checking progress, managing rooms, viewing a floor map, and planning schedules.

## Supported platforms

Scrubby is currently released and tested for Android, Linux, Windows, and the
web. Apple platforms are not supported. The Android release keeps a foreground
notification-monitoring service while the app is backgrounded; this is
described in [Privacy](PRIVACY.md).

## Run it

```sh
flutter pub get
flutter run
```

Choose **Explore with demo home** to see the complete interface without a server. To connect a real installation, enter the Home Assistant URL and a long-lived access token created at **Home Assistant → Profile → Security → Long-lived access tokens**.

## Home Assistant integration

The app authenticates with Home Assistant's WebSocket API, discovers every `vacuum.*` entity, and subscribes to the Home Assistant event bus so vacuum state, battery, fan speed, and compatible camera/image maps stay live. REST is used for the latest map image bytes and the standard service calls:

- `vacuum.start`
- `vacuum.pause`
- `vacuum.return_to_base`
- `vacuum.locate`

Room labels are Scrubby map metadata stored securely on the device and scoped to each vacuum. They do not create Home Assistant Areas. For vacuums supporting Home Assistant's `CLEAN_AREA` capability, Scrubby discovers real rooms with `vacuum/get_segments`, binds each label to a segment ID, and discovers the installed integration's segment-cleaning service when a manual clean starts. This supports Dreame's `dreame_vacuum.vacuum_clean_segment` service and the equivalent `clean_segment` service shapes used by other integrations. Scrubby never substitutes a whole-home `vacuum.start` call when room cleaning is unavailable. Map images do not contain standard room geometry, so the labelling dialog asks which reported vacuum room is under the tapped point. The integration boundary lives in `lib/core/home_assistant.dart`.

Robot settings are discovered from Home Assistant's entity registry by matching the vacuum's device ID. Every enabled `switch`, `select`, `number`, and `button` entity on that device is rendered with its native control. This gives Dreame robots model-aware access to carpet cleaning mode, clean-carpets-first, carpet boost, cleaning route, mop and dock preferences, maintenance actions, and any newer options the integration adds without requiring an app update. Entities disabled in Home Assistant must be enabled there before Scrubby can control them.

## Dreame notifications

Scrubby listens for all five event families emitted by the Dreame Home Assistant integration: `task_status`, `consumable`, `information`, `warning`, and `error`. They are delivered through separate Android notification channels (Cleaning activity, Consumables, Robot information, Robot warnings, and Robot errors), so users can configure each family independently. Notification permission is requested after Home Assistant connects.

On Android, Scrubby starts a `remoteMessaging` foreground service when the app is backgrounded. The service runs the authenticated Home Assistant WebSocket in its own Dart isolate, reconnects using the securely stored credentials, and posts the same category-specific notifications even after the UI isolate is suspended. Android displays a small, low-priority “Scrubby connection” status notification while monitoring is active; stopping or force-stopping Scrubby stops delivery.

For Flutter web, Home Assistant must allow the app's origin in `http.cors_allowed_origins`. Mobile builds support both local HTTP Home Assistant instances and remote HTTPS instances.

## Quality checks

```sh
flutter analyze
flutter test
flutter build web
flutter build appbundle --release
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the supported toolchain and local
release-signing setup. See [SECURITY.md](SECURITY.md) for vulnerability
reporting and [PRIVACY.md](PRIVACY.md) for data handling.

## Screenshots

Generate the complete Fastlane screenshot set (phone, 7-inch tablet, 10-inch
tablet, and desktop) with Waydroid and Chrome:

```sh
scripts/screenshots-waydroid.sh
```

Pass a dimension such as `phoneScreenshots`, `sevenInchScreenshots`,
`tenInchScreenshots`, or `desktop` to regenerate only that target. A second
argument can select one screenshot by number or test name, for example:

```sh
scripts/screenshots-waydroid.sh phoneScreenshots 1
```

Android output is written to Fastlane's Play metadata folders and desktop
output to `fastlane/screenshots`. The runner requires Waydroid, ADB, `dwl`,
ChromeDriver, and passwordless `sudo` for Waydroid administration.

## Trademarks and affiliation

Scrubby is an independent project and is not affiliated with, endorsed by, or
sponsored by Home Assistant or Dreame. Home Assistant and Dreame are trademarks
of their respective owners.

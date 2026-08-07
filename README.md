# Scrubby

Scrubby is a focused Flutter companion for robot vacuums connected to Home Assistant. It turns the generic vacuum entity controls into a calm, purpose-built interface for starting a clean, checking progress, managing rooms, viewing a floor map, and planning schedules.

## Run it

```sh
flutter pub get
flutter run
```

Choose **Explore with demo home** to see the complete interface without a server. To connect a real installation, enter the Home Assistant URL and a long-lived access token created at **Home Assistant → Profile → Security → Long-lived access tokens**.

## Home Assistant integration

The app authenticates with Home Assistant's WebSocket API, discovers every `vacuum.*` entity, and subscribes to `state_changed` events so vacuum state, battery, fan speed, and compatible camera/image maps stay live. REST is used for the latest map image bytes and the standard service calls:

- `vacuum.start`
- `vacuum.pause`
- `vacuum.return_to_base`
- `vacuum.locate`

Room labels are Scrubby map metadata stored securely on the device and scoped to each vacuum. They do not create Home Assistant Areas. For vacuums supporting Home Assistant's `CLEAN_AREA` capability, Scrubby discovers real rooms with `vacuum/get_segments`, binds each label to a segment ID, and discovers the installed integration's segment-cleaning service when a manual clean starts. This supports Dreame's `dreame_vacuum.vacuum_clean_segment` service and the equivalent `clean_segment` service shapes used by other integrations. Scrubby never substitutes a whole-home `vacuum.start` call when room cleaning is unavailable. Map images do not contain standard room geometry, so the labelling dialog asks which reported vacuum room is under the tapped point. The integration boundary lives in `lib/core/home_assistant.dart`.

Robot settings are discovered from Home Assistant's entity registry by matching the vacuum's device ID. Every enabled `switch`, `select`, `number`, and `button` entity on that device is rendered with its native control. This gives Dreame robots model-aware access to carpet cleaning mode, clean-carpets-first, carpet boost, cleaning route, mop and dock preferences, maintenance actions, and any newer options the integration adds without requiring an app update. Entities disabled in Home Assistant must be enabled there before Scrubby can control them.

For Flutter web, Home Assistant must allow the app's origin in `http.cors_allowed_origins`. Mobile builds support both local HTTP Home Assistant instances and remote HTTPS instances.

## Quality checks

```sh
flutter analyze
flutter test
flutter build web
```

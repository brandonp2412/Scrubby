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

Naming a room on the map reuses or creates a Home Assistant Area through the Area Registry WebSocket API. Creating Areas requires an administrator access token. Home Assistant does not store map coordinates for Areas, so pin positions remain session-local and removing a pin does not delete the Area or disturb its assigned entities. Vacuum vendors expose segmented cleaning differently, so room-targeted cleaning still requires vendor-specific entities, scripts, or automations. The integration boundary lives in `lib/core/home_assistant.dart`.

For Flutter web, Home Assistant must allow the app's origin in `http.cors_allowed_origins`. Mobile builds support both local HTTP Home Assistant instances and remote HTTPS instances.

## Quality checks

```sh
flutter analyze
flutter test
flutter build web
```

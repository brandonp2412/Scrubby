# Scrubby

Scrubby is a focused Flutter companion for robot vacuums connected to Home Assistant. It turns the generic vacuum entity controls into a calm, purpose-built interface for starting a clean, checking progress, managing rooms, viewing a floor map, and planning schedules.

## Run it

```sh
flutter pub get
flutter run
```

Choose **Explore with demo home** to see the complete interface without a server. To connect a real installation, enter the Home Assistant URL and a long-lived access token created at **Home Assistant → Profile → Security → Long-lived access tokens**.

## Home Assistant integration

The app discovers every `vacuum.*` entity through the REST API and currently calls the standard services:

- `vacuum.start`
- `vacuum.pause`
- `vacuum.return_to_base`
- `vacuum.locate`

The rooms, illustrated map, and schedules are interactive product surfaces with demo/local state. Vacuum vendors expose segmented cleaning and maps differently, so connecting these surfaces to production data should be done through vendor-specific Home Assistant entities, scripts, or automations. The integration boundary lives in `lib/core/home_assistant.dart`.

For Flutter web, Home Assistant must allow the app's origin in `http.cors_allowed_origins`. Mobile builds support both local HTTP Home Assistant instances and remote HTTPS instances.

## Quality checks

```sh
flutter analyze
flutter test
flutter build web
```

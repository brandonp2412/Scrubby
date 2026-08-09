# Privacy policy

Effective date: 2026-08-09

Scrubby is a direct client for a Home Assistant server selected by the user. It
does not operate a Scrubby backend, include advertising, or include analytics
or crash-reporting SDKs.

## Data used by the app

Scrubby stores the following data locally:

- the Home Assistant URL and long-lived access token supplied by the user;
- room labels created in Scrubby; and
- normal application preferences needed to restore the connection.

The URL and token are stored with `flutter_secure_storage` on supported native
platforms. In a web browser, storage is controlled by the browser and is not
equivalent to native device key storage; use a trusted browser profile and log
out on shared devices.

To provide its features, Scrubby sends the token to the selected Home Assistant
server and receives vacuum state, map images, device settings, schedules, and
Dreame integration events. This data is not sent to a Scrubby-operated server.

## Notifications and background operation

On Android, when a connected app enters the background, Scrubby runs a visible
foreground service to monitor Home Assistant events. It displays a persistent,
low-priority connection notification and may display event notifications. The
service stops when the app returns to the foreground, the user logs out, or the
app is force-stopped.

## Your choices

Logging out deletes the saved URL, token, and Scrubby room labels from local
storage and stops background monitoring. Revoke a long-lived token in Home
Assistant to invalidate it independently of the app. Home Assistant's own
privacy practices govern data held by the selected server.

## Changes and contact

Changes to this policy are published in this file. Privacy questions should be
raised through the project's issue tracker without including credentials or
private Home Assistant data.

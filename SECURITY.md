# Security policy

## Supported versions

Security fixes are made on the latest released version of Scrubby.

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability and do not include a
Home Assistant URL or access token in a report. If this repository is hosted on
GitHub, use its **Report a vulnerability** button to create a private security
advisory. If private advisories are unavailable, contact the repository
maintainers through the private contact method published in the repository
profile or release page; do not send exploit details through a public issue.

Include the affected version, platform, reproduction steps, impact, and any
suggested mitigation. Reports are acknowledged within seven days when
maintainer availability permits.

## Security boundaries

Scrubby stores a Home Assistant URL, a long-lived access token, and local room
labels on the device. Anyone with access to that token can act with its Home
Assistant permissions. Use the least-privileged token practical, revoke it on
loss of a device, and prefer HTTPS for remote connections.

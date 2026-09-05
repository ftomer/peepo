# Security and privacy

## What Peepo collects

Nothing.

Peepo is a children's game with no network code.
There are no accounts, no analytics, no crash reporting, no advertising and no remote configuration.
The only thing it writes is settings and level progress, stored on the device by `shared_preferences`.
Nothing leaves the device, so there is nothing to breach on a server, because there is no server.

See [docs/legal/privacy-policy.md](docs/legal/privacy-policy.md) for the published policy and [docs/kids-direction.md](docs/kids-direction.md) for why the app is built this way.

## Reporting a vulnerability

Email ftomerf0@gmail.com.
Do not open a public issue for something exploitable.

Expect a reply within a week.
There is no bounty programme.

What is in scope:

- Anything that makes the app reach the network, directly or through a dependency.
- Anything that lets data about a child off the device.
- A dependency with a known advisory that Peepo actually reaches.
- A way past the parental gate that guards external links.

What is not in scope:

- Reading or modifying the app's own local `shared_preferences` on a device you already control.
- Findings against a fork rather than this repository.

## Supported versions

The latest release on the App Store is the supported one.
Fixes land on `main` and go out in the next build.

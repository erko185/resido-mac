# Changelog — Resido macOS client

All notable changes to the macOS desktop client (Electron shell for the Resido
web app). Versions match `RESIDO_CLIENT_VERSION` in `script/.env`.

## [1.0.0] - 2026-08-01

### Added

- macOS counterpart of the Windows desktop client: Electron shell loading `<server>/resido/`, exposing the `window.reservationClient` bridge used by the web app for silent printing.
- Silent printing to a receipt printer plus four bon printers, sizing the page from the `paperWidth` parameter and the `--receipt-width`/`--bon-width` CSS variables, and honouring the `print-copies` meta tag (duplicate receipts print as separate jobs so roll printers cut between copies).
- Settings screen: server URL and the five printer slots, with an update check.
- Injected "Nastavenia" and back buttons, no-cache session, auto-update support.
- `script/build.sh` release flow (version prompt, build, upload), mirroring the Windows `build.bat`.

### Fixed

- Receipt width scaling: `scaleFactor: 100` stops Chromium from fit-scaling the page onto the driver's paper, which showed up as a clipped right edge and long lines wrapping to the left margin.

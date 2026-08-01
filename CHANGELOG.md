# Changelog — Resido macOS client

All notable changes to the macOS desktop client (Electron shell for the Resido
web app). Versions match `RESIDO_CLIENT_VERSION` in `script/.env`.

## [Unreleased]

### Fixed

- **Bon tails were cut off on printers with a long head-to-cutter distance (CK710)**: in RAW ESC/POS mode the feed before the cut used `ESC d 6` (six text lines), whose real length depends on the firmware's line spacing and fell short of the CK710's head-to-cutter distance — the last line(s) stayed behind the blade and came out on top of the next bon. The feed is now 36 mm of blank raster rows, which every printer advances dot-exactly (`ESC J`, the dot-based feed command, turned out to be ignored outright by XP-80 clones, so no pure feed command is trusted anymore). Matches Windows client 3.7.6.

### Added

- Print diagnostics log a `RAW feed before cut: ...` line, so the log identifies builds carrying this fix.

## [1.1.0] - 2026-08-01

Port of the Windows client's printing overhaul (Windows client 3.7.x).

### Added

- **RAW ESC/POS printing** (per printer slot, on by default): the receipt/bon page is rendered off-screen, rasterized at exactly the configured paper width (203 dpi) and submitted to CUPS as a raw job (`lp -o raw`), bypassing the printer driver entirely. Fixes thermal printers (Xprinter/POS-80C and similar) whose drivers ignore custom page widths and print shifted or clipped receipts. Existing installs get RAW switched on once by a one-time migration; turning a slot back off stays respected.
- **Hidden print diagnostics** (`Cmd+Shift+L`): logs the print path, paper width, page zoom and how much of the raster is actually inked, shown in the settings screen and written to `print-log.txt` in the app's data folder. Off by default.

### Fixed

- **Receipts printed narrower than the paper**: the RAW renderer measures the window's page zoom factor (shared per origin within a session, so a window zoomed with `Cmd+-` shrank prints too) and compensates for it, printing at the configured width regardless of how the operator zoomed the window.
- **Implicit system-default printing removed**: every slot, including the receipt printer, is now picked explicitly — RAW ESC/POS needs a named printer, and silently printing to whatever the system considers default was a source of wrong-printer/wrong-width output.

### Changed

- The client source (`main.js`, `preload.js`, `offline.html`, README) moved out of `resido.sh` heredocs into plain files under `script/assets/`, mirroring the Windows client layout — print fixes can now be ported between the two by diffing files directly.
- `RESIDO_CLIENT_VERSION` in `script/.env` corrected to the macOS versioning scheme (was left at the Windows client's `3.6.0` before the repository split).

## [1.0.0] - 2026-08-01

### Added

- macOS counterpart of the Windows desktop client: Electron shell loading `<server>/resido/`, exposing the `window.reservationClient` bridge used by the web app for silent printing.
- Silent printing to a receipt printer plus four bon printers, sizing the page from the `paperWidth` parameter and the `--receipt-width`/`--bon-width` CSS variables, and honouring the `print-copies` meta tag (duplicate receipts print as separate jobs so roll printers cut between copies).
- Settings screen: server URL and the five printer slots, with an update check.
- Injected "Nastavenia" and back buttons, no-cache session, auto-update support.
- `script/build.sh` release flow (version prompt, build, upload), mirroring the Windows `build.bat`.

### Fixed

- Receipt width scaling: `scaleFactor: 100` stops Chromium from fit-scaling the page onto the driver's paper, which showed up as a clipped right edge and long lines wrapping to the left margin.

# Apple Sharpener CLI

This document explains how to use the `sharpener` command‑line tool to control Apple Sharpener at runtime.

## Quick Start

```bash
# Enable or disable
sharpener on
sharpener off

# Toggle
sharpener toggle

# Set radius
sharpener -r 40
sharpener --radius=40

# Show current settings
sharpener -s
sharpener --status

# Show version
sharpener -v
sharpener --version
```

## Commands

- `on` — Enable window sharpening
- `off` — Disable window sharpening
- `toggle` — Toggle window sharpening on/off

## Options

- `-r, --radius <value>` — Set the sharpening radius (integer `>= 0`)
- `--radius=<value>` — Alternative syntax to set radius
- `-s, --status` — Show current radius and status (`on`/`off`)
- `-v, --version` — Show CLI version
- `-h, --help` — Show built‑in help

## Examples

```bash
# Set radius to 0 for sharp (square) corners
sharpener -r 0

# Set radius to 40 and enable immediately
sharpener on && sharpener -r 40

# Query current status
sharpener -s
# Output example:
# Current radius: 40
# Status: on

# Show version
sharpener --version
# Output example:
# Apple Sharpener version: 0.1
```

## Behavior Notes

- **Crash-resistant**: v0.0.3+ includes fixes for application crashes, especially with Zoom and other complex apps
- **Smart targeting**: Only affects standard application windows with title bars and minimum size requirements
- **System UI preservation**: Intelligently excludes context menus, tooltips, HUD/utility windows, and floating panels
- **Window level awareness**: Respects macOS window hierarchy to avoid affecting system overlays
- **Notification-based updates**: Uses safe window lifecycle events for corner radius application
- Fullscreen windows use a radius of `0` to avoid visual artifacts
- Changes apply live across open windows; no app relaunch required
- Enabled state and radius persist across apps via system notifications

## Installation Path

- The installer places the CLI at `/usr/local/bin/sharpener`.
- If building from source via `make install`, the CLI is installed to the same path.

## Troubleshooting

### Common Issues

**Application crashes (especially Zoom)**: Fixed in v0.0.3+ with crash-resistant design and improved window detection.

**Corner radius not applying to specific apps**:
- Some applications may require a restart after Apple Sharpener installation
- Run `sharpener -s` to verify Apple Sharpener is enabled
- Check that the application uses standard titled windows

**System UI elements affected**:
- v0.0.3+ intelligently excludes context menus, tooltips, and system overlays
- If issues persist, please report with your macOS version and affected application

### General Troubleshooting
- Run `sharpener -s` to confirm status and radius.
- Ensure system requirements from the main README are met.
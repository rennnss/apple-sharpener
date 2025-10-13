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

# Show version
sharpener -v
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

- Targets standard application windows only; menus, popovers, HUD/utility windows are preserved.
- Fullscreen windows use a radius of `0` to avoid visual artifacts.
- Changes apply live across open windows; no app relaunch required.
- Enabled state and radius persist across apps via system notifications.

## Installation Path

- The installer places the CLI at `/usr/local/bin/sharpener`.
- If building from source via `make install`, the CLI is installed to the same path.

## Troubleshooting

- Run `sharpener -s` to confirm status and radius.
- Ensure system requirements from the main README are met.
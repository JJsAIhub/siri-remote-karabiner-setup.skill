---
name: siri-remote-karabiner-setup
description: Use when turning an Apple TV Siri Remote into a macOS controller for vibe coding, including Karabiner button mappings, touch-surface mouse movement, one-command installation, mapping diagrams, configurable toggle buttons, or troubleshooting remote input on Mac.
---

# Siri Remote macOS Vibe Coding Controller

## Overview

This skill helps turn an Apple TV Siri Remote into a practical macOS controller for vibe coding: remote buttons become keyboard/mouse shortcuts, and the touch surface can move the pointer through a helper app.

Current mapping diagram:

![Apple TV Siri Remote macOS mapping](assets/siri-remote-white-vibe-coding-map.png)

The working setup has two parts:

- `Karabiner-Elements` maps physical remote buttons.
- `SiriRemoteHIDProbe.app` handles touch-surface mouse movement and can be installed by script.

Use it when the job includes:

- guiding Bluetooth pairing for the remote
- installing `Karabiner-Elements`
- installing the touch-surface helper app
- confirming whether a remote is detected by `Karabiner-EventViewer`
- mapping remote buttons to keyboard keys
- using a custom helper app for touch-surface mouse movement
- making the touch-surface on/off button configurable
- generating or explaining the remote mapping diagram
- importing ready-made JSON files
- switching between `On / Off` Karabiner profiles
- explaining or editing the JSON mappings
- using the bundled script for near one-click setup

## When To Read Which File

- For install and zero-to-one setup, read [references/install-and-import.md](references/install-and-import.md).
- For confirmed event names and final button mapping, read [references/event-map.md](references/event-map.md).
- For JSON structure and field meanings, read [references/json-explained.md](references/json-explained.md).
- For touch-surface mouse movement, configurable toggle buttons, and helper-app verification, read [references/touch-mouse-config.md](references/touch-mouse-config.md).
- For common failures and recovery steps, read [references/troubleshooting.md](references/troubleshooting.md).

## Bundled Assets

- `assets/karabiner-siri-remote-on-off.json`
  Full dual-profile configuration with `Siri Remote On` and `Siri Remote Off`.
- `assets/siri-remote-codex-import.json`
  Single-rule import file for reuse.
- `assets/keymap-diagram.png`
  Early button mapping diagram kept for historical reference.
- `assets/siri-remote-white-vibe-coding-map.png`
  Current white-background real-remote mapping diagram with complete Chinese labels.
- `assets/siri-remote-white-vibe-coding-map.svg`
  Lightweight SVG wrapper for the current white-background diagram.
- `assets/siri-remote-white-base.png`
  Generated white-background realistic remote base image used by the current diagram.
- `scripts/generate-white-mapping-diagram.py`
  Regenerates the current white-background mapping diagram when labels change.
- `assets/siri-remote-vibe-coding-map.svg`
- `assets/siri-remote-realistic-vibe-coding-map.svg`
- `assets/siri-remote-realistic-vibe-coding-map.png`
- `assets/siri-remote-realistic-base.png`
  Older dark-style realistic diagram assets kept for reference.

## Bundled Script

- `scripts/install-karabiner-profile.sh`
  Checks common install locations for `Karabiner-Elements`, tries Homebrew install if it is still missing, then copies the dual-profile JSON into `~/.config/karabiner/karabiner.json` after creating a timestamped backup, and opens Karabiner.

Use the script when the user wants the fastest local setup with the fewest manual steps.

- `touch-mouse-app/tools/install-touch-mouse-app.mjs`
  One-command installer for the touch mouse helper app and generated Karabiner config. Prefer `--dry-run` before first install.

## Important Notes

- The remote's touch swipe area may not appear as ordinary Karabiner button events. Use the helper app plus Karabiner toggle file flow when touch movement is required.
- Keep physical button mappings in Karabiner and touch-surface mouse movement in the helper app. This separation prevents normal mouse/trackpad conflicts from becoming impossible to debug.
- Before running install commands for a user, explain that the installer edits `~/.config/karabiner/karabiner.json`, installs `/Applications/SiriRemoteHIDProbe.app`, and requires macOS Accessibility/Input Monitoring approvals.
- When changing mappings, edit the small config/generator first. Avoid hand-editing the large installed `karabiner.json` unless debugging.
- A truly zero-click setup is not realistic on macOS because first-run system permissions still require user approval.
- Homebrew auto-install should be framed as "try automatically first, then fall back to manual install if it fails" rather than as a guaranteed one-click path.
- `Karabiner-EventViewer` can temporarily disable active modifications while monitoring. If mappings appear not to work, check that first.
- The Back button on this remote was confirmed as `generic_desktop: system_app_menu`, not `menu_escape`.

## Compatibility Notes

- Treat the Karabiner button mappings and the touch mouse helper as two different compatibility surfaces.
- Karabiner v16 supports modern macOS versions and both Intel and Apple Silicon Macs, but the helper app still depends on private macOS `MultitouchSupport` APIs.
- Do not promise that a prebuilt `SiriRemoteHIDProbe.app` works on every Mac. Prefer local compile through `node touch-mouse-app/tools/install-touch-mouse-app.mjs`.
- The currently verified remote identifier is Apple `vendor_id: 76`, `product_id: 789`. If another Siri Remote generation does not respond, verify the device ID before changing mappings.
- If the active Karabiner profile is `Siri Remote Off`, mappings are intentionally disabled. Check the current profile before debugging code.
- Node.js 18+ is the safest baseline because the generator uses modern JavaScript APIs.

# Touch Mouse Config

## Architecture

Use two layers:

- Karabiner handles physical button mappings.
- `SiriRemoteHIDProbe.app` handles touch-surface mouse movement.

Current mapping diagram:

- `../assets/siri-remote-white-vibe-coding-map.svg`
- `../assets/siri-remote-white-vibe-coding-map.png`

Karabiner toggles the helper app by touching:

- `/tmp/SiriRemoteTouchMouse.toggle`

The helper app watches that file and switches touch mouse mode on/off.

## Current Project Files

In this project, the working touch mouse implementation lives at:

- `touch-mouse-app/SiriRemoteTouchMouse.m`
- `touch-mouse-app/karabiner-siri-remote-safe.json`
- `touch-mouse-app/remote-settings.json`
- `touch-mouse-app/tools/configure-touch-toggle.mjs`

The installed app path is:

- `/Applications/SiriRemoteHIDProbe.app`

The runtime log is:

- `/tmp/SiriRemoteTouchMouse.log`

## One-Command Install

For vibe-coding style setup, prefer the installer script:

```bash
node touch-mouse-app/tools/install-touch-mouse-app.mjs
```

Before a first install or after changing the script, preview it:

```bash
node touch-mouse-app/tools/install-touch-mouse-app.mjs --dry-run
```

The installer regenerates mappings, runs self-tests, builds the helper app, backs up Karabiner config, installs the app to `/Applications`, restarts the app, and validates the active Karabiner setup.

## Configurable Toggle Button

The user-facing config is:

```json
{
  "touchMouseToggleButton": "selection",
  "doubleClickDelayMilliseconds": 300,
  "longPressDelayMilliseconds": 500
}
```

Supported `touchMouseToggleButton` values:

- `selection`
- `back`
- `home`
- `mute`
- `play_pause`
- `microphone`

After editing `remote-settings.json`, regenerate Karabiner config:

```bash
node touch-mouse-app/tools/configure-touch-toggle.mjs
```

Then install it:

```bash
cp touch-mouse-app/karabiner-siri-remote-safe.json ~/.config/karabiner/karabiner.json
```

## Important Behavior

When the toggle button is `selection`:

- single click Confirm -> `return_or_enter`
- double click Confirm -> touch mouse on/off

When the toggle button is `mute`:

- single click Mute -> delete
- long press Mute -> clear current input
- double click Mute -> touch mouse on/off
- Confirm remains `return_or_enter`

The generator must preserve base mappings when the toggle button changes. Do not remove Confirm's `Enter` behavior when moving the toggle away from Confirm.

## How To Adjust Mappings

Prefer these layers, in this order:

- Touch on/off button: edit `remote-settings.json`, then run `node touch-mouse-app/tools/configure-touch-toggle.mjs`.
- Basic remote button actions: edit `buttonCatalog` and `createBaseManipulators` in `tools/configure-touch-toggle.mjs`, then run the generator self-test.
- Touch-surface mouse feel: edit constants such as mouse scale, cooldown, and fallback behavior in `SiriRemoteTouchMouse.m`, then run `make test`.

After any mapping change:

```bash
node touch-mouse-app/tools/configure-touch-toggle.mjs --self-test
node touch-mouse-app/tools/configure-touch-toggle.mjs
/Library/Application\ Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli --lint-complex-modifications touch-mouse-app/karabiner-siri-remote-safe.json
cp touch-mouse-app/karabiner-siri-remote-safe.json ~/.config/karabiner/karabiner.json
```

For full install after mapping changes, use the one-command installer instead.

## Verification

Run:

```bash
node touch-mouse-app/tools/install-touch-mouse-app.mjs --self-test
node touch-mouse-app/tools/install-touch-mouse-app.mjs --dry-run
node touch-mouse-app/tools/configure-touch-toggle.mjs --self-test
/Library/Application\ Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli --lint-complex-modifications touch-mouse-app/karabiner-siri-remote-safe.json
cd touch-mouse-app && make test
```

## AI One-Command Install

Use:

```bash
node touch-mouse-app/tools/install-touch-mouse-app.mjs
```

The installer performs:

- regenerate configurable Karabiner mapping
- run generator self-test
- build and self-test `SiriRemoteHIDProbe`
- package the `.app`
- back up `~/.config/karabiner/karabiner.json`
- install the new Karabiner config
- copy the app to `/Applications/SiriRemoteHIDProbe.app`
- restart the helper app
- lint the installed Karabiner config and show current profile

Always prefer `--dry-run` before a first install on a new machine.

After installing the config, verify:

```bash
/Library/Application\ Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli --show-current-profile-name
/Library/Application\ Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli --lint-complex-modifications ~/.config/karabiner/karabiner.json
```

Expected profile:

- `Siri Remote On`

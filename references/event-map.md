# Event Map

Diagram:

- `../assets/siri-remote-white-vibe-coding-map.svg`
- `../assets/siri-remote-white-vibe-coding-map.png`

Regenerate the diagram after mapping changes:

```bash
python3 siri-remote-karabiner-setup/scripts/generate-white-mapping-diagram.py
```

## Confirmed Raw Events

The following event names were confirmed from `Karabiner-EventViewer` for this Siri Remote flow:

- Up: `consumer_key_code: menu_up`
- Down: `consumer_key_code: menu_down`
- Left: `consumer_key_code: menu_left`
- Right: `consumer_key_code: menu_right`
- Confirm: `consumer_key_code: selection`
- Back: `generic_desktop: system_app_menu`
- Home: `consumer_key_code: data_on_screen`
- Play/Pause: `consumer_key_code: play_or_pause`
- Side microphone button: `consumer_key_code: microphone`
- Mute: `consumer_key_code: mute`
- Volume up: `consumer_key_code: volume_increment`
- Volume down: `consumer_key_code: volume_decrement`

## Final Mapping

- `menu_up` -> `up_arrow`
- `menu_down` -> `down_arrow`
- `menu_left` -> `left_arrow`
- `menu_right` -> `right_arrow`
- `selection` -> `return_or_enter`
- double click `selection` -> toggle touch-surface mouse movement
- single click `system_app_menu` -> mouse left click + `return_or_enter`
- double click `system_app_menu` -> `control + left_arrow`
- single click `data_on_screen` -> mouse right click
- double click `data_on_screen` -> `control + right_arrow`
- `play_or_pause` -> `spacebar`
- single click `microphone` -> `Fn`
- double click `microphone` -> `escape`
- single click `mute` -> `delete_or_backspace`
- long press `mute` -> `command + a`, then `delete_or_backspace`
- `volume_increment` -> scroll up
- `volume_decrement` -> scroll down

## Configurable Touch Toggle

The default touch-surface toggle is:

- double click `selection`

Use the project's `remote-settings.json` and `tools/configure-touch-toggle.mjs` to switch the toggle button without hand-editing the full Karabiner JSON.

## Important Clarification

The Back button is the easiest place to make a wrong assumption.

Do not map Back as:

- `menu_escape`

For this setup, the confirmed event was:

- `generic_desktop: system_app_menu`

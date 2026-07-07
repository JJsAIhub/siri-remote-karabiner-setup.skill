# JSON Explained

## Dual-Profile File

File:

- `assets/karabiner-siri-remote-on-off.json`

This file contains two Karabiner profiles:

- `Siri Remote On`
- `Siri Remote Off`

## Top-Level Structure

### `profiles`

This is the main list of Karabiner profiles.

Each profile is like a full preset.

## Inside A Profile

### `name`

The visible profile name inside Karabiner.

### `selected`

Whether that profile is the currently active one when the file is loaded.

### `devices`

This tells Karabiner which physical device the rules should apply to.

For this setup, the device is matched by:

- `vendor_id: 76`
- `product_id: 789`
- `is_consumer: true`

That makes the rules target the Siri Remote instead of changing the keyboard globally.

### `simple_modifications`

This is the actual mapping list.

Each entry is:

- `from`
- `to`

Example:

```json
{
  "from": { "consumer_key_code": "menu_up" },
  "to": [{ "key_code": "up_arrow" }]
}
```

Meaning:

- when the remote sends `menu_up`
- Karabiner should act as if `up_arrow` was pressed

## Special Cases

### Back Button

This one uses:

```json
{ "generic_desktop": "system_app_menu" }
```

instead of `consumer_key_code`.

That is why it looks different from the other buttons.

### Play/Pause

The Play/Pause button maps single click to:

```json
{ "key_code": "spacebar" }
```

Double click maps to:

```json
{ "key_code": "escape" }
```

### Fn

The microphone side button maps to:

```json
{ "apple_vendor_top_case_key_code": "keyboard_fn" }
```

This is Karabiner's way of expressing the Mac `Fn` key.

### Scroll

Volume up/down are mapped using:

```json
{ "mouse_key": { "vertical_wheel": -32 } }
```

and

```json
{ "mouse_key": { "vertical_wheel": 32 } }
```

Meaning:

- negative value = scroll up
- positive value = scroll down

## Why The Off Profile Matters

`Siri Remote Off` keeps the same device match but uses an empty `simple_modifications` list.

That gives the user a clean way to disable the whole custom mapping set without editing JSON again.

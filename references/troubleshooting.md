# Troubleshooting

## EventViewer Shows Events But Mapping Does Not Work

First check whether `Karabiner-EventViewer` is temporarily disabling modifications.

If the banner says modifications are disabled:

- stop monitoring
- close EventViewer
- test again

## Remote Appears In Devices But Not In Simple Modifications

This can still happen when the remote sends special event types such as:

- `consumer_key_code`
- `generic_desktop`

That does not mean the remote failed.

It only means the event names must be selected from the correct Karabiner categories.

## Back Button Does The Wrong Thing

Check whether Back was mapped using the wrong source event.

Correct source:

- `generic_desktop: system_app_menu`

Wrong assumption to avoid:

- `menu_escape`

## Swipe Does Nothing

Karabiner may not expose the Siri Remote touch surface as ordinary button events.

If touch-surface mouse movement is required, use the helper app flow described in `touch-mouse-config.md`.

Check:

- `SiriRemoteHIDProbe.app` is running
- `/tmp/SiriRemoteTouchMouse.log` exists
- double clicking the configured toggle button writes `/tmp/SiriRemoteTouchMouse.toggle`
- the log shows `[mode] touch mouse enabled` or `[mode] touch mouse disabled`

## Touch Movement Affects Normal Mouse Or Trackpad

The fallback path reads Karabiner multitouch variables, which can include normal Mac trackpad input.

Mitigations used in the helper app:

- touch mouse mode starts disabled
- double click toggle enables/disables it
- repeated old multitouch snapshots do not move the cursor
- multi-finger input is ignored
- normal mouse movement briefly pauses fallback movement

Do not reintroduce always-on unsafe fallback for daily use.

## JSON Applied But Karabiner Looks Broken

Recover by restoring the backup `karabiner.json`.

If the bundled installer script was used, it creates a timestamped backup automatically.

Default backup location:

- `~/.config/karabiner/automatic_backups/`

Restore flow:

```bash
cp ~/.config/karabiner/automatic_backups/<backup-file>.json ~/.config/karabiner/karabiner.json
```

Then reopen Karabiner-Elements.

## Uninstall Touch Mouse App

Stop and remove the helper app:

```bash
pkill -f SiriRemoteHIDProbe
rm -rf /Applications/SiriRemoteHIDProbe.app
```

Then restore the Karabiner backup if the user wants to remove the mappings too.

## Profile Switching Does Not Update Immediately

Try:

- reopen Karabiner-Elements
- switch profile again
- disconnect and reconnect the remote if necessary

## Fn Mapping Feels Like It Does Nothing

That may be normal.

`Fn` is often a trigger or modifier for macOS features rather than a visible text key.

Verify macOS keyboard settings if the user expects:

- Dictation
- Globe behavior
- input switching behavior

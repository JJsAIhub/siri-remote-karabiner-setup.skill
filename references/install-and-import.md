# Install And Import

## Goal

This guide helps a new user go from "nothing installed" to "remote can switch on/off as a full preset" with as little manual work as macOS allows.

For the newer vibe-coding setup with touch-surface mouse movement, use:

```bash
node touch-mouse-app/tools/install-touch-mouse-app.mjs --dry-run
node touch-mouse-app/tools/install-touch-mouse-app.mjs
```

The old Karabiner-only import path is still useful when the user only wants physical button mappings.

## Step 0: Pair The Siri Remote By Bluetooth

Before Karabiner setup, make sure the remote is paired to the Mac.

Recommended flow:

1. Open macOS Bluetooth settings.
2. Put the Siri Remote close to the Mac.
3. If needed, hold the pairing combination shown by Apple for the user's remote generation until it appears in Bluetooth devices.
4. Wait until macOS shows it as connected.

If the remote is already connected, skip this step.

Important:

- the exact pairing gesture may differ slightly by remote generation
- if pairing fails, have the user recharge the remote first and try again close to the Mac

## Step 1: Install Karabiner-Elements

Preferred methods:

1. Official site download  
   Open the official Karabiner-Elements website and install it normally.
2. Homebrew  
   If the user already uses Homebrew, they can try that path first, but do not present it as guaranteed.

After install, tell the user to open `Karabiner-Elements` once and allow the requested macOS permissions.

Common permissions to confirm:

- `Accessibility`
- `Input Monitoring`
- system extension / driver prompts if macOS asks

Compatibility notes:

- Karabiner-Elements is the stable layer for physical button mappings.
- The touch-surface helper app is more sensitive to macOS changes because it uses the private `MultitouchSupport` framework.
- Prefer compiling the helper app on the user's own Mac instead of distributing a prebuilt `.app`.
- If the user is on Intel Mac, do not reuse an Apple Silicon-only build.
- If the user is on an older macOS version, verify build output and app launch before assuming touch movement works.

If the goal is the fewest possible steps, prefer the bundled script first. It will:

- check whether Karabiner is installed in common app locations
- try Homebrew install if Karabiner is missing
- stop with a clear fallback message if Homebrew install fails
- back up the current config
- copy the dual-profile JSON
- open Karabiner after writing the config

Important:

- Homebrew auto-install is convenient, but not fully reliable in the real world
- the script currently checks standard app locations such as `/Applications` and `~/Applications`
- common failure causes include network issues, mirror queue delays, Homebrew health, and macOS permission problems
- when that happens, switch to manual install instead of repeatedly retrying blindly

## Step 2: Confirm The Remote Is Visible

Open:

- `Karabiner-EventViewer`

Ask the user to press a few remote buttons and confirm events appear.

If no events appear:

- verify Bluetooth pairing first
- check whether the remote is still connected
- check Karabiner permissions again
- confirm the remote device ID; this setup currently targets Apple `vendor_id: 76`, `product_id: 789`

## Step 3: Choose Setup Path

There are two valid setup paths:

### Path A: Manual import from JSON

Use:

- `assets/karabiner-siri-remote-on-off.json`

This is best when the user wants to inspect or merge the JSON themselves.

### Path B: One-command local install

Use:

- `scripts/install-karabiner-profile.sh`

This is best when the user wants the fastest local setup and wants AI to minimize manual steps.

Expectation setting:

- this is "as close to one-click as macOS allows"
- it still cannot bypass first-run permission dialogs
- it may try Homebrew automatically, but that step can fail and should have a manual fallback

## Step 4: Apply The Dual-Profile Config

After the JSON is copied into:

- `~/.config/karabiner/karabiner.json`

the user should open `Karabiner-Elements` and go to:

- `Profiles`

They should see:

- `Siri Remote On`
- `Siri Remote Off`

## Step 5: Verify

With `Siri Remote On` selected, test:

- Up button moves up
- Down button moves down
- Center confirm acts like `Enter`
- Back single click acts like mouse left click + `Enter`
- Back double click acts like `Control + Left Arrow`
- Home single click acts like mouse right click
- Home double click acts like `Control + Right Arrow`
- double click the configured toggle button enables or disables touch-surface mouse movement

Then switch to `Siri Remote Off` and confirm the custom behavior stops.

If the mappings do not work immediately:

- close `Karabiner-EventViewer`
- reopen `Karabiner-Elements`
- switch profiles once
- test again

## Step 6: Keep A Recovery Path

Always keep a backup of the previous Karabiner config before overwriting it.

The bundled script already does this automatically.

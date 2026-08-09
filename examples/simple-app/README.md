# simple-app

Minimal widget demonstrating the rest of the Tinymetrix API not covered by
[`examples/simple-watchface`](../simple-watchface):

- `source/SimpleAppApp.mc` — extends `Tinymetrix.ApplicationBase`, and reacts to
  `onSettingsChanged()` (fired when the user changes a setting from Garmin
  Connect Mobile — see `resources/settings/settings.xml`) by tracking a
  `"properties_changed"` custom event, updating a user property, and logging
  the outcome with `logInfo`/`logError`.
- `source/SimpleAppView.mc` — shows the current setting value.

## Run it

From a checkout of the [`tinymetrix/client`](https://github.com/tinymetrix/client) repo, with the Connect IQ SDK installed:

1. Download [`tinymetrix-latest-debug.barrel`](https://github.com/tinymetrix/client/releases/latest/download/tinymetrix-latest-debug.barrel) and save it to `output/tinymetrix-latest-debug.barrel` at the repo root — `barrels.jungle` already points there, nothing to edit.
2. Open this folder in VS Code with the Monkey C extension and run/debug normally, or from the CLI (both jungle files — `monkey.jungle` alone won't pull in the barrel dependency declared in `barrels.jungle`):

   ```bash
   monkeyc -f "examples/simple-app/monkey.jungle;examples/simple-app/barrels.jungle" \
           -d fenix7pro \
           -o bin/simple-app.prg \
           -y developer_key.der
   monkeydo bin/simple-app.prg fenix7pro
   ```

To see `onSettingsChanged()` fire in the simulator: run the app, then in the
simulator go to *Settings → App Settings* (or trigger it via
`Application.Properties.setValue` from another test), change *Sync interval
(minutes)*, and check the simulator's log output for the
`logInfo`/`logError` line.

Set your real token in `resources/properties.xml` (`TinymetrixToken`) before shipping.

## Using this as a template

Copy this folder as a starting point for your own app, then:

1. Rename `SimpleApp*` classes/files and the `manifest.xml` `entry`/`name`.
2. Add your full device list to `manifest.xml` (VS Code: *Monkey C: Set Products by Product Category*).

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

Build a barrel from the repo root (see [`examples/simple-watchface`](../simple-watchface#run-it) for why not a raw `monkeyc`/`monkeybrains` call), then compile this folder — both jungle files are needed, `monkey.jungle` alone won't pull in the barrel dependency declared in `barrels.jungle`:

```bash
python3 scripts/minify.py . --build --debug --sdk "$CIQ_HOME" \
  --barrel-output output/tinymetrix-2.2.0-debug.barrel

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

Same steps as [`examples/simple-watchface`](../simple-watchface#using-this-as-a-template) —
rename `SimpleApp*`, point `barrels.jungle` at a released barrel, add your
full device list.

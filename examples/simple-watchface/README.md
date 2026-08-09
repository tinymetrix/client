# simple-watchface

Minimal digital watch face demonstrating the Tinymetrix Connect IQ client:

- `source/SimpleWatchFaceApp.mc` — extends `Tinymetrix.WatchFaceApplicationBase`, sets a user id/properties on launch.
- `source/SimpleWatchFaceView.mc` — tracks `SESSION_START`/`SESSION_END` and draws the time.
- `source/SimpleWatchFaceDelegate.mc` — logs an error via `Tinymetrix.Client.logError` from the AMOLED power-budget callback.

## Run it

From a checkout of the [`tinymetrix/client`](https://github.com/tinymetrix/client) repo, with the Connect IQ SDK installed:

```bash
# 1. Build a barrel (from the repo root) so barrels.jungle has something to point at
java -cp "$CIQ_HOME/bin/monkeybrains.jar" com.garmin.monkeybrains.MonkeyBarrelEntry \
  -o output/tinymetrix-2.2.0-debug.barrel -f monkey.jungle -w -O 3

# 2. Open this folder in VS Code with the Monkey C extension and run/debug normally,
#    or from the CLI:
monkeyc -f examples/simple-watchface/monkey.jungle \
        -d fenix7pro \
        -o bin/simple-watchface.prg \
        -y developer_key.der
monkeydo bin/simple-watchface.prg fenix7pro
```

Set your real token in `resources/properties.xml` (`TinymetrixToken`) before shipping — the placeholder value only works against your own test setup.

## Using this as a template

Copy this folder as a starting point for your own app, then:

1. Rename `SimpleWatchFace*` classes/files and the `manifest.xml` `entry`/`name`.
2. Update `barrels.jungle` to point at a barrel downloaded from [Releases](https://github.com/tinymetrix/client/releases) instead of a locally-built one.
3. Add your full device list to `manifest.xml` (VS Code: *Monkey C: Set Products by Product Category*).

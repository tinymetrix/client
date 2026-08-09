# simple-watchface

Minimal digital watch face demonstrating the Tinymetrix Connect IQ client:

- `source/SimpleWatchFaceApp.mc` — extends `Tinymetrix.WatchFaceApplicationBase`, sets a user id/properties on launch.
- `source/SimpleWatchFaceView.mc` — draws the time.
- `source/SimpleWatchFaceDelegate.mc` — logs an error via `Tinymetrix.Client.logError` from the AMOLED power-budget callback.

## Run it

From a checkout of the [`tinymetrix/client`](https://github.com/tinymetrix/client) repo, with the Connect IQ SDK installed:

1. Download [`tinymetrix-latest-debug.barrel`](https://github.com/tinymetrix/client/releases/latest/download/tinymetrix-latest-debug.barrel) and save it to `output/tinymetrix-latest-debug.barrel` at the repo root — `barrels.jungle` already points there, nothing to edit.
2. Open this folder in VS Code with the Monkey C extension and run/debug normally, or from the CLI (both jungle files — `monkey.jungle` alone won't pull in the barrel dependency declared in `barrels.jungle`):

   ```bash
   monkeyc -f "examples/simple-watchface/monkey.jungle;examples/simple-watchface/barrels.jungle" \
           -d fenix7pro \
           -o bin/simple-watchface.prg \
           -y developer_key.der
   monkeydo bin/simple-watchface.prg fenix7pro
   ```

Set your real token in `resources/properties.xml` (`TinymetrixToken`) before shipping — the placeholder value only works against your own test setup.

## Using this as a template

Copy this folder as a starting point for your own app, then:

1. Rename `SimpleWatchFace*` classes/files and the `manifest.xml` `entry`/`name`.
2. Add your full device list to `manifest.xml` (VS Code: *Monkey C: Set Products by Product Category*).

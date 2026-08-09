# Tinymetrix Connect IQ Client

[![CI](https://github.com/tinymetrix/client/actions/workflows/ci.yml/badge.svg)](https://github.com/tinymetrix/client/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

Lightweight analytics & crash/error logging barrel for [Garmin Connect IQ](https://developer.garmin.com/connect-iq/overview/) apps (watch faces, widgets, apps, data fields). Drop-in `AppBase` replacement that tracks install/session events, forwards logs, and batches everything to the [Tinymetrix](https://tinymetrix.com) ingest API in the background — without you having to write any networking, storage, or background-service code.

- **No app-side networking code.** Events/logs are queued to `Storage` and flushed by a background `ServiceDelegate` Tinymetrix registers for you.
- **Tiny.** Compiles into a single `.barrel` (a few KB), built with debug logging stripped in release mode.
- **Respects Connect IQ constraints.** Background execution, `CommStatus` restrictions and API level differences are all handled internally.

## Table of contents

- [Install](#install)
- [Quick start](#quick-start)
- [API reference](#api-reference)
  - [`Tinymetrix.Client`](#tinymetrixclient)
  - [`Tinymetrix.EventType`](#tinymetrixeventtype)
  - [App base classes](#app-base-classes)
  - [Config options](#config-options)
  - [Required `properties.xml` keys](#required-propertiesxml-keys)
- [Examples](#examples)
- [Building from source](#building-from-source)
- [Running tests](#running-tests)
- [Releasing](#releasing-maintainers)
- [Contributing](#contributing)
- [License](#license)

## Install

1. Get an app token from your Tinymetrix dashboard (this is the `TinymetrixToken` used below).
2. Download a `.barrel` from [Releases](https://github.com/tinymetrix/client/releases) — grab the `tinymetrix-<version>.barrel` for release builds, or the `-debug` one while developing (unstripped logging). Prefer not pinning a version? [`tinymetrix-latest.barrel`](https://github.com/tinymetrix/client/releases/latest/download/tinymetrix-latest.barrel) / [`tinymetrix-latest-debug.barrel`](https://github.com/tinymetrix/client/releases/latest/download/tinymetrix-latest-debug.barrel) always resolve to the newest release.
3. Point a barrel at it in your project's `barrels.jungle` (or edit it via VS Code's *Monkey C: Configure Monkey Barrel* command):

   ```jungle
   Tinymetrix = "/absolute/path/to/tinymetrix-2.2.0.barrel"
   base.barrelPath = $(base.barrelPath);$(Tinymetrix)
   ```

4. Declare the dependency in `manifest.xml` (VS Code does this automatically when you add the barrel):

   ```xml
   <iq:barrels>
       <iq:depends name="Tinymetrix" version="2.2.0"/>
   </iq:barrels>
   ```

5. Add your token (and, optionally, app name/version so they show up in Tinymetrix metadata) to `resources/properties.xml`:

   ```xml
   <properties>
     <property id="TinymetrixToken" type="string">YOUR_TINYMETRIX_TOKEN</property>
     <property id="AppName" type="string">MyWatchFace</property>
     <property id="AppVersion" type="string">1.0.0</property>
   </properties>
   ```

## Quick start

Extend the base class that matches your app type instead of `Application.AppBase` — Tinymetrix wires up install/session tracking and the background sync service for you:

```mc
import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Tinymetrix;

class MyWatchFaceApp extends Tinymetrix.WatchFaceApplicationBase {

    function initialize() {
        Tinymetrix.WatchFaceApplicationBase.initialize({
            "syncDelay" => 6 * 60 * 60,  // flush to Tinymetrix every 6h
        });
    }

    function onCreateView() as [Views] or [Views, InputDelegates] {
        return [ new MyWatchFaceView() ];
    }
}

function getApp() as MyWatchFaceApp {
    return Application.getApp() as MyWatchFaceApp;
}
```

Then, anywhere in your app:

```mc
Tinymetrix.Client.track("goal_completed");
Tinymetrix.Client.setUserId("user-123");
Tinymetrix.Client.logInfo("View rendered in " + elapsedMs + "ms");
```

See [`examples/simple-watchface`](examples/simple-watchface) for a full, runnable project.

## API reference

Only symbols exported from files marked `(:barrel)` are part of the public surface — everything else (config storage, scheduler, service delegate, JSON serializer, etc.) is an internal implementation detail and is not accessible outside the barrel.

### `Tinymetrix.Client`

Static entry point for tracking and logging. Safe to call from foreground or background context.

| Method | Description |
|---|---|
| `track(event as EventType \| String) as Void` | Track a built-in `EventType` or a custom event name. |
| `logInfo(message as String) as Void` | Log an informational message, forwarded to Tinymetrix. |
| `logError(message as String) as Void` | Log an error message, forwarded to Tinymetrix. |
| `setUserId(userId as String) as Void` | Associate all future events/logs with a user identifier. |
| `setUserProperties(properties as Dictionary) as Void` | Attach a batch of string key/value properties to future events. |

### `Tinymetrix.EventType`

```mc
enum EventType {
    SESSION_START = "session_started",
    SESSION_END   = "session_ended",
    INSTALL       = "install",
    HEARTBEAT     = "heartbeat"
}
```

`track()` also accepts any arbitrary `String` for custom events (e.g. `Tinymetrix.Client.track("workout_started")`).

### App base classes

Pick the one matching your app's entry point. All three accept an optional config `Dictionary` in `initialize()` (see [Config options](#config-options)) and automatically:

- Track `INSTALL` on launch.
- Register the background `ServiceDelegate` that flushes queued events/logs to Tinymetrix.
- Mark foreground/background execution context so background-restricted communications aren't attempted from a temporary activity.

| Class | Use for | Notes |
|---|---|---|
| `Tinymetrix.WatchFaceApplicationBase` | Watch faces | Override `onCreateView()`. |
| `Tinymetrix.ApplicationBase` | Regular apps / widgets | Override `onCreateView()`. The only base class that ever emits `SESSION_START`/`SESSION_END` — gated behind the `trackSessions` config key (see below), off by default. |
| `Tinymetrix.DataFieldApplicationBase` | Data fields | Override `onCreateView()`. |

All three also expose:

```mc
// Override to run your own background work alongside Tinymetrix's sync.
function getBackgroundServiceDelegate() as System.ServiceDelegate? {
    return null;
}
```

### Config options

Passed as a `Dictionary` to the base class `initialize()`. All keys are optional; anything omitted keeps its default.

| Key | Type | Default | Description |
|---|---|---|---|
| `enabled` | `Boolean` | `true` | Master on/off switch for tracking. |
| `debug` | `Boolean` | `false` | Verbose local logging via `System.println`. |
| `trackSessions` | `Boolean` | `false` | Track `SESSION_START`/`SESSION_END`. Only has an effect on `Tinymetrix.ApplicationBase` — `WatchFaceApplicationBase`/`DataFieldApplicationBase` never emit session events regardless of this setting. |
| `heartbeat` | `Boolean` | `true` | Periodic `HEARTBEAT` event while the app is active. |
| `syncDelay` | `Number` (seconds) | `43200` (12h) | Minimum delay between background syncs to the ingest API. Clamped to `[300, 604800]` (5 min – 7 days). |
| `sampleRate` | `Number` | `10` | Drop repeated identical consecutive logs, keeping 1 in N. `1` disables sampling. |

### Required `properties.xml` keys

| Property | Type | Required | Description |
|---|---|---|---|
| `TinymetrixToken` | `string` | Yes | Your app's ingest token from the Tinymetrix dashboard. |
| `AppName` | `string` | No | Reported in event metadata; falls back to `"unknown"`. |
| `AppVersion` | `string` | No | Reported in event metadata; falls back to `"unknown"`. |

## Examples

- [`examples/simple-watchface`](examples/simple-watchface) — minimal digital watch face: `setUserId`/`setUserProperties` on launch, `logError` from the AMOLED power-budget callback.
- [`examples/simple-app`](examples/simple-app) — widget showing the rest of the API: reacting to `onSettingsChanged()` with a custom `track()` event + `setUserProperties`, and a realistic `logInfo`/`logError` path around a settings value.

## Building from source

Requires the [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) — `scripts/ci-download-sdk.sh <dir>` fetches it non-interactively (same manifest the CI uses), or install it via the SDK Manager. A [developer key](https://developer.garmin.com/connect-iq/reference-guides/developer-key/) is only needed for compiling the test project, not for building the barrel itself.

```bash
python3 scripts/minify.py . --build --release --sdk "$CIQ_HOME" \
  --barrel-output output/tinymetrix-release.barrel
python3 scripts/minify.py . --build --debug --sdk "$CIQ_HOME" \
  --barrel-output output/tinymetrix-debug.barrel
```

`scripts/minify.py` merges the top-level `.mc` files, strips comments/whitespace, renames private identifiers, toggles debug-logging dead-code stripping (`--release` vs `--debug`), and invokes `monkeybrains.jar` to produce the `.barrel`. This is the exact same script CI runs (see the `release` job in [`.github/workflows/ci.yml`](.github/workflows/ci.yml)).

## Running tests

```bash
"$CIQ_HOME/bin/barreltest" -y /path/to/developer_key.der -f monkey.jungle -d fenix7pro -o bin/tests.prg
"$CIQ_HOME/bin/connectiq" &        # start the simulator once
"$CIQ_HOME/bin/monkeydo" bin/tests.prg fenix7pro -t
```

Unit tests live in [`tests/`](tests) and use the Connect IQ [`(:test)` framework](https://developer.garmin.com/connect-iq/core-topics/unit-testing/). Every pull request runs them headlessly in CI (see the `test` job in [`.github/workflows/ci.yml`](.github/workflows/ci.yml)) against a throwaway signing key — no secrets required.

[`test-fixtures/properties.xml`](test-fixtures/properties.xml) exists only so `barreltest`'s synthetic host app has *some* declared properties — without it, `App.Properties.getValue()` panics instead of returning null. It's test-only infrastructure, never included in the actual barrel (`scripts/minify.py`'s build copies only `manifest.xml` + merged source into an isolated temp project).

## Releasing (maintainers)

Bump `manifest.xml`'s `<iq:barrel version="...">` and push the commit to `main`. That triggers the `release` job in [`.github/workflows/ci.yml`](.github/workflows/ci.yml) (gated on `test` passing), which builds release + debug barrels via `scripts/minify.py` in CI, tags `vX.Y.Z`, and publishes a GitHub Release with both `.barrel` files attached.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Apache License 2.0 — see [LICENSE](LICENSE).

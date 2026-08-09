# Contributing

Thanks for considering a contribution to the Tinymetrix Connect IQ client!

## Setup

1. Install the [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) (via the SDK Manager, or the [VS Code Monkey C extension](https://marketplace.visualstudio.com/items?itemName=garmin.monkey-c)).
2. Generate a [developer key](https://developer.garmin.com/connect-iq/reference-guides/developer-key/) — only needed to compile the test project, not to build the barrel itself.
3. See [Building from source](README.md#building-from-source) and [Running tests](README.md#running-tests) in the README for the exact commands.

## Making a change

1. Fork and branch from `main`.
2. Public API lives in the files marked `(:barrel)` at the top of the module (`tinymetrix.mc`, `TinymetrixApplicationBase.mc`, `TinymetrixWatchFaceApplicationBase.mc`, `TinymetrixDataFieldApplicationBase.mc`, `TinymetrixEventType.mc`). Everything else is internal and can change freely.
3. Add/update a test under `tests/` for behavior changes — the `(:test)` files mirror the class they cover (e.g. `TinymetrixConfigTest.mc` for `TinymetrixConfig.mc`).
4. Run the test suite locally before opening a PR (see [Running tests](README.md#running-tests)).
5. Open a pull request against `main`. CI (`.github/workflows/ci.yml`, `test` job) compiles and runs the full suite headlessly on every PR — it must be green before merge.

## Releasing

Maintainers only — see the [Releasing](README.md#releasing-maintainers) section of the README.

## Reporting issues

Open a [GitHub issue](https://github.com/tinymetrix/client/issues) with your Connect IQ SDK version, target device, and a minimal repro if possible.

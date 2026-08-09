#!/usr/bin/env bash
# Downloads Connect IQ device definitions non-interactively, for CI.
#
# The SDK zip has no device data — the compiler/simulator look for it at a
# hard-coded ~/.Garmin/ConnectIQ/Devices, and Garmin doesn't publish a
# scriptable per-device download (only the interactive SDK Manager). Reusing
# the device bundle from matco/connectiq-tester (public, MIT-licensed CI
# image for Connect IQ) since it already solves exactly this for headless CI.
#
# Needed for both running tests (barreltest -d <device>) and building the
# barrel itself (monkeybrains validates manifest.xml's <iq:products> list
# against installed device definitions even with no -d flag).
#
# Usage: ci-download-devices.sh [install-dir]
#   [install-dir]  Defaults to ~/.Garmin/ConnectIQ/Devices (the hard-coded
#                   location the compiler/simulator actually look at — only
#                   override this for testing).
set -euo pipefail

DEST="${1:-$HOME/.Garmin/ConnectIQ/Devices}"
DEVICES_ZIP_URL="https://raw.githubusercontent.com/matco/connectiq-tester/master/devices.zip"

# A truncated/corrupt download here doesn't fail loudly — the compiler just
# silently falls back to weird behavior instead of an "invalid device"
# error — so verify the zip explicitly rather than trusting a clean exit code.
for attempt in 1 2 3; do
    curl -fsSL "$DEVICES_ZIP_URL" -o /tmp/devices.zip
    if unzip -tq /tmp/devices.zip > /dev/null 2>&1; then
        break
    fi
    echo "devices.zip failed integrity check (attempt $attempt), retrying..."
    rm -f /tmp/devices.zip
    if [ "$attempt" = 3 ]; then
        echo "Could not download a valid devices.zip after 3 attempts" >&2
        exit 1
    fi
done

mkdir -p "$DEST"
unzip -oq /tmp/devices.zip -d "$DEST"
rm -f /tmp/devices.zip

if [ -z "$(ls -A "$DEST" 2>/dev/null)" ]; then
    echo "$DEST is empty after extraction" >&2
    exit 1
fi

echo "Installed device definitions to $DEST"

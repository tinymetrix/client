#!/usr/bin/env bash
# Downloads the Garmin Connect IQ SDK (Linux build) non-interactively, for CI.
#
# There is no documented headless CLI for Garmin's graphical SDK Manager, but
# it (and this script) both read from the same public manifest it uses under
# the hood: https://developer.garmin.com/downloads/connect-iq/sdks/sdks.json
#
# Usage: ci-download-sdk.sh <install-dir> [version]
#   <install-dir>  Where to unzip the SDK. Created if missing.
#   [version]      Specific SDK version (e.g. 9.2.0). Defaults to latest.
set -euo pipefail

DEST="${1:?usage: ci-download-sdk.sh <install-dir> [version]}"
VERSION="${2:-}"

SDKS_JSON_URL="https://developer.garmin.com/downloads/connect-iq/sdks/sdks.json"
BASE_URL="https://developer.garmin.com/downloads/connect-iq/sdks/"

SDKS_JSON=$(curl -fsSL "$SDKS_JSON_URL")

if [ -z "$VERSION" ]; then
    VERSION=$(echo "$SDKS_JSON" | jq -r '.[].version' | sort -V | tail -1)
fi

FILENAME=$(echo "$SDKS_JSON" | jq -r --arg v "$VERSION" '.[] | select(.version==$v) | .linux')

if [ -z "$FILENAME" ] || [ "$FILENAME" = "null" ]; then
    echo "Could not resolve a Linux Connect IQ SDK build for version '$VERSION'." >&2
    echo "Available versions:" >&2
    echo "$SDKS_JSON" | jq -r '.[].version' >&2
    exit 1
fi

echo "Downloading Connect IQ SDK ${VERSION} (${FILENAME})..."
mkdir -p "$DEST"
curl -fsSL "${BASE_URL}${FILENAME}" -o /tmp/connectiq-sdk.zip
# -o: overwrite without prompting. A partial cache restore (e.g. a
# prefix-matched key) can leave $DEST non-empty; unzip would otherwise stop
# and wait on an interactive y/n/A/N/r prompt that never comes in CI.
unzip -oq /tmp/connectiq-sdk.zip -d "$DEST"
rm -f /tmp/connectiq-sdk.zip
chmod +x "$DEST"/bin/* 2>/dev/null || true

echo "Installed Connect IQ SDK ${VERSION} to ${DEST}"

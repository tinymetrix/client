#!/usr/bin/env bash
# Download Connect IQ device definitions from Garmin for CI builds.
#
# The SDK Manager is separate from the SDK itself. This uses the headless CLI
# to download exactly the devices declared in manifest.xml, including newly
# released devices that are not present in public third-party bundles.
set -euo pipefail

MANIFEST_PATH="${1:-manifest.xml}"
MANAGER_VERSION="0.8.4"
MANAGER_URL="https://github.com/lindell/connect-iq-sdk-manager-cli/releases/download/v${MANAGER_VERSION}/connect-iq-sdk-manager-cli_${MANAGER_VERSION}_Linux_x86_64.tar.gz"
WORK_DIR="${RUNNER_TEMP:-/tmp}/connect-iq-sdk-manager-${MANAGER_VERSION}"
MANAGER_ARCHIVE="${WORK_DIR}.tar.gz"
MANAGER="${WORK_DIR}/connect-iq-sdk-manager"
DEVICES_DIR="${HOME}/.Garmin/ConnectIQ/Devices"

: "${GARMIN_USERNAME:?GARMIN_USERNAME is required}"
: "${GARMIN_PASSWORD:?GARMIN_PASSWORD is required}"

mkdir -p "$WORK_DIR"
curl -fsSL "$MANAGER_URL" -o "$MANAGER_ARCHIVE"
tar -xzf "$MANAGER_ARCHIVE" -C "$WORK_DIR"
chmod +x "$MANAGER"

AGREEMENT_HASH=$("$MANAGER" agreement view | sed -n 's/^Current Hash: //p')
if [ -z "$AGREEMENT_HASH" ]; then
    echo "Could not determine the current Garmin agreement hash" >&2
    exit 1
fi

"$MANAGER" agreement accept --agreement-hash="$AGREEMENT_HASH"
"$MANAGER" login

mapfile -t DEVICES < <(python3 - "$MANIFEST_PATH" <<'PY'
import sys
import xml.etree.ElementTree as ET

namespace = {'iq': 'http://www.garmin.com/xml/connectiq'}
for node in ET.parse(sys.argv[1]).findall('.//iq:product', namespace):
    print(node.attrib['id'])
PY
)
if [ "${#DEVICES[@]}" -eq 0 ]; then
    echo "No devices found in $MANIFEST_PATH" >&2
    exit 1
fi

DEVICE_ARGS=()
for device in "${DEVICES[@]}"; do
    DEVICE_ARGS+=(--device "$device")
done
"$MANAGER" device download "${DEVICE_ARGS[@]}"

python3 - "$MANIFEST_PATH" "$DEVICES_DIR" <<'PY'
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

manifest, devices_dir = sys.argv[1:]
namespace = {'iq': 'http://www.garmin.com/xml/connectiq'}
products = [node.attrib['id'] for node in ET.parse(manifest).findall('.//iq:product', namespace)]
missing = [device for device in products if not (Path(devices_dir) / device / 'compiler.json').is_file()]
if missing:
    raise SystemExit('Missing device definitions after Garmin download: ' + ', '.join(missing))
print(f'Verified {len(products)} Connect IQ device definitions')
PY

#!/usr/bin/env bash
# Installs the bundled ConnectIQ device definitions into
# ~/.Garmin/ConnectIQ/Devices so compilers and the simulator can find them.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ARCHIVE="${SCRIPT_DIR}/devices.tar.gz"
DEVICES_HOME="${CONNECT_IQ_DEVICES_HOME:-${HOME:?HOME must be set}/.Garmin/ConnectIQ/Devices}"
echo "::debug::Device installation: archive=${ARCHIVE} destination=${DEVICES_HOME}"

if [ ! -f "${ARCHIVE}" ]; then
    echo "error: device archive not found at ${ARCHIVE}" >&2
    exit 1
fi

mkdir -p "${DEVICES_HOME}"
tar -xzf "${ARCHIVE}" -C "${DEVICES_HOME}"
echo "::debug::Device archive extracted successfully"

echo "ConnectIQ device definitions installed at ${DEVICES_HOME}"

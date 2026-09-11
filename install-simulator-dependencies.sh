#!/usr/bin/env bash
set -euo pipefail

# SDK 9.2.0 requires WebKitGTK 4.0 and libsoup 2.4.
# Use the matching distribution packages, never cross-ABI symlinks.
echo "::debug::Simulator dependency platform: kernel=$(uname -s) architecture=$(uname -m)"
if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
    echo "::error::Simulator dependencies require Ubuntu 22.04 x86_64." >&2
    exit 1
fi
source /etc/os-release
if [[ "${ID:-}" != ubuntu || "${VERSION_ID:-}" != 22.04 ]]; then
    echo "::error::Simulator dependencies require runs-on: ubuntu-22.04. SDK 9.2.0 needs WebKitGTK 4.0, which Ubuntu 24.04 does not provide." >&2
    exit 1
fi
echo "::debug::Simulator dependency OS: id=${ID:-unknown} version=${VERSION_ID:-unknown}"
: "${CONNECT_IQ_HOME:?CONNECT_IQ_HOME must name the installed SDK}"
privilege=()
if (( EUID != 0 )); then
    if ! command -v sudo >/dev/null || ! sudo -n true; then
        echo "::error::Installing simulator dependencies requires root or passwordless sudo." >&2
        exit 1
    fi
    privilege=(sudo -n)
fi
echo "::debug::Package installation privilege: $([[ ${#privilege[@]} -eq 0 ]] && echo root || echo passwordless-sudo)"
"${privilege[@]}" apt-get update
"${privilege[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    libwebkit2gtk-4.0-37 libsecret-1-0 libgtk-3-0 libusb-1.0-0 \
    libudev1 libsm6 libxxf86vm1 libxkbcommon0 libjpeg-turbo8 \
    xvfb xauth dbus-x11 fonts-dejavu-core
echo "::debug::Simulator dependency packages installed"

for executable in simulator shell; do
    echo "::debug::Checking shared libraries for ${CONNECT_IQ_HOME}/bin/${executable}"
    if ! dependencies="$(ldd "${CONNECT_IQ_HOME}/bin/${executable}" 2>&1)"; then
        printf '%s\n' "$dependencies" >&2
        exit 1
    fi
    printf '%s\n' "$dependencies"
    if [[ "$dependencies" == *"not found"* ]]; then
        echo "::error::Unresolved dependencies in ${executable}." >&2
        exit 1
    fi
done

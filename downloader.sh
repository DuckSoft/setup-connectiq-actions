#!/usr/bin/env bash
# Downloads and installs the Garmin ConnectIQ SDK.
# Based on https://github.com/matco/connectiq-tester/blob/master/downloader.sh

set -euo pipefail

CONNECT_IQ_VERSION="${CONNECT_IQ_VERSION:-latest}"
CONNECT_IQ_HOME="${CONNECT_IQ_HOME:?CONNECT_IQ_HOME must be set to the SDK install directory}"
echo "::debug::SDK request: version=${CONNECT_IQ_VERSION} install-path=${CONNECT_IQ_HOME}"

for cmd in curl jq unzip; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        echo "error: '${cmd}' is required but not installed" >&2
        exit 1
    fi
done
echo "::debug::Download prerequisites found: curl=$(command -v curl) jq=$(command -v jq) unzip=$(command -v unzip)"

CONNECTIQ_SDK_URL="https://developer.garmin.com/downloads/connect-iq/sdks"
CONNECTIQ_SDK_INFO_URL="${CONNECTIQ_SDK_URL}/sdks.json"

info="$(curl -fsSL "${CONNECTIQ_SDK_INFO_URL}")"

# Resolve the requested version and its linux download filename. Newer SDK
# manifests have a top-level "sdks" array; older ones are a plain array.
if [ "${CONNECT_IQ_VERSION}" = "latest" ]; then
    read -r version filename <<< "$(echo "${info}" | jq -r '
        (if type == "object" then .sdks else . end)
        | sort_by(.version | split(".") | map(tonumber)) | last
        | "\(.version) \(.linux)"')"
else
    read -r version filename <<< "$(echo "${info}" | jq -r --arg version "${CONNECT_IQ_VERSION}" '
        (if type == "object" then .sdks else . end)[]
        | select(.version == $version) | "\(.version) \(.linux)"')"
fi
echo "::debug::Resolved SDK request '${CONNECT_IQ_VERSION}' to version=${version:-<none>} archive=${filename:-<none>}"

if [ -z "${version}" ] || [ -z "${filename}" ] || [ "${filename}" = "null" ]; then
    echo "error: no Linux SDK download found for version '${CONNECT_IQ_VERSION}'" >&2
    exit 1
fi

marker="${CONNECT_IQ_HOME}/.sdk-version"
if [ -f "${marker}" ] && [ "$(cat "${marker}")" = "${version}" ]; then
    echo "ConnectIQ SDK ${version} is already installed at ${CONNECT_IQ_HOME}"
else
    url="${CONNECTIQ_SDK_URL}/${filename}"
    echo "Downloading ConnectIQ SDK ${version} from ${url}"

    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "${tmp_dir}"' EXIT

    curl -fsSL "${url}" -o "${tmp_dir}/connectiq.zip"

    rm -rf "${CONNECT_IQ_HOME}"
    mkdir -p "${CONNECT_IQ_HOME}"
    # unzip excluding things we do not need: docs, examples, etc.
    unzip -q "${tmp_dir}/connectiq.zip" -d "${CONNECT_IQ_HOME}" -x "doc/*" "resources/*" "samples/*" "*.html"

    echo "${version}" > "${marker}"
fi

# Export the SDK location for subsequent steps in the same workflow run.
if [ -n "${GITHUB_PATH:-}" ]; then
    echo "${CONNECT_IQ_HOME}/bin" >> "${GITHUB_PATH}"
fi
if [ -n "${GITHUB_ENV:-}" ]; then
    echo "CONNECT_IQ_HOME=${CONNECT_IQ_HOME}" >> "${GITHUB_ENV}"
fi
echo "::debug::Exported SDK bin directory to GITHUB_PATH and CONNECT_IQ_HOME to GITHUB_ENV when available"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
        echo "sdk-path=${CONNECT_IQ_HOME}"
        echo "sdk-version=${version}"
    } >> "${GITHUB_OUTPUT}"
fi

echo "ConnectIQ SDK ${version} installed at ${CONNECT_IQ_HOME}"

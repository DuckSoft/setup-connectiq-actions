# Setup ConnectIQ SDK

A composite GitHub Action for installing the Garmin ConnectIQ SDK on Linux runners.
After the setup step, later workflow steps can call tools such as `monkeyc`,
`monkeydo`, and `monkeytest` directly.

The action:

- downloads a requested ConnectIQ SDK version;
- adds the SDK's `bin` directory to `PATH`;
- exports `CONNECT_IQ_HOME`;
- installs bundled device definitions by default; and
- can optionally install the native libraries needed by the Linux simulator.

## Quick start

Use `ubuntu-latest` for compiler-only jobs. Java is required by the ConnectIQ
compiler, so install Java 17 or newer before compiling.

```yaml
name: Build

on:
  push:
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"

      - name: Set up ConnectIQ SDK
        uses: DuckSoft/setup-connectiq-actions@v1
        with:
          sdk-version: "9.2.0"

      - name: Check the compiler
        run: monkeyc --version
```

Pinning an SDK version makes builds reproducible. Use `sdk-version: latest` only
when automatically adopting new Garmin releases is intentional.

## Compile an app

`monkeyc` also needs a ConnectIQ developer key in DER format. Keep a stable key
for release builds; changing it changes the identity used to sign the app. One
common CI setup is to base64-encode the DER file and save the result as the
`CONNECTIQ_DEVELOPER_KEY_BASE64` repository secret.

```yaml
- name: Restore developer key
  shell: bash
  env:
    DEVELOPER_KEY_BASE64: ${{ secrets.CONNECTIQ_DEVELOPER_KEY_BASE64 }}
  run: printf '%s' "$DEVELOPER_KEY_BASE64" | base64 --decode > "$RUNNER_TEMP/developer_key.der"

- name: Compile
  run: >-
    monkeyc
    -f monkey.jungle
    -d fenix7
    -o bin/app.prg
    -y "$RUNNER_TEMP/developer_key.der"
```

Replace `monkey.jungle`, `fenix7`, and the output path with values appropriate
for the project.

## Inputs

| Input | Description | Default |
| --- | --- | --- |
| `sdk-version` | SDK version to install, such as `9.2.0`, or `latest`. | `9.2.0` |
| `install-path` | SDK installation directory. | `${{ runner.temp }}/connectiq` |
| `install-devices` | Install the bundled device definitions in `~/.Garmin/ConnectIQ/Devices`. | `true` |
| `install-simulator-dependencies` | Install the Linux simulator's system packages. Supported only on Ubuntu 22.04 x86_64 and requires root or passwordless `sudo`. | `false` |

Inputs are GitHub Action strings, so boolean values are written as `"true"` or
`"false"` when overriding them.

### Outputs

Give the setup step an `id` to use its outputs:

```yaml
- name: Set up ConnectIQ SDK
  id: connectiq
  uses: DuckSoft/setup-connectiq-actions@v1
  with:
    sdk-version: "9.2.0"

- name: Show installed SDK
  run: echo "SDK ${{ steps.connectiq.outputs.sdk-version }} is at ${{ steps.connectiq.outputs.sdk-path }}"
```

| Output | Description |
| --- | --- |
| `sdk-path` | Directory containing the installed SDK. The same value is exported as `CONNECT_IQ_HOME`. |
| `sdk-version` | Resolved SDK version. This is useful when the input was `latest`. |

## Run unit tests in the simulator

Simulator jobs have stricter requirements than compiler-only jobs:

- use `ubuntu-22.04` on x86_64;
- set `install-simulator-dependencies: "true"`; and
- use SDK `9.2.0`, which is the configuration tested by this repository.

The SDK 9.2.0 simulator depends on WebKitGTK 4.0, which Ubuntu 24.04 does not
provide. Do not symlink WebKitGTK 4.1 to 4.0 or mix packages from different
Ubuntu releases.

The action installs and validates the required native libraries, but it does
not start the simulator. Copy
[`tests/run-simulator-tests.sh`](tests/run-simulator-tests.sh) into the same path
in the consumer repository. The helper starts the simulator under Xvfb and
D-Bus, waits until it is ready, runs `monkeydo`, reports test failures, and
cleans up the background process.

```yaml
jobs:
  simulator-tests:
    runs-on: ubuntu-22.04
    timeout-minutes: 15
    permissions:
      contents: read

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"

      - name: Set up ConnectIQ SDK and simulator libraries
        uses: DuckSoft/setup-connectiq-actions@v1
        with:
          sdk-version: "9.2.0"
          install-simulator-dependencies: "true"

      # An ephemeral key is sufficient for CI-only test artifacts.
      - name: Create test developer key
        run: |
          openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out "$RUNNER_TEMP/test-key.pem"
          openssl pkcs8 -topk8 -inform PEM -outform DER -in "$RUNNER_TEMP/test-key.pem" -out "$RUNNER_TEMP/test-key.der" -nocrypt

      - name: Compile tests
        run: >-
          monkeyc
          -f monkey.jungle
          -d fenix7
          -o "$RUNNER_TEMP/app.prg"
          -y "$RUNNER_TEMP/test-key.der"
          -t

      - name: Run tests
        run: bash tests/run-simulator-tests.sh "$RUNNER_TEMP/app.prg" fenix7
```

The `-t` compiler flag includes unit tests in the application. The helper has a
180-second overall timeout and requires a successful test summary; a simulator
or test failure therefore fails the workflow step.

Self-hosted runners must be Ubuntu 22.04 x86_64, provide root or passwordless
`sudo`, and have the official Ubuntu Universe component enabled.

## GitHub Copilot coding agent

To make the SDK available to Copilot coding agent tasks, create
`.github/workflows/copilot-setup-steps.yml`. The workflow file and job must use
the names expected by GitHub:

```yaml
name: Copilot Setup Steps

on:
  workflow_dispatch:

jobs:
  copilot-setup-steps:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"
      - uses: DuckSoft/setup-connectiq-actions@v1
        with:
          sdk-version: "9.2.0"
```

For Copilot tasks that must run the simulator, use `ubuntu-22.04`, enable
`install-simulator-dependencies`, and invoke the simulator helper as shown
above. Setup workflows should not leave background simulator processes running.

## Updating the bundled device definitions

This section is for maintainers of this action. Garmin's SDK Manager currently
provides device definitions through its GUI rather than a headless download.
Install all devices locally with SDK Manager, run `./update-devices.sh`, and
commit the updated `devices.tar.gz`.

## Credits

Forked from
[blackshadev/garmin-connectiq-tools](https://github.com/blackshadev/garmin-connectiq-tools),
which is largely based on
[matco/connectiq-tester](https://github.com/matco/connectiq-tester).

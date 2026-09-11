# Setup ConnectIQ SDK

A composite GitHub Action that downloads and installs the
[Garmin ConnectIQ SDK](https://developer.garmin.com/connect-iq/overview/) and
the bundled device definitions, so ConnectIQ apps can be compiled and tested
in CI — including inside
[GitHub Copilot coding agent environments](https://docs.github.com/en/copilot/customizing-copilot/customizing-the-development-environment-for-copilot-coding-agent)
via `copilot-setup-steps.yml`.

The action:

- Downloads the requested SDK version (or `latest`) from Garmin.
- Adds the SDK `bin` directory (`monkeyc`, `monkeydo`, …) to `PATH`.
- Exports `CONNECT_IQ_HOME` for later steps.
- Installs the bundled device definitions into `~/.Garmin/ConnectIQ/Devices`
  (used by the compiler and `monkeydo`/`monkeytest`).

> [!NOTE]
> The ConnectIQ compiler (`monkeybrains.jar`) requires a Java runtime.
> Install one with [`actions/setup-java`](https://github.com/actions/setup-java)
> (Java 17+) before or after this action. The action warns when `java` is not
> found on `PATH`.

## Usage

```yaml
steps:
  - uses: actions/checkout@v4

  - uses: actions/setup-java@v4
    with:
      distribution: temurin
      java-version: "17"

  - name: Setup ConnectIQ SDK
    uses: DuckSoft/setup-connectiq-actions@v1
    with:
      sdk-version: "9.2.0" # or "latest"

  - name: Build
    run: monkeyc -f monkey.jungle -d fenix7 -o bin/app.prg -y developer_key
```

### Copilot coding agent (`.github/workflows/copilot-setup-steps.yml`)

```yaml
name: Copilot Setup Steps

on:
  workflow_dispatch:
  push:
    paths:
      - .github/workflows/copilot-setup-steps.yml
  pull_request:
    paths:
      - .github/workflows/copilot-setup-steps.yml

jobs:
  # The job MUST be called `copilot-setup-steps` to be picked up by Copilot.
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

      - name: Setup ConnectIQ SDK
        uses: DuckSoft/setup-connectiq-actions@v1
        with:
          sdk-version: "9.2.0" # or "latest"
```

## Inputs

| Input             | Description                                                                 | Default                     |
| ----------------- | --------------------------------------------------------------------------- | --------------------------- |
| `sdk-version`     | ConnectIQ SDK version to install (e.g. `9.2.0`), or `latest`.               | `9.2.0`                     |
| `install-path`    | Directory the SDK is installed into.                                        | `${{ runner.temp }}/connectiq` |
| `install-devices` | Extract the bundled device definitions to `~/.Garmin/ConnectIQ/Devices`.    | `true`                      |

## Outputs

| Output        | Description                                   |
| ------------- | --------------------------------------------- |
| `sdk-path`    | Directory the SDK was installed into.         |
| `sdk-version` | The SDK version that was installed.           |

## Example: compile and run unit tests

SDK 9.2.0's Linux simulator is an x86_64 GUI executable requiring WebKitGTK
4.0. Use `ubuntu-22.04` for simulator jobs. Ubuntu 24.04 does not provide the
required WebKitGTK 4.0 package. Keep compiler-only jobs on their existing runner.
Do not symlink WebKitGTK 4.1 to 4.0 or mix Ubuntu package repositories.

The optional `install-simulator-dependencies` input defaults to `false`.
When `true`, it installs the Ubuntu 22.04 runtime libraries, Xvfb, Xauth,
D-Bus tools and fonts using root or passwordless sudo, and checks shared-library
resolution. It does not start a simulator or leave a display server running.
On other OS versions or architectures it fails with an actionable error.
Self-hosted Ubuntu 22.04 runners must have the official Universe component enabled.
This configuration is tested with SDK 9.2.0; `latest` is not a compatibility guarantee.

For a consumer repository, copy `tests/run-simulator-tests.sh` from this action
into your own repository at the same path, then use:

```yaml
jobs:
  simulator-tests:
    runs-on: ubuntu-22.04
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"
      - uses: DuckSoft/setup-connectiq-actions@v1
        with:
          sdk-version: "9.2.0"
          install-simulator-dependencies: "true"
      # Provision DEVELOPER_KEY with the path to your DER signing key.
      - name: Compile tests
        run: monkeyc -f monkey.jungle -d fenix7 -o bin/app.prg -y "$DEVELOPER_KEY" -t
      - name: Run tests
        run: bash tests/run-simulator-tests.sh bin/app.prg fenix7
```

Compile with `-t` to include unit tests. On Linux, `connectiq` runs the
simulator in the foreground, so `connectiq && monkeydo ...` cannot execute tests
while the simulator is running. The helper launches the simulator in the
background, waits for its TCP listener, runs tests in the same virtual display,
propagates failures and cleans up. It times out after 180 seconds.
The new action input is available through `@v1` only after the fix is released
and that tag is updated; before release, use the reviewed fix's commit SHA.

For Copilot simulator work, likewise change the setup job to `ubuntu-22.04`
and set `install-simulator-dependencies: "true"`. Launch the simulator through
the helper when running tests; background processes from setup are not relied on.

## Updating the bundled device definitions

Garmin does not provide a headless way to download device definitions (the
SDK Manager is a GUI app). To refresh them: install all devices locally with
the SDK Manager, then run `./update-devices.sh` and commit the resulting
`devices.tar.gz`.

## Based on

Forked from [blackshadev/garmin-connectiq-tools](https://github.com/blackshadev/garmin-connectiq-tools),
which in turn is largely based on [prior work by matco](https://github.com/matco/connectiq-tester).

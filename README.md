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

```yaml
- name: Compile
  run: |
    java -jar "$CONNECT_IQ_HOME/bin/monkeybrains.jar" \
      -f monkey.jungle -d fenix7 -o bin/app.prg -y "$DEVELOPER_KEY" -l 3

- name: Run tests in the simulator
  run: connectiq && monkeydo bin/app.prg fenix7 -t
```

The simulator needs extra graphical libraries; this action targets compiling
and headless tooling.

## Updating the bundled device definitions

Garmin does not provide a headless way to download device definitions (the
SDK Manager is a GUI app). To refresh them: install all devices locally with
the SDK Manager, then run `./update-devices.sh` and commit the resulting
`devices.tar.gz`.

## Based on

Forked from [blackshadev/garmin-connectiq-tools](https://github.com/blackshadev/garmin-connectiq-tools),
which in turn is largely based on [prior work by matco](https://github.com/matco/connectiq-tester).

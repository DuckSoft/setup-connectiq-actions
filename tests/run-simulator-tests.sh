#!/usr/bin/env bash
set -euo pipefail
: "${CONNECT_IQ_HOME:?CONNECT_IQ_HOME must be set}"
if (( $# != 2 )); then
    echo "Usage: $0 app.prg device_id" >&2
    exit 2
fi
# Keep simulator, D-Bus, and monkeydo inside the same virtual display session.
exec timeout --signal=TERM --kill-after=10s 180s \
    xvfb-run -a -s "-screen 0 1280x1024x24" dbus-run-session -- \
    bash -euo pipefail -c '
        log_dir="$(mktemp -d)"
        simulator_pid=""
        cleanup() {
            if [[ -n "$simulator_pid" ]]; then
                kill "$simulator_pid" 2>/dev/null || true
                wait "$simulator_pid" 2>/dev/null || true
            fi
            cat "$log_dir/simulator.log" >&2
            rm -rf "$log_dir"
        }
        trap cleanup EXIT
        trap "exit 143" TERM
        trap "exit 130" INT
        "$CONNECT_IQ_HOME/bin/simulator" >"$log_dir/simulator.log" 2>&1 &
        simulator_pid=$!
        # The native simulator serves MonkeyDo on TCP 1234.
        ready=false
        for (( attempt=0; attempt<60; attempt++ )); do
            if ! kill -0 "$simulator_pid" 2>/dev/null; then
                echo "Simulator exited before becoming ready." >&2
                exit 1
            fi
            if (: > /dev/tcp/127.0.0.1/1234) 2>/dev/null; then
                ready=true
                break
            fi
            sleep 0.5
        done
        if [[ "$ready" != true ]]; then
            echo "Simulator did not become ready within 30 seconds." >&2
            exit 1
        fi
        "$CONNECT_IQ_HOME/bin/monkeydo" "$1" "$2" -t | tee "$log_dir/tests.log"
        # Require an actual successful test summary, even if the SDK exits zero.
        grep -Eq "^PASSED \(passed=[1-9][0-9]*, failed=0, errors=0\)[[:space:]]*$" "$log_dir/tests.log"
    ' bash "$1" "$2"

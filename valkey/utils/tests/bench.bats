#!/usr/bin/env bats

load helpers

setup() {
	setup_mocks
	BENCH="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/bench"
}

@test "logs how long a command took on stderr and keeps its stdout and exit code" {
	export VALKEY_BENCHMARK=true
	run bash -c "{ source '$BENCH'; timed 'sleepy step' bash -c 'sleep 0.2; echo payload; exit 3'; } 2>'$BATS_TEST_TMPDIR/stderr'"
	[ "$status" -eq 3 ]
	assert_equal "$output" "payload"
	[[ "$(cat "$BATS_TEST_TMPDIR/stderr")" =~ \[benchmark\]\ [0-9:]{8}\ sleepy\ step:\ ([0-9]+)ms\ \(since\ start:\ [0-9]+ms\) ]]
	[ "${BASH_REMATCH[1]}" -ge 150 ]
}

@test "logs nothing when the benchmark is disabled" {
	export VALKEY_BENCHMARK=false
	run bash -c "source '$BENCH'; timed 'quiet step' true 2>&1"
	[ "$status" -eq 0 ]
	assert_equal "$output" ""
}

@test "measures from the start of the first script that loaded it" {
	export VALKEY_BENCHMARK=true
	export BENCH_START_MS=1
	run bash -c "source '$BENCH'; bench_log 'step' \"\$(bench_now)\" 2>&1"
	[[ "$output" =~ since\ start:\ ([0-9]+)ms ]]
	[ "${BASH_REMATCH[1]}" -gt 1000000 ]
}

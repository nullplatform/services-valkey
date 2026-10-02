#!/usr/bin/env bats

load helpers

setup() {
	setup_mocks
	export OVERRIDES_PATH="$BATS_TEST_TMPDIR/overrides"
}

run_entrypoint() {
	run bash "$SERVICE_PATH/entrypoint/metric"
}

@test "runs the metric-list workflow without output for metric:list" {
	export NOTIFICATION_ACTION="metric:list"
	run_entrypoint
	[ "$status" -eq 0 ]
	assert_contains "$(cat "$MOCK_LOG")" "np service workflow exec --no-output --workflow $SERVICE_PATH/workflows/aws/metric-list.yaml --values $SERVICE_PATH/values.yaml"
}

@test "runs the metric workflow for metric:data" {
	export NOTIFICATION_ACTION="metric:data"
	run_entrypoint
	[ "$status" -eq 0 ]
	assert_contains "$(cat "$MOCK_LOG")" "--workflow $SERVICE_PATH/workflows/aws/metric.yaml "
}

@test "adds the override workflow when one exists" {
	export NOTIFICATION_ACTION="metric:data"
	mkdir -p "$OVERRIDES_PATH/workflows/aws"
	: >"$OVERRIDES_PATH/workflows/aws/metric.yaml"
	run_entrypoint
	[ "$status" -eq 0 ]
	assert_contains "$(cat "$MOCK_LOG")" "--overrides $OVERRIDES_PATH/workflows/aws/metric.yaml"
}

@test "routes metric notifications away from the service action runner" {
	export NP_ACTION_CONTEXT
	NP_ACTION_CONTEXT=$(jq -nc '{notification: {action: "metric:list", arguments: {}}}')
	run bash "$SERVICE_PATH/entrypoint/entrypoint" --service-path="$SERVICE_PATH"
	[ "$status" -eq 0 ]
	assert_contains "$(cat "$MOCK_LOG")" "--workflow $SERVICE_PATH/workflows/aws/metric-list.yaml"
	assert_not_contains "$(cat "$MOCK_LOG")" "service-action exec"
}

@test "runs the log workflow without output for log notifications" {
	export NOTIFICATION_ACTION="log:read"
	run bash "$SERVICE_PATH/entrypoint/log"
	[ "$status" -eq 0 ]
	assert_contains "$(cat "$MOCK_LOG")" "np service workflow exec --no-output --workflow $SERVICE_PATH/workflows/aws/log.yaml"
}

@test "routes log notifications away from the service action runner" {
	export NP_ACTION_CONTEXT
	NP_ACTION_CONTEXT=$(jq -nc '{notification: {action: "log:read", arguments: {}}}')
	run bash "$SERVICE_PATH/entrypoint/entrypoint" --service-path="$SERVICE_PATH"
	[ "$status" -eq 0 ]
	assert_contains "$(cat "$MOCK_LOG")" "--workflow $SERVICE_PATH/workflows/aws/log.yaml"
	assert_not_contains "$(cat "$MOCK_LOG")" "service-action exec"
}

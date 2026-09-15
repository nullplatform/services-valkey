#!/usr/bin/env bats

load helpers

setup() {
	setup_mocks
	export CONTEXT
	CONTEXT=$(link_context '{"endpoint":"np-my-cache-0f3a6-abc.serverless.usw2.cache.amazonaws.com","port":"6379"}' '{}')
	export OUTPUT_DIR="$BATS_TEST_TMPDIR/out"
	mkdir -p "$OUTPUT_DIR"
	export MOCK_TOFU_OUTPUTS='{"user_name":{"value":"np-orders-api-7d9e2-user"},"user_password":{"value":"s3cr3tp4ssw0rdvalue","sensitive":true}}'
}

@test "patches the link attributes with the user name and password" {
	run_script write_link_outputs
	[ "$status" -eq 0 ]
	assert_contains "$(cat "$MOCK_LOG")" 'np link patch --id 7d9e2f10-1234-4abc-9def-0123456789ab --body {"attributes": {"user_name":"np-orders-api-7d9e2-user","user_password":"s3cr3tp4ssw0rdvalue","connection_url":"valkeys://np-orders-api-7d9e2-user:s3cr3tp4ssw0rdvalue@np-my-cache-0f3a6-abc.serverless.usw2.cache.amazonaws.com:6379"}}'
	assert_contains "$captured_stdout" "Writing link attributes for link 7d9e2f10-1234-4abc-9def-0123456789ab (user: np-orders-api-7d9e2-user)"
	assert_not_contains "$captured_stdout" "s3cr3tp4ssw0rdvalue"
}

@test "fails instead of writing a link the application cannot authenticate with" {
	export MOCK_TOFU_OUTPUTS='{"user_name":{"value":"np-orders-api-7d9e2-user"}}'
	run_script write_link_outputs
	[ "$status" -ne 0 ]
	assert_not_contains "$(cat "$MOCK_LOG")" "np link patch"
	assert_contains "$captured_stderr" "ERROR: the user was created but its password could not be read."

	export MOCK_TOFU_OUTPUTS='{"user_password":{"value":"s3cr3tp4ssw0rdvalue"}}'
	run_script write_link_outputs
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: No user_name output found."
}

@test "defaults the port to 6379 when the service carries none" {
	CONTEXT=$(link_context '{"endpoint":"cache-host"}' '{}')
	run_script write_link_outputs
	[ "$status" -eq 0 ]
	assert_contains "$(cat "$MOCK_LOG")" '"connection_url":"valkeys://np-orders-api-7d9e2-user:s3cr3tp4ssw0rdvalue@cache-host:6379"'
}

@test "fails instead of writing a link with no connection url" {
	CONTEXT=$(link_context '{}' '{}')
	run_script write_link_outputs
	[ "$status" -ne 0 ]
	assert_not_contains "$(cat "$MOCK_LOG")" "np link patch"
	assert_contains "$captured_stderr" "ERROR: the service has no endpoint attribute yet."
}

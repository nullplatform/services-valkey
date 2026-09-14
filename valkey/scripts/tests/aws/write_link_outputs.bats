#!/usr/bin/env bats

load helpers

setup() {
	setup_mocks
	export CONTEXT
	CONTEXT=$(link_context '{}' '{}')
	export OUTPUT_DIR="$BATS_TEST_TMPDIR/out"
	mkdir -p "$OUTPUT_DIR"
	export MOCK_TOFU_OUTPUTS='{"user_name":{"value":"np-orders-api-7d9e2-user"},"user_password":{"value":"s3cr3tp4ssw0rdvalue","sensitive":true}}'
}

@test "patches the link attributes with the user name and password" {
	run_script write_link_outputs
	[ "$status" -eq 0 ]
	assert_contains "$(cat "$MOCK_LOG")" 'np link patch --id 7d9e2f10-1234-4abc-9def-0123456789ab --body {"attributes": {"user_name":"np-orders-api-7d9e2-user","user_password":"s3cr3tp4ssw0rdvalue"}}'
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

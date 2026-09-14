#!/usr/bin/env bats

load helpers

setup() {
	setup_mocks
	export CONTEXT
	CONTEXT=$(service_context '{}' '{}')
	export OUTPUT_DIR="$BATS_TEST_TMPDIR/out"
	mkdir -p "$OUTPUT_DIR"
	export MOCK_TOFU_OUTPUTS='{"endpoint":{"value":"np-my-cache-0f3a6-abc.serverless.usw2.cache.amazonaws.com"},"valkey_arn":{"value":"arn:aws:elasticache:us-west-2:2:serverlesscache:np-my-cache-0f3a6"},"cache_name":{"value":"np-my-cache-0f3a6"}}'
}

@test "patches the service attributes with the endpoint and the arn" {
	run_script write_service_outputs
	[ "$status" -eq 0 ]
	assert_contains "$(cat "$MOCK_LOG")" 'np service patch --id 0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718 --body {"attributes": {"endpoint":"np-my-cache-0f3a6-abc.serverless.usw2.cache.amazonaws.com","valkey_arn":"arn:aws:elasticache:us-west-2:2:serverlesscache:np-my-cache-0f3a6","cache_name":"np-my-cache-0f3a6"}}'
	assert_contains "$captured_stdout" "Service attributes updated."
}

@test "skips the update with a warning when the endpoint output is missing" {
	export MOCK_TOFU_OUTPUTS='{}'
	run_script write_service_outputs
	[ "$status" -eq 0 ]
	assert_not_contains "$(cat "$MOCK_LOG")" "np service patch"
	assert_contains "$captured_stdout" "WARNING: No endpoint output found. Skipping attribute update."
}

@test "persists the cache name so later actions never recompute it" {
	export MOCK_TOFU_OUTPUTS='{"endpoint":{"value":"host"},"valkey_arn":{"value":"arn"},"cache_name":{"value":"np-my-cache-0f3a6"}}'
	run_script write_service_outputs
	[ "$status" -eq 0 ]
	assert_contains "$(cat "$MOCK_LOG")" 'np service patch --id 0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718 --body {"attributes": {"endpoint":"host","valkey_arn":"arn","cache_name":"np-my-cache-0f3a6"}}'
}

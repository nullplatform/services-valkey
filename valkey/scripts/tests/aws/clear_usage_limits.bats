#!/usr/bin/env bats

load helpers

setup() {
	setup_mocks
	export CONTEXT
	CONTEXT=$(service_context '{}' '{}')
	export OUTPUT_DIR="$BATS_TEST_TMPDIR/out"
	mkdir -p "$OUTPUT_DIR"
	export CACHE_NAME="np-my-cache-0f3a6"
	export REGION="us-west-2"
	export MOCK_DESCRIBE_CACHE='{"ServerlessCaches":[{}]}'
}

limits() {
	jq -n "{data_storage_minimum_gb: null, data_storage_maximum_gb: null, ecpu_minimum: null, ecpu_maximum: null} + $1" > "$OUTPUT_DIR/terraform.tfvars.json"
}

in_aws() {
	export MOCK_DESCRIBE_CACHE
	MOCK_DESCRIBE_CACHE=$(jq -cn "{ServerlessCaches: [{CacheUsageLimits: $1}]}")
}

@test "clears a removed data storage limit by sending it as 0, keeping the one still set" {
	limits '{data_storage_minimum_gb: 2}'
	in_aws '{DataStorage: {Minimum: 2, Maximum: 10, Unit: "GB"}}'
	run_script clear_usage_limits
	[ "$status" -eq 0 ]
	assert_contains "$(cat "$MOCK_LOG")" 'aws elasticache modify-serverless-cache --serverless-cache-name np-my-cache-0f3a6 --region us-west-2 --cache-usage-limits {"DataStorage":{"Minimum":2,"Maximum":0,"Unit":"GB"}}'
}

@test "clears removed ECPU limits" {
	limits '{}'
	in_aws '{ECPUPerSecond: {Minimum: 1000, Maximum: 5000}}'
	run_script clear_usage_limits
	[ "$status" -eq 0 ]
	assert_contains "$(cat "$MOCK_LOG")" '--cache-usage-limits {"ECPUPerSecond":{"Minimum":0,"Maximum":0}}'
}

@test "does nothing when every limit in AWS is still set" {
	limits '{data_storage_maximum_gb: 10, ecpu_maximum: 5000}'
	in_aws '{DataStorage: {Maximum: 10, Unit: "GB"}, ECPUPerSecond: {Maximum: 5000}}'
	run_script clear_usage_limits
	[ "$status" -eq 0 ]
	assert_not_contains "$(cat "$MOCK_LOG")" "modify-serverless-cache"
}

@test "does nothing when the cache has no limits" {
	limits '{}'
	run_script clear_usage_limits
	[ "$status" -eq 0 ]
	assert_not_contains "$(cat "$MOCK_LOG")" "modify-serverless-cache"
}

@test "fails when build_context did not run first" {
	unset CACHE_NAME
	run_script clear_usage_limits
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: CACHE_NAME is not set. build_context must run before this script."
}

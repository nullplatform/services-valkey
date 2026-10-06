#!/usr/bin/env bats

load helpers

setup() {
	setup_mocks
	export CONTEXT
	CONTEXT=$(service_context '{}' "$(full_params)")
	export OUTPUT_DIR="$BATS_TEST_TMPDIR/out"
	mkdir -p "$OUTPUT_DIR"
	export REGION="us-west-2"
	export CACHE_NAME="np-my-cache-0f3a6"
	export POLL_SECONDS=0
	export MAX_POLLS=5
}

state_with() {
	jq -n --arg type "$1" '{resources: [{mode: "managed", type: $type, name: "cache", instances: [{attributes: {}}]}]}' > "$OUTPUT_DIR/previous-state.json"
}

run_as_workflow_step() {
	run bash -c "source '$SCRIPTS_DIR/delete_untracked_cache'; echo 'next step ran'"
}

@test "lets the next workflow step run after every successful outcome" {
	state_with aws_elasticache_serverless_cache
	run_as_workflow_step
	[ "$status" -eq 0 ]
	assert_contains "$output" "next step ran"

	state_with aws_elasticache_user_group
	run_as_workflow_step
	[ "$status" -eq 0 ]
	assert_contains "$output" "next step ran"

	export MOCK_CACHE_STATUSES="available"
	export MOCK_CACHE_TAGS='{"TagList":[]}'
	run_as_workflow_step
	[ "$status" -eq 0 ]
	assert_contains "$output" "next step ran"

	: > "$MOCK_LOG"
	export MOCK_CACHE_STATUSES="available deleting gone"
	unset MOCK_CACHE_TAGS
	setup_mocks
	run_as_workflow_step
	[ "$status" -eq 0 ]
	assert_contains "$output" "Cache np-my-cache-0f3a6 deleted."
	assert_contains "$output" "next step ran"
}

@test "leaves the cache to tofu when the state tracks it" {
	state_with aws_elasticache_serverless_cache
	export MOCK_CACHE_STATUSES="available"
	run_script delete_untracked_cache
	[ "$status" -eq 0 ]
	assert_contains "$captured_stdout" "tofu deletes it"
	assert_not_contains "$(cat "$MOCK_LOG")" "elasticache"
}

@test "does nothing when no cache exists outside the state" {
	state_with aws_elasticache_user_group
	run_script delete_untracked_cache
	[ "$status" -eq 0 ]
	assert_contains "$(cat "$MOCK_LOG")" "aws elasticache describe-serverless-caches --serverless-cache-name np-my-cache-0f3a6 --region us-west-2"
	assert_not_contains "$(cat "$MOCK_LOG")" "delete-serverless-cache"
}

@test "deletes a cache whose failed creation left it out of the state and waits until it is gone" {
	state_with aws_elasticache_user_group
	export MOCK_CACHE_STATUSES="create-failed deleting deleting gone"
	run_script delete_untracked_cache
	[ "$status" -eq 0 ]
	assert_equal "$(grep -c "aws elasticache delete-serverless-cache --serverless-cache-name np-my-cache-0f3a6 --region us-west-2" "$MOCK_LOG")" "1"
	assert_equal "$(grep -c "describe-serverless-caches" "$MOCK_LOG")" "4"
	assert_contains "$captured_stdout" "Cache np-my-cache-0f3a6 deleted."
}

@test "requests the deletion once even when the next poll still reports the old status" {
	export MOCK_CACHE_STATUSES="create-failed create-failed deleting gone"
	run_script delete_untracked_cache
	[ "$status" -eq 0 ]
	assert_equal "$(grep -c "delete-serverless-cache" "$MOCK_LOG")" "1"
}

@test "looks for the cache when there is no state at all" {
	export MOCK_CACHE_STATUSES="available gone"
	run_script delete_untracked_cache
	[ "$status" -eq 0 ]
	assert_contains "$(cat "$MOCK_LOG")" "aws elasticache delete-serverless-cache --serverless-cache-name np-my-cache-0f3a6"
}

@test "waits for a cache still being created before deleting it" {
	state_with aws_elasticache_user_group
	export MOCK_CACHE_STATUSES="creating creating available deleting gone"
	run_script delete_untracked_cache
	[ "$status" -eq 0 ]
	assert_equal "$(grep -c "delete-serverless-cache" "$MOCK_LOG")" "1"
}

@test "leaves a cache tagged with another service untouched" {
	export MOCK_CACHE_STATUSES="available"
	export MOCK_CACHE_TAGS='{"TagList":[{"Key":"service-id","Value":"another-service"}]}'
	run_script delete_untracked_cache
	[ "$status" -eq 0 ]
	assert_contains "$captured_stderr" "found 'another-service'"
	assert_not_contains "$(cat "$MOCK_LOG")" "delete-serverless-cache"
}

@test "leaves an untagged cache untouched" {
	export MOCK_CACHE_STATUSES="available"
	export MOCK_CACHE_TAGS='{"TagList":[]}'
	run_script delete_untracked_cache
	[ "$status" -eq 0 ]
	assert_not_contains "$(cat "$MOCK_LOG")" "delete-serverless-cache"
}

@test "fails instead of assuming there is no cache when the lookup is denied" {
	export MOCK_CACHE_STATUSES="denied"
	run_script delete_untracked_cache
	[ "$status" -eq 1 ]
	assert_contains "$captured_stderr" "AccessDenied"
	assert_contains "$captured_stderr" "could not check whether the cache np-my-cache-0f3a6 exists"
}

@test "fails when the cache is still there after the last poll" {
	export MOCK_CACHE_STATUSES="available deleting"
	run_script delete_untracked_cache
	[ "$status" -eq 1 ]
	assert_contains "$captured_stderr" "still exists"
	assert_equal "$(grep -c "describe-serverless-caches" "$MOCK_LOG")" "6"
}

@test "never deletes an untagged cache when the context has no service id" {
	CONTEXT=$(echo "$CONTEXT" | jq '.service.id = ""')
	export MOCK_CACHE_STATUSES="available"
	export MOCK_CACHE_TAGS='{"TagList":[]}'
	run_script delete_untracked_cache
	[ "$status" -eq 1 ]
	assert_not_contains "$(cat "$MOCK_LOG")" "delete-serverless-cache"
}

@test "fails when build_context did not export the cache name" {
	unset CACHE_NAME
	run_script delete_untracked_cache
	[ "$status" -eq 1 ]
	assert_contains "$captured_stderr" "CACHE_NAME is not set"
}

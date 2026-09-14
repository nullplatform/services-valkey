#!/usr/bin/env bats

load helpers

setup() {
	setup_mocks
	export CONTEXT
	CONTEXT=$(link_context '{"endpoint":"np-my-cache-0f3a6-abc.serverless.usw2.cache.amazonaws.com","valkey_arn":"arn:aws:elasticache:us-west-2:2:serverlesscache:np-my-cache-0f3a6"}' '{}')
	export LINK_ID="7d9e2f10-1234-4abc-9def-0123456789ab"
	export LINK_USER_NAME="np-orders-api-7d9e2-user"
	export CACHE_NAME="np-my-cache-0f3a6"
	export TFSTATE_BUCKET="np-service-0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718"
	export REGION="us-west-2"
}

@test "exports the tofu execution variables for the permissions module" {
	run_script build_permissions_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured OUTPUT_DIR)" "/tmp/np-link-7d9e2f10-1234-4abc-9def-0123456789ab"
	assert_equal "$(captured TOFU_MODULE_DIR)" "$SERVICE_PATH/permissions"
	assert_equal "$(captured TOFU_INIT_VARIABLES)" "-backend-config=bucket=np-service-0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718 -backend-config=key=links/7d9e2f10-1234-4abc-9def-0123456789ab.tfstate -backend-config=region=us-west-2 -backend-config=use_lockfile=true"
	assert_equal "$(captured TOFU_VARIABLES)" "-var=link_id=7d9e2f10-1234-4abc-9def-0123456789ab -var=region=us-west-2 -var=user_group_id=np-my-cache-0f3a6-ug -var=user_name=np-orders-api-7d9e2-user"
	assert_contains "$captured_stdout" "Link 7d9e2f10-1234-4abc-9def-0123456789ab -> cache np-my-cache-0f3a6 (user: np-orders-api-7d9e2-user)"
}

@test "fails when the cache has not been created yet" {
	CONTEXT=$(link_context '{}' '{}')
	run_script build_permissions_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: the service has no valkey_arn attribute yet."
	assert_contains "$captured_stderr" "The cache must be created before a link can be established."
}

@test "fails when build_context did not run first" {
	unset LINK_ID
	run_script build_permissions_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: LINK_ID is not set. build_context must run before this script."

	export LINK_ID="7d9e2f10-1234-4abc-9def-0123456789ab"
	unset CACHE_NAME
	run_script build_permissions_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: CACHE_NAME is not set. build_context must run before this script."
}

@test "always applies the aws_profile from values.yaml" {
	export AWS_PROFILE="from-shell"
	printf 'aws_profile: "sso-valkey"\n' > "$VALUES"
	run_script build_permissions_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured AWS_PROFILE)" "sso-valkey"
}

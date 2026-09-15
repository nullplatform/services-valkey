#!/usr/bin/env bats

load helpers

setup() {
	setup_mocks
	export REGION="us-west-2"
	export TFSTATE_BUCKET="np-valkey-state"
	export SERVICE_ID="0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718"
}

@test "deletes every version and delete marker under the service prefix" {
	export MOCK_LIST_VERSIONS='[{"Key":"services/0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718/terraform.tfstate","VersionId":"v1"}]'
	run_script delete_tfstate_objects
	[ "$status" -eq 0 ]
	assert_equal "$(grep -c 'aws s3api delete-objects' "$MOCK_LOG")" "2"
	assert_contains "$captured_stdout" "State under services/0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718/ deleted."
}

@test "never deletes the shared bucket" {
	export MOCK_LIST_VERSIONS='[{"Key":"services/0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718/terraform.tfstate","VersionId":"v1"}]'
	run_script delete_tfstate_objects
	[ "$status" -eq 0 ]
	assert_not_contains "$(cat "$MOCK_LOG")" "delete-bucket"
}

@test "scopes the listing to the service prefix so other services are untouched" {
	run_script delete_tfstate_objects
	[ "$status" -eq 0 ]
	assert_contains "$(cat "$MOCK_LOG")" "--prefix services/0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718/"
}

@test "does nothing when the service has no state left" {
	run_script delete_tfstate_objects
	[ "$status" -eq 0 ]
	assert_not_contains "$(cat "$MOCK_LOG")" "delete-objects"
	assert_contains "$captured_stdout" "No object versions to delete."
	assert_contains "$captured_stdout" "No delete markers to delete."
}

@test "fails when REGION was not exported by build_context" {
	unset REGION
	run_script delete_tfstate_objects
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: REGION is not set. Expected to be exported by build_context."
}

@test "fails when SERVICE_ID was not exported by build_context" {
	unset SERVICE_ID
	run_script delete_tfstate_objects
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: SERVICE_ID is not set. build_context must run before this script."
}

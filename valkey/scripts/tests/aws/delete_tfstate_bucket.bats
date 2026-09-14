#!/usr/bin/env bats

load helpers

setup() {
	setup_mocks
	export REGION="us-west-2"
	export TFSTATE_BUCKET="np-service-0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718"
}

@test "empties every version and delete marker before deleting the bucket" {
	export MOCK_LIST_VERSIONS='[{"Key":"terraform.tfstate","VersionId":"v1"}]'
	run_script delete_tfstate_bucket
	[ "$status" -eq 0 ]
	assert_equal "$(grep -c 'aws s3api delete-objects' "$MOCK_LOG")" "2"
	assert_contains "$(cat "$MOCK_LOG")" "aws s3api delete-bucket --bucket np-service-0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718 --region us-west-2"
	assert_contains "$captured_stdout" "Bucket np-service-0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718 deleted."
}

@test "deletes an already empty bucket without calling delete-objects" {
	run_script delete_tfstate_bucket
	[ "$status" -eq 0 ]
	assert_not_contains "$(cat "$MOCK_LOG")" "delete-objects"
	assert_contains "$captured_stdout" "No object versions to delete."
	assert_contains "$captured_stdout" "No delete markers to delete."
	assert_contains "$(cat "$MOCK_LOG")" "aws s3api delete-bucket"
}

@test "does nothing when the bucket is already gone" {
	export MOCK_BUCKET_EXISTS=1
	run_script delete_tfstate_bucket
	[ "$status" -eq 0 ]
	assert_not_contains "$(cat "$MOCK_LOG")" "delete-bucket"
	assert_contains "$captured_stdout" "Bucket np-service-0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718 does not exist, nothing to delete."
}

@test "fails when REGION was not exported by build_context" {
	unset REGION
	run_script delete_tfstate_bucket
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: REGION is not set. Expected to be exported by build_context."
}

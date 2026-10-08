#!/usr/bin/env bats

load helpers

setup() {
	setup_mocks
	REQUIREMENTS="$SERVICE_PATH/specs/requirements/aws"
	MAIN="$REQUIREMENTS/main.tf"
	LOCALS="$REQUIREMENTS/locals.tf"
}

@test "listing the state bucket is not restricted by prefix: HeadBucket and the S3 backend list without the service prefix" {
	run grep -rn 's3:prefix' "$REQUIREMENTS"
	[ "$status" -ne 0 ]
	assert_contains "$(grep -A8 'ListStateBucket' "$MAIN")" '"s3:ListBucket"'
}

@test "reading and writing state objects stays under services/valkey/" {
	assert_contains "$(grep -A12 'ManageStateObjects' "$MAIN")" '/services/valkey/*"'
	run grep -n 'state_bucket_name}/\*"' "$MAIN"
	[ "$status" -ne 0 ]
}

@test "public caches can be managed through Cloud Control, which the awscc provider uses" {
	block=$(grep -A14 'ManagePublicCachesThroughCloudControl' "$MAIN")
	for action in CreateResource GetResource UpdateResource DeleteResource GetResourceRequestStatus; do
		assert_contains "$block" "\"cloudformation:${action}\""
	done
}

@test "link users can only be created or given a policy when they carry the link boundary" {
	block=$(grep -A10 'CreateBoundedLinkIamUsers' "$MAIN")
	assert_contains "$block" '"iam:CreateUser", "iam:PutUserPolicy"'
	assert_contains "$block" '"iam:PermissionsBoundary" = local.link_boundary_arn'
	assert_contains "$(grep -A10 'KeepTheLinkBoundary' "$MAIN")" '"iam:DeleteUserPermissionsBoundary"'
	assert_contains "$(grep -A10 'KeepTheLinkBoundary' "$MAIN")" 'Effect = "Deny"'
	run grep -n '"iam:CreateUser"' "$MAIN"
	[ "${#lines[@]}" -eq 1 ]
}

@test "every link user permission is scoped to the link users' path" {
	for sid in CreateBoundedLinkIamUsers ManageLinkIamUsers KeepTheLinkBoundary; do
		assert_contains "$(grep -A25 "$sid" "$MAIN" | grep -m1 'Resource')" 'local.link_users_arn' || { echo "$sid"; return 1; }
	done
	run grep -n 'user/${var.cache_name_prefix}\*' "$REQUIREMENTS"/*.tf
	[ "$status" -ne 0 ]
}

@test "the link boundary only lets its users connect to a cache" {
	block=$(sed -n '/resource "aws_iam_policy" "link_boundary"/,/^}/p' "$MAIN")
	assert_contains "$block" 'Action   = "elasticache:Connect"'
	[ "$(echo "$block" | grep -c 'Action')" -eq 1 ]
}

@test "the requirements and the link module agree on the link users' path and boundary" {
	assert_contains "$(grep 'link_iam_path *=' "$LOCALS")" '"/nullplatform/valkey/"'
	assert_contains "$(grep 'link_iam_path *=' "$SERVICE_PATH/permissions/locals.tf")" '"/nullplatform/valkey/"'
	assert_contains "$(grep 'link_boundary_name *=' "$LOCALS")" 'valkey-link-boundary"'
	assert_contains "$(grep 'link_boundary_arn *=' "$SERVICE_PATH/permissions/locals.tf")" 'np-valkey-link-boundary"'
}

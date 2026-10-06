#!/usr/bin/env bats

load helpers

setup() {
	setup_mocks
	export CONTEXT
	CONTEXT=$(service_context '{}' "$(full_params)")
}

@test "derives the cache name from the service slug and the first five characters of its id" {
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured CACHE_NAME)" "np-my-cache-0f3a6"
	assert_equal "$(captured SERVICE_ID)" "0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718"
}

@test "sanitizes and truncates a long mixed-case slug so the cache name stays within 36 characters" {
	CONTEXT=$(echo "$CONTEXT" | jq '.service.slug = "My_Very.Long Cache Name With Spaces And More-"')
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured CACHE_NAME)" "np-my-very-long-cache-name-wit-0f3a6"
	[ "$(captured CACHE_NAME | wc -c)" -le 37 ]
}

@test "falls back to the service name and then to the id alone when the slug is missing" {
	CONTEXT=$(echo "$CONTEXT" | jq 'del(.service.slug)')
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured CACHE_NAME)" "np-my-cache-0f3a6"

	CONTEXT=$(echo "$CONTEXT" | jq 'del(.service.name) | .service.slug = "___"')
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured CACHE_NAME)" "np-0f3a6"
}

@test "resolves the region and the network from the providers of the service nrn" {
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured REGION)" "us-west-2"
	assert_equal "$(captured VPC_ID)" "vpc-0123"
	assert_equal "$(captured SUBNET_IDS)" '["subnet-a","subnet-b"]'
	assert_contains "$(cat "$MOCK_LOG")" "np provider list --nrn organization=1:account=2:namespace=3:application=4 --categories cloud-providers --format json"
	assert_contains "$(cat "$MOCK_LOG")" "np provider list --nrn organization=1:account=2:namespace=3:application=4 --categories vpc --format json"
}

@test "looks the providers up by the entity nrn when the context has one" {
	CONTEXT=$(echo "$CONTEXT" | jq '.entity_nrn = "organization=1:account=2:namespace=9"')
	run_script build_context
	[ "$status" -eq 0 ]
	assert_contains "$(cat "$MOCK_LOG")" "--nrn organization=1:account=2:namespace=9 --categories vpc"
	assert_not_contains "$(cat "$MOCK_LOG")" "application=4"
}

@test "passes the service dimensions to every provider lookup" {
	CONTEXT=$(echo "$CONTEXT" | jq '.service.dimensions = {environment: "prod", country: "ar"}')
	run_script build_context
	[ "$status" -eq 0 ]
	assert_contains "$(cat "$MOCK_LOG")" "--categories cloud-providers --dimensions environment:prod,country:ar"
	assert_contains "$(cat "$MOCK_LOG")" "--categories vpc --dimensions environment:prod,country:ar"
}

@test "omits the dimensions flag when the service has no dimensions" {
	run_script build_context
	[ "$status" -eq 0 ]
	assert_not_contains "$(cat "$MOCK_LOG")" "--dimensions"
}

@test "ignores the legacy network attributes and values.yaml settings" {
	CONTEXT=$(service_context '{"aws_region":"us-east-1","vpc_id":"vpc-0dd","subnet_ids":"subnet-old"}' "$(full_params)")
	printf 'aws_profile: ""\nvpc_id: "vpc-from-values"\nsubnet_ids: "subnet-v1,subnet-v2"\n' > "$VALUES"
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured REGION)" "us-west-2"
	assert_equal "$(captured VPC_ID)" "vpc-0123"
	assert_equal "$(captured SUBNET_IDS)" '["subnet-a","subnet-b"]'
}

@test "fails when the context carries no nrn" {
	CONTEXT=$(echo "$CONTEXT" | jq 'del(.service.nrn)')
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: could not read the service NRN"
}

@test "fails with a clear message when no cloud-providers provider has a region" {
	export MOCK_NP_CLOUD_PROVIDERS='{"results":[]}'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: no cloud-providers provider with account.region found for organization=1:account=2:namespace=3:application=4"
}

@test "fails with a clear message when no vpc provider has a vpc id" {
	export MOCK_NP_VPC_PROVIDERS='{"results":[]}'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: no vpc provider with vpc.id found for organization=1:account=2:namespace=3:application=4"
}

@test "fails when the vpc provider lists no subnets" {
	export MOCK_NP_VPC_PROVIDERS='{"results":[{"attributes":{"vpc":{"id":"vpc-0123","subnets":[]}}}]}'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "has no vpc.subnets"

	export MOCK_NP_VPC_PROVIDERS='{"results":[{"attributes":{"vpc":{"id":"vpc-0123"}}}]}'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "has no vpc.subnets"
}

@test "fails before running tofu when a provider value is not a well-formed aws id" {
	export MOCK_NP_CLOUD_PROVIDERS='{"results":[{"attributes":{"account":{"region":"us-east-1 -backend-config=bucket=evil"}}}]}'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "which is not an AWS region"
	assert_not_contains "$(cat "$MOCK_LOG")" "s3api head-bucket"

	unset MOCK_NP_CLOUD_PROVIDERS
	setup_mocks
	export MOCK_NP_VPC_PROVIDERS='{"results":[{"attributes":{"vpc":{"id":"vpc-1 -var=kms_key_arn=x","subnets":["subnet-a"]}}}]}'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "which is not a VPC ID"

	export MOCK_NP_VPC_PROVIDERS='{"results":[{"attributes":{"vpc":{"id":"vpc-0123","subnets":["subnet-a","not a subnet"]}}}]}'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "which is not a subnet ID"
}

@test "fails when the tofu state records a malformed vpc id" {
	export MOCK_STATE_JSON='{"resources":[{"mode":"managed","type":"aws_security_group","name":"cache","instances":[{"attributes":{"vpc_id":"vpc-1 -var=x=y"}}]}]}'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "the tofu state gives"
}

@test "writes the provider subnets to the tfvars file as a list" {
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(jq -c '.subnet_ids' /tmp/np-service-0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718/terraform.tfvars.json)" '["subnet-a","subnet-b"]'
}

@test "keeps the vpc, subnets and region of an existing cache when the providers resolve others" {
	export MOCK_STATE_JSON='{"resources":[{"mode":"managed","type":"aws_security_group","name":"cache","instances":[{"attributes":{"vpc_id":"vpc-0dd"}}]},{"mode":"managed","type":"aws_elasticache_serverless_cache","name":"cache","instances":[{"attributes":{"arn":"arn:aws:elasticache:us-east-1:222222222222:serverlesscache:np-my-cache-0f3a6","subnet_ids":["subnet-0ddb","subnet-0dda"]}}]}]}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured VPC_ID)" "vpc-0dd"
	assert_equal "$(captured SUBNET_IDS)" '["subnet-0dda","subnet-0ddb"]'
	assert_equal "$(captured REGION)" "us-east-1"
	assert_contains "$(captured TOFU_VARIABLES)" "-var=region=us-east-1"
	assert_contains "$(captured TOFU_VARIABLES)" "-var=vpc_id=vpc-0dd"
	assert_equal "$(jq -c '.subnet_ids' /tmp/np-service-0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718/terraform.tfvars.json)" '["subnet-0dda","subnet-0ddb"]'
	assert_contains "$captured_stderr" "keeping vpc-0dd so the cache is not replaced"
}

@test "keeps only the subnets of an existing cache when the vpc and region already match" {
	export MOCK_STATE_JSON='{"resources":[{"mode":"managed","type":"aws_security_group","name":"cache","instances":[{"attributes":{"vpc_id":"vpc-0123"}}]},{"mode":"managed","type":"aws_elasticache_serverless_cache","name":"cache","instances":[{"attributes":{"arn":"arn:aws:elasticache:us-west-2:222222222222:serverlesscache:np-my-cache-0f3a6","subnet_ids":["subnet-a","subnet-c"]}}]}]}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured VPC_ID)" "vpc-0123"
	assert_equal "$(captured REGION)" "us-west-2"
	assert_equal "$(captured SUBNET_IDS)" '["subnet-a","subnet-c"]'
	assert_contains "$captured_stderr" "keeping them so the cache is not replaced"
	assert_not_contains "$captured_stderr" "keeping vpc-"
}

@test "keeps the providers network when the state has no cache resources" {
	export MOCK_STATE_JSON='{"resources":[]}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured VPC_ID)" "vpc-0123"
	assert_equal "$(captured SUBNET_IDS)" '["subnet-a","subnet-b"]'
	assert_not_contains "$captured_stderr" "WARNING"
}

@test "does not warn when the existing cache already matches the providers" {
	export MOCK_STATE_JSON='{"resources":[{"mode":"managed","type":"aws_security_group","name":"cache","instances":[{"attributes":{"vpc_id":"vpc-0123"}}]},{"mode":"managed","type":"aws_elasticache_serverless_cache","name":"cache","instances":[{"attributes":{"arn":"arn:aws:elasticache:us-west-2:222222222222:serverlesscache:np-my-cache-0f3a6","subnet_ids":["subnet-b","subnet-a"]}}]}]}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured SUBNET_IDS)" '["subnet-a","subnet-b"]'
	assert_not_contains "$captured_stderr" "WARNING"
}

@test "exports the tofu execution variables for the deployment module" {
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured OUTPUT_DIR)" "/tmp/np-service-0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718"
	assert_equal "$(captured TOFU_MODULE_DIR)" "$SERVICE_PATH/deployment"
	assert_equal "$(captured TFSTATE_BUCKET)" "np-valkey-state"
	assert_equal "$(captured TFSTATE_KEY_PREFIX)" "services/valkey/0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718/"
	assert_equal "$(captured TOFU_INIT_VARIABLES)" "-backend-config=bucket=np-valkey-state -backend-config=key=services/valkey/0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718/terraform.tfstate -backend-config=region=us-west-2 -backend-config=use_lockfile=true"
	assert_equal "$(captured TOFU_VARIABLES)" "-var=service_id=0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718 -var=region=us-west-2 -var=cache_name=np-my-cache-0f3a6 -var=vpc_id=vpc-0123 -var-file=/tmp/np-service-0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718/terraform.tfvars.json"
}

@test "writes the context tags to the tfvars file keeping only string values" {
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(jq -cS '.tags' /tmp/np-service-0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718/terraform.tfvars.json)" \
		'{"account":"acc","account_id":"2","application":"app","application_id":"4","namespace":"ns","namespace_id":"3","organization":"org","organization_id":"1"}'
}

@test "fails when VALKEY_S3_STATE_BUCKET is not set" {
	unset VALKEY_S3_STATE_BUCKET
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: VALKEY_S3_STATE_BUCKET is not set"
}

@test "fails when VALKEY_S3_STATE_BUCKET is set to an empty value" {
	export VALKEY_S3_STATE_BUCKET=""
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: VALKEY_S3_STATE_BUCKET is not set"
}

@test "fails when the state bucket does not exist" {
	export MOCK_BUCKET_EXISTS=1
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: the state bucket np-valkey-state does not exist"
}

@test "never creates or configures the state bucket" {
	run_script build_context
	[ "$status" -eq 0 ]
	assert_not_contains "$(cat "$MOCK_LOG")" "create-bucket"
	assert_not_contains "$(cat "$MOCK_LOG")" "put-bucket-versioning"
}

@test "never injects the access key from the service attributes" {
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured AWS_ACCESS_KEY_ID)" ""
	assert_equal "$(captured AWS_SECRET_ACCESS_KEY)" ""
	assert_not_contains "$captured_stdout" "AKIASTATIC"
}

@test "leaves the credentials from the assume-role step untouched" {
	export AWS_ACCESS_KEY_ID="ASIAASSUMED"
	export AWS_SECRET_ACCESS_KEY="assumed-secret"
	export AWS_SESSION_TOKEN="token"
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured AWS_ACCESS_KEY_ID)" "ASIAASSUMED"
	assert_equal "$(captured AWS_SECRET_ACCESS_KEY)" "assumed-secret"
	assert_equal "$(captured AWS_SESSION_TOKEN)" "token"
}

@test "always applies the aws_profile from values.yaml" {
	export AWS_PROFILE="from-shell"
	printf 'aws_profile: "sso-valkey"\n' > "$VALUES"
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured AWS_PROFILE)" "sso-valkey"
}

@test "exports the link identity and the derived user name on link actions" {
	export ACTION_SOURCE=link
	CONTEXT=$(link_context '{}' "$(full_params)")
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured LINK_ID)" "7d9e2f10-1234-4abc-9def-0123456789ab"
	assert_equal "$(captured LINK_USER_NAME)" "np-orders-api-7d9e2-user"
}

@test "truncates a long link slug so the user name stays within 40 characters" {
	export ACTION_SOURCE=link
	CONTEXT=$(link_context '{}' "$(full_params)" | jq '.link.slug = "a-really-long-link-slug-that-goes-on-forever"')
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured LINK_USER_NAME)" "np-a-really-long-link-slug-th-7d9e2-user"
}

@test "does not export link variables on service actions" {
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured LINK_ID)" ""
}

@test "reuses the cache name already stored in the service attributes instead of recomputing it" {
	CONTEXT=$(service_context '{"cache_name":"np-old-slug-0f3a6"}' "$(full_params)")
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured CACHE_NAME)" "np-old-slug-0f3a6"
	assert_contains "$captured_stderr" "Using existing cache_name from service attributes: np-old-slug-0f3a6"
}

@test "takes the cache name from the user group in the state when a failed create left no attributes" {
	CONTEXT=$(echo "$CONTEXT" | jq '.service.slug = "renamed"')
	export MOCK_STATE_JSON='{"resources":[{"mode":"managed","type":"aws_elasticache_user_group","name":"cache","instances":[{"attributes":{"user_group_id":"np-my-cache-0f3a6-ug"}}]}]}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured CACHE_NAME)" "np-my-cache-0f3a6"
	assert_contains "$captured_stderr" "Using cache_name from the tofu state: np-my-cache-0f3a6"
}

@test "prefers the cache name in the state over the service attributes" {
	CONTEXT=$(service_context '{"cache_name":"np-other-0f3a6"}' "$(full_params)")
	export MOCK_STATE_JSON='{"resources":[{"mode":"managed","type":"aws_elasticache_user_group","name":"cache","instances":[{"attributes":{"user_group_id":"np-my-cache-0f3a6-ug"}}]}]}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured CACHE_NAME)" "np-my-cache-0f3a6"
}

@test "does not leave a state file from an earlier run for the later steps" {
	mkdir -p /tmp/np-service-0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718
	echo '{"resources":[]}' > /tmp/np-service-0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718/previous-state.json
	run_script build_context
	[ "$status" -eq 0 ]
	[ ! -e /tmp/np-service-0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718/previous-state.json ]
}

@test "passes the configured kms key on create when there is no state yet" {
	export VALKEY_KMS_KEY_ARN="arn:aws:kms:us-west-2:222222222222:key/1234abcd-12ab-34cd-56ef-1234567890ab"
	CONTEXT=$(service_context '{}' "$(full_params)" | jq '.type = "create"')
	run_script build_context
	[ "$status" -eq 0 ]
	assert_contains "$(captured TOFU_VARIABLES)" "-var=kms_key_arn=arn:aws:kms:us-west-2:222222222222:key/1234abcd-12ab-34cd-56ef-1234567890ab"
}

@test "creates a dedicated key when no kms key is configured" {
	CONTEXT=$(service_context '{}' "$(full_params)" | jq '.type = "create"')
	run_script build_context
	[ "$status" -eq 0 ]
	assert_not_contains "$(captured TOFU_VARIABLES)" "kms_key_arn"
}

@test "keeps the module managing its own key when the state already owns one" {
	export VALKEY_KMS_KEY_ARN="arn:aws:kms:us-west-2:222222222222:key/1234abcd-12ab-34cd-56ef-1234567890ab"
	export MOCK_STATE_JSON='{"resources":[{"mode":"managed","type":"aws_kms_key","name":"cache","instances":[{"attributes":{"arn":"arn:aws:kms:us-west-2:222222222222:key/99999999-9999-9999-9999-999999999999"}}]},{"mode":"managed","type":"aws_elasticache_serverless_cache","name":"cache","instances":[{"attributes":{"kms_key_id":"arn:aws:kms:us-west-2:222222222222:key/99999999-9999-9999-9999-999999999999"}}]}]}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_not_contains "$(captured TOFU_VARIABLES)" "kms_key_arn"
}

@test "reuses the external key recorded in the state instead of the configured one" {
	export VALKEY_KMS_KEY_ARN="arn:aws:kms:us-west-2:222222222222:key/1234abcd-12ab-34cd-56ef-1234567890ab"
	export MOCK_STATE_JSON='{"resources":[{"mode":"managed","type":"aws_elasticache_serverless_cache","name":"cache","instances":[{"attributes":{"kms_key_id":"arn:aws:kms:us-west-2:222222222222:key/99999999-9999-9999-9999-999999999999"}}]}]}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_contains "$(captured TOFU_VARIABLES)" "-var=kms_key_arn=arn:aws:kms:us-west-2:222222222222:key/99999999-9999-9999-9999-999999999999"
	assert_not_contains "$(captured TOFU_VARIABLES)" "arn:aws:kms:us-west-2:222222222222:key/1234abcd-12ab-34cd-56ef-1234567890ab"
}

@test "ignores the configured key on actions other than create" {
	export VALKEY_KMS_KEY_ARN="arn:aws:kms:us-west-2:222222222222:key/1234abcd-12ab-34cd-56ef-1234567890ab"
	CONTEXT=$(service_context '{}' "$(full_params)" | jq '.type = "update"')
	run_script build_context
	[ "$status" -eq 0 ]
	assert_not_contains "$(captured TOFU_VARIABLES)" "kms_key_arn"
}

@test "fails when the configured kms key is not a key arn" {
	export VALKEY_KMS_KEY_ARN="alias/my-key"
	CONTEXT=$(service_context '{}' "$(full_params)" | jq '.type = "create"')
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "is not a KMS key ARN"
}

@test "fails instead of guessing when the state cannot be read" {
	export MOCK_STATE_JSON="denied"
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "could not read the tofu state"
	assert_contains "$captured_stderr" "AccessDenied"
}

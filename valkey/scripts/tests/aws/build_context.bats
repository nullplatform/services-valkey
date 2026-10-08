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
	assert_equal "$(captured TOFU_VARIABLES)" "-var=service_id=0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718 -var=region=us-west-2 -var=cache_name=np-my-cache-0f3a6 -var=vpc_id=vpc-0123 -var=engine_version=9 -var-file=/tmp/np-service-0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718/terraform.tfvars.json"
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

tfvars() {
	jq -c "$1" /tmp/np-service-0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718/terraform.tfvars.json
}

# Each call starts from a fresh service context, so the cases of one test do not leak into the next.
with_params() {
	CONTEXT=$(service_context '{}' "$(full_params)" | jq "$1")
}

# A tofu state holding an existing cache, as build_context downloads it.
existing_cache() {
	local type="${1:-aws_elasticache_serverless_cache}" name="${2:-cache}" attrs="${3:-{\}}"
	export MOCK_STATE_JSON
	MOCK_STATE_JSON=$(jq -cn --arg type "$type" --arg name "$name" --argjson attrs "$attrs" '{resources: [
		{mode: "managed", type: "aws_elasticache_user_group", name: "cache", instances: [{attributes: {user_group_id: "np-my-cache-0f3a6-ug"}}]},
		{mode: "managed", type: $type, name: $name, instances: [{attributes: ({
			arn: "arn:aws:elasticache:us-west-2:222222222222:serverlesscache:np-my-cache-0f3a6",
			subnet_ids: ["subnet-a", "subnet-b"], kms_key_id: "arn:aws:kms:us-west-2:222222222222:key/own"} + $attrs)}]},
		{mode: "managed", type: "aws_kms_key", name: "cache", instances: [{attributes: {}}]}
	]}')
}

@test "merges the developer's tags under the platform tags, which cannot be overridden" {
	with_params '.parameters.tags = [{"key":" team ","value":" payments "},{"key":"account_id","value":"spoofed"},{"key":"","value":"x"}]'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvars '[.tags.team, .tags.account_id, (.tags | has(""))]')" '["payments","2",false]'
}

@test "keeps a tag with no value and accepts the tags as a key=value string" {
	with_params '.parameters.tags = [{"key":"cost-center"}]'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvars '.tags["cost-center"]')" '""'

	with_params '.parameters.tags = "team=payments, env = prod,expr=a=b"'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvars '.tags | {team, env, expr}')" '{"team":"payments","env":"prod","expr":"a=b"}'
}

@test "rejects a tag key that starts with aws:" {
	with_params '.parameters.tags = [{"key":"aws:team","value":"x"}]'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: tag keys must not start with aws:"
}

@test "defaults to a Valkey 9 VPC cache with IPv4, the default security group, no backups and no usage limits" {
	run_script build_context
	[ "$status" -eq 0 ]
	assert_contains "$(captured TOFU_VARIABLES)" "-var=engine_version=9"
	assert_equal "$(tfvars '{connection_type, network_type, security_group_ids, snapshot_retention_limit, daily_snapshot_time}')" \
		'{"connection_type":"vpc","network_type":"ipv4","security_group_ids":[],"snapshot_retention_limit":0,"daily_snapshot_time":""}'
	assert_equal "$(tfvars '[.data_storage_minimum_gb, .data_storage_maximum_gb, .ecpu_minimum, .ecpu_maximum]')" '[null,null,null,null]'
}

@test "creates a public cache without a vpc provider" {
	export MOCK_NP_VPC_PROVIDERS='{"results":[]}'
	with_params '.parameters += {engine_version: "9", connection_type: "public"}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_contains "$(captured TOFU_VARIABLES)" "-var=vpc_id= -var=engine_version=9"
	assert_equal "$(tfvars '[.connection_type, .subnet_ids]')" '["public",[]]'
}

@test "rejects a public cache before Valkey 9 and an unknown connection type" {
	with_params '.parameters += {engine_version: "8", connection_type: "public"}'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: the public connection type requires Valkey 9"

	with_params '.parameters += {engine_version: "9", connection_type: "internet"}'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: connection_type must be vpc or public"
}

@test "upgrades the engine of an existing cache but never downgrades it" {
	existing_cache aws_elasticache_serverless_cache cache '{"major_engine_version":"8"}'
	with_params '.parameters.engine_version = "9"'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_contains "$(captured TOFU_VARIABLES)" "-var=engine_version=9"

	existing_cache aws_elasticache_serverless_cache cache '{"major_engine_version":"9"}'
	with_params '.parameters.engine_version = "8"'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: the engine can only be upgraded (from 9 to 8 is a downgrade)"
}

@test "keeps the connection type and network type an existing cache was created with" {
	existing_cache awscc_elasticache_serverless_cache public '{"major_engine_version":"9","network_type":"dual_stack"}'
	with_params '.parameters += {connection_type: "vpc", settings_mode: "default"}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvars '[.connection_type, .network_type]')" '["public","dual_stack"]'
}

@test "passes the network type on create and rejects an unknown one" {
	with_params '.parameters += {settings_mode: "customize", network_type: "dual_stack"}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvars '.network_type')" '"dual_stack"'

	with_params '.parameters += {settings_mode: "customize", network_type: "ipv5"}'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: network_type must be ipv4, ipv6 or dual_stack"
}

@test "places the cache in the VPC and subnets the developer sets, overriding the vpc provider" {
	with_params '.parameters += {settings_mode: "customize", vpc_id: "vpc-0abc", subnet_ids: "subnet-0aa, subnet-0bb"}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured VPC_ID)" "vpc-0abc"
	assert_equal "$(tfvars '.subnet_ids')" '["subnet-0aa","subnet-0bb"]'

	with_params '.parameters += {settings_mode: "customize", vpc_id: "vpc-0abc", subnet_ids: ""}'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: set both vpc_id and subnet_ids"
}

@test "ignores the network override while the default settings are selected" {
	with_params '.parameters += {settings_mode: "default", vpc_id: "vpc-0abc", subnet_ids: "subnet-0aa"}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured VPC_ID)" "vpc-0123"
}

@test "uses the existing key chosen in the security settings instead of a dedicated one, and requires its ARN" {
	with_params '.type = "create" | .parameters += {settings_mode: "customize", security_settings: "customize", encryption_key: "existing", kms_key_arn: " arn:aws:kms:us-west-2:111122223333:key/abc "}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_contains "$(captured TOFU_VARIABLES)" "-var=kms_key_arn=arn:aws:kms:us-west-2:111122223333:key/abc"

	with_params '.type = "create" | .parameters += {settings_mode: "customize", security_settings: "customize", encryption_key: "existing", kms_key_arn: ""}'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: kms_key_arn is required when encryption_key is existing"
}

@test "keeps the dedicated key while the default security settings are selected" {
	with_params '.type = "create" | .parameters += {settings_mode: "customize", security_settings: "default", encryption_key: "existing", kms_key_arn: "arn:aws:kms:us-west-2:111122223333:key/abc"}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_not_contains "$(captured TOFU_VARIABLES)" "kms_key_arn"
}

@test "replaces the default security group with the selected ones, from a list or a comma-separated string" {
	with_params '.parameters += {settings_mode: "customize", security_settings: "customize", security_group_ids: ["sg-1", " sg-2 ", ""]}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvars '.security_group_ids')" '["sg-1","sg-2"]'

	with_params '.parameters += {settings_mode: "customize", security_settings: "customize", security_group_ids: "sg-1, sg-2"}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvars '.security_group_ids')" '["sg-1","sg-2"]'
}

@test "drops the selected security groups on a public cache" {
	with_params '.parameters += {engine_version: "9", connection_type: "public", settings_mode: "customize", security_settings: "customize", security_group_ids: ["sg-1"]}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvars '.security_group_ids')" '[]'
}

@test "turns on automatic backups with a one day retention unless another is given" {
	with_params '.parameters += {settings_mode: "customize", automatic_backups: "enabled"}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvars '[.snapshot_retention_limit, .daily_snapshot_time]')" '[1,""]'

	with_params '.parameters += {settings_mode: "customize", automatic_backups: "enabled", backup_retention_days: 7, backup_window_start: "04:30"}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvars '[.snapshot_retention_limit, .daily_snapshot_time]')" '[7,"04:30"]'
}

@test "rejects a backup retention outside 1-35 days and a malformed backup time" {
	with_params '.parameters += {settings_mode: "customize", automatic_backups: "enabled", backup_retention_days: 36}'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: backup_retention_days must be between 1 and 35"

	with_params '.parameters += {settings_mode: "customize", automatic_backups: "enabled", backup_window_start: "25:00"}'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: backup_window_start must be a UTC time as HH:MM"
}

@test "passes the usage limits that are set, reading 0 as no limit" {
	with_params '.parameters += {settings_mode: "customize", usage_limits: "set", data_storage_minimum_gb: 0, data_storage_maximum_gb: 10, ecpu_minimum: 1000, ecpu_maximum: 5000}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvars '[.data_storage_minimum_gb, .data_storage_maximum_gb, .ecpu_minimum, .ecpu_maximum]')" '[null,10,1000,5000]'
}

@test "clears every usage limit when they are set back to not set, whatever values were stored" {
	with_params '.service.attributes += {data_storage_maximum_gb: 10} | .parameters += {settings_mode: "customize", usage_limits: "not_set", data_storage_maximum_gb: 10}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvars '[.data_storage_minimum_gb, .data_storage_maximum_gb, .ecpu_minimum, .ecpu_maximum]')" '[null,null,null,null]'
}

@test "rejects usage limits out of range or with a minimum above the maximum" {
	with_params '.parameters += {settings_mode: "customize", usage_limits: "set", data_storage_maximum_gb: 5001}'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: data_storage_maximum_gb must be 0 (no limit) or between 1 and 5000"

	with_params '.parameters += {settings_mode: "customize", usage_limits: "set", ecpu_minimum: 999}'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: ecpu_minimum must be 0 (no limit) or between 1000 and 15000000"

	with_params '.parameters += {settings_mode: "customize", usage_limits: "set", data_storage_minimum_gb: 20, data_storage_maximum_gb: 10}'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: data_storage_minimum_gb must not exceed data_storage_maximum_gb"
}

@test "ignores customized values while the default settings are selected, and rejects an unknown mode" {
	with_params '.parameters += {settings_mode: "default", network_type: "dual_stack", security_settings: "customize", security_group_ids: ["sg-1"], automatic_backups: "enabled", usage_limits: "set", data_storage_maximum_gb: 10}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvars '{network_type, security_group_ids, snapshot_retention_limit, data_storage_maximum_gb}')" \
		'{"network_type":"ipv4","security_group_ids":[],"snapshot_retention_limit":0,"data_storage_maximum_gb":null}'

	with_params '.parameters += {settings_mode: "advanced"}'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: settings_mode must be default or customize"
}

@test "deletes with the stored settings, ignoring the form defaults the platform fills into the delete" {
	export SERVICE_ACTION_TYPE=delete
	export MOCK_NP_VPC_PROVIDERS='{"results":[]}'
	existing_cache awscc_elasticache_serverless_cache public '{"major_engine_version":"9"}'
	with_params '.service.attributes += {engine_version: "9", connection_type: "public"} | .parameters += {engine_version: "8", connection_type: "vpc"}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_contains "$(captured TOFU_VARIABLES)" "-var=engine_version=9"
	assert_equal "$(tfvars '.connection_type')" '"public"'
}

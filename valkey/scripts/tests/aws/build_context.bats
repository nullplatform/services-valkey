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

@test "takes the region from the aws_region attribute without querying the account provider" {
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured REGION)" "us-west-2"
	assert_not_contains "$(cat "$MOCK_LOG")" "np provider"
}

@test "resolves the region from the account provider when the attribute is absent" {
	CONTEXT=$(echo "$CONTEXT" | jq 'del(.parameters.aws_region)')
	export MOCK_NP_PROVIDERS='{"results":[{"id":"prov-1","data_source":{"stored_keys":["account.region"]}}]}'
	export MOCK_NP_PROVIDER='{"attributes":{"account":{"region":"eu-central-1"}}}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured REGION)" "eu-central-1"
	assert_contains "$(cat "$MOCK_LOG")" "np provider list --nrn organization=1:account=2 --format json --limit 100"
	assert_contains "$(cat "$MOCK_LOG")" "np provider read --id prov-1 --format json"
}

@test "fails with a clear message when no region can be resolved" {
	CONTEXT=$(echo "$CONTEXT" | jq 'del(.parameters.aws_region)')
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: no account provider with account.region found for organization=1:account=2"
}

@test "prefers parameters over stored attributes for the network settings" {
	CONTEXT=$(service_context '{"vpc_id":"vpc-old","subnet_ids":"subnet-old","aws_region":"us-east-1"}' "$(full_params)")
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured VPC_ID)" "vpc-0123"
	assert_equal "$(captured SUBNET_IDS)" "subnet-a,subnet-b"
}

@test "falls back to values.yaml for the network settings when the context has none" {
	CONTEXT=$(echo "$CONTEXT" | jq 'del(.parameters.vpc_id, .parameters.subnet_ids)')
	printf 'aws_profile: ""\nvpc_id: "vpc-from-values"\nsubnet_ids: "subnet-v1,subnet-v2"\n' > "$VALUES"
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured VPC_ID)" "vpc-from-values"
	assert_equal "$(captured SUBNET_IDS)" "subnet-v1,subnet-v2"
}

@test "fails when neither the context nor values.yaml provide the vpc or the subnets" {
	CONTEXT=$(echo "$CONTEXT" | jq 'del(.parameters.vpc_id)')
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: vpc_id is required"

	CONTEXT=$(service_context '{}' "$(full_params | jq 'del(.subnet_ids)')")
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: subnet_ids is required"
}

@test "exports the tofu execution variables for the deployment module" {
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured OUTPUT_DIR)" "/tmp/np-service-0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718"
	assert_equal "$(captured TOFU_MODULE_DIR)" "$SERVICE_PATH/deployment"
	assert_equal "$(captured TFSTATE_BUCKET)" "np-service-0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718"
	assert_equal "$(captured TOFU_INIT_VARIABLES)" "-backend-config=bucket=np-service-0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718 -backend-config=key=terraform.tfstate -backend-config=region=us-west-2 -backend-config=use_lockfile=true"
	assert_equal "$(captured TOFU_VARIABLES)" "-var=service_id=0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718 -var=region=us-west-2 -var=cache_name=np-my-cache-0f3a6 -var=vpc_id=vpc-0123 -var=subnet_ids=subnet-a,subnet-b -var-file=/tmp/np-service-0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718/terraform.tfvars.json"
}

@test "writes the context tags to the tfvars file keeping only string values" {
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(jq -cS '.tags' /tmp/np-service-0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718/terraform.tfvars.json)" \
		'{"account":"acc","account_id":"2","application":"app","application_id":"4","namespace":"ns","namespace_id":"3","organization":"org","organization_id":"1"}'
}

@test "creates a versioned tfstate bucket with a location constraint outside us-east-1" {
	export MOCK_BUCKET_EXISTS=1
	run_script build_context
	[ "$status" -eq 0 ]
	assert_contains "$(cat "$MOCK_LOG")" "aws s3api create-bucket --bucket np-service-0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718 --region us-west-2 --create-bucket-configuration LocationConstraint=us-west-2"
	assert_contains "$(cat "$MOCK_LOG")" "aws s3api put-bucket-versioning --bucket np-service-0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718 --versioning-configuration Status=Enabled"
}

@test "creates the tfstate bucket without a location constraint in us-east-1" {
	export MOCK_BUCKET_EXISTS=1
	CONTEXT=$(echo "$CONTEXT" | jq '.parameters.aws_region = "us-east-1"')
	run_script build_context
	[ "$status" -eq 0 ]
	assert_contains "$(cat "$MOCK_LOG")" "aws s3api create-bucket --bucket np-service-0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718 --region us-east-1"
	assert_not_contains "$(cat "$MOCK_LOG")" "LocationConstraint"
}

@test "reuses an existing tfstate bucket" {
	run_script build_context
	[ "$status" -eq 0 ]
	assert_not_contains "$(cat "$MOCK_LOG")" "create-bucket"
	assert_contains "$captured_stdout" "Using existing tfstate bucket: np-service-0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718"
}

@test "exports the static credentials from the attributes when the assume-role step left none" {
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured AWS_ACCESS_KEY_ID)" "AKIASTATIC"
	assert_equal "$(captured AWS_SECRET_ACCESS_KEY)" "static-secret"
	assert_contains "$captured_stdout" "Using the access key from the service attributes"
}

@test "keeps the assumed-role credentials over the static attributes" {
	export AWS_ACCESS_KEY_ID="ASIAASSUMED"
	export AWS_SECRET_ACCESS_KEY="assumed-secret"
	export AWS_SESSION_TOKEN="token"
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured AWS_ACCESS_KEY_ID)" "ASIAASSUMED"
	assert_equal "$(captured AWS_SECRET_ACCESS_KEY)" "assumed-secret"
}

@test "leaves the credentials untouched when the attributes carry none" {
	CONTEXT=$(echo "$CONTEXT" | jq 'del(.parameters.access_key_id, .parameters.secret_access_key)')
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured AWS_ACCESS_KEY_ID)" ""
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

@test "strips whitespace from the subnet list so it survives word splitting" {
	CONTEXT=$(echo "$CONTEXT" | jq '.parameters.subnet_ids = " subnet-a, subnet-b "')
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured SUBNET_IDS)" "subnet-a,subnet-b"
}

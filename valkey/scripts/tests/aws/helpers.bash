setup_mocks() {
	TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
	SERVICE_PATH="$(cd "$TEST_DIR/../../.." && pwd)"
	SCRIPTS_DIR="$SERVICE_PATH/scripts/aws"
	MOCK_BIN="$BATS_TEST_TMPDIR/bin"
	MOCK_LOG="$BATS_TEST_TMPDIR/mock.log"
	VALUES="$BATS_TEST_TMPDIR/values.yaml"
	mkdir -p "$MOCK_BIN"
	: > "$MOCK_LOG"
	printf 'aws_profile: ""\n' > "$VALUES"
	export SERVICE_PATH MOCK_LOG VALUES
	export PATH="$MOCK_BIN:$PATH"
	export MOCK_BUCKET_EXISTS="${MOCK_BUCKET_EXISTS:-0}"
	export MOCK_TOFU_OUTPUTS="${MOCK_TOFU_OUTPUTS:-{\}}"
	export MOCK_TOFU_EXIT="${MOCK_TOFU_EXIT:-0}"
	if [ -z "${MOCK_NP_CLOUD_PROVIDERS+set}" ]; then
		MOCK_NP_CLOUD_PROVIDERS='{"results":[{"attributes":{"account":{"region":"us-west-2"}}}]}'
	fi
	if [ -z "${MOCK_NP_VPC_PROVIDERS+set}" ]; then
		MOCK_NP_VPC_PROVIDERS='{"results":[{"attributes":{"vpc":{"id":"vpc-0123","subnets":["subnet-a","subnet-b"]}}}]}'
	fi
	export MOCK_NP_CLOUD_PROVIDERS MOCK_NP_VPC_PROVIDERS
	export MOCK_CW_EXIT="${MOCK_CW_EXIT:-0}"
	if [ -z "${MOCK_CW_RESPONSE+set}" ]; then
		MOCK_CW_RESPONSE='{"Label":"x","Datapoints":[]}'
	fi
	export MOCK_CW_RESPONSE
	export MOCK_LIST_VERSIONS="${MOCK_LIST_VERSIONS:-null}"
	export MOCK_DESCRIBE_CACHE="${MOCK_DESCRIBE_CACHE:-}"
	export MOCK_STATE_JSON="${MOCK_STATE_JSON-missing}"
	export MOCK_CACHE_STATUSES="${MOCK_CACHE_STATUSES-gone}"
	if [ -z "${MOCK_CACHE_TAGS+set}" ]; then
		MOCK_CACHE_TAGS='{"TagList":[{"Key":"managed-by","Value":"nullplatform"},{"Key":"service-id","Value":"0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718"}]}'
	fi
	export MOCK_CACHE_TAGS
	unset AWS_PROFILE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN ACTION_SOURCE NOTIFICATION_ACTION OVERRIDES_PATH SERVICE_ACTION_TYPE
	export VALKEY_S3_STATE_BUCKET="${VALKEY_S3_STATE_BUCKET-np-valkey-state}"

	cat > "$MOCK_BIN/aws" <<'MOCK'
#!/bin/bash
echo "aws $*" >> "$MOCK_LOG"
case "$*" in
	*"s3api head-bucket"*)
		[ "$MOCK_BUCKET_EXISTS" = "0" ] && printf '{\n    "BucketArn": "arn:aws:s3:::b",\n    "BucketRegion": "us-east-1",\n    "AccessPointAlias": false\n}\n'
		exit "$MOCK_BUCKET_EXISTS" ;;
	"s3 cp "*)
		case "$MOCK_STATE_JSON" in
		missing) echo "fatal error: An error occurred (404) when calling the HeadObject operation: Not Found" >&2; exit 1 ;;
		denied) echo "fatal error: An error occurred (AccessDenied) when calling the HeadObject operation: Forbidden" >&2; exit 1 ;;
		*)
			dest=""
			prev=""
			for arg in "$@"; do
				skip=0
				case "$prev" in --*) skip=1 ;; esac
				case "$arg" in s3 | cp | s3://* | --*) skip=1 ;; esac
				if [ "$skip" = "0" ] && [ -z "$dest" ]; then
					dest="$arg"
				fi
				prev="$arg"
			done
			if [ -z "$dest" ]; then
				echo "mock: could not parse the s3 cp destination from: $*" >&2
				exit 1
			fi
			printf '%s' "$MOCK_STATE_JSON" > "$dest" ;;
		esac ;;
	"cloudwatch get-metric-statistics"*)
		echo "cloudwatch credentials: ${AWS_ACCESS_KEY_ID:-agent}" >> "$MOCK_LOG"
		if [ "$MOCK_CW_EXIT" != "0" ]; then
			echo "An error occurred (AccessDenied) when calling the GetMetricStatistics operation" >&2
			exit "$MOCK_CW_EXIT"
		fi
		echo "$MOCK_CW_RESPONSE" ;;
	*"s3api list-object-versions"*) echo "$MOCK_LIST_VERSIONS" ;;
	*"s3api delete-objects"*)
		for arg in "$@"; do
			case "$arg" in file://*) [ -f "${arg#file://}" ] || { echo "missing delete file" >&2; exit 1; } ;; esac
		done ;;
	*"elasticache describe-serverless-caches"*)
		if [ -n "$MOCK_DESCRIBE_CACHE" ]; then
			echo "$MOCK_DESCRIBE_CACHE"
			exit 0
		fi
		calls=$(grep -c "elasticache describe-serverless-caches" "$MOCK_LOG")
		read -ra statuses <<<"$MOCK_CACHE_STATUSES"
		index=$((calls - 1))
		[ "$index" -lt "${#statuses[@]}" ] || index=$((${#statuses[@]} - 1))
		case "${statuses[$index]}" in
		gone)
			echo "An error occurred (ServerlessCacheNotFoundFault) when calling the DescribeServerlessCaches operation: Serverless cache not found" >&2
			exit 254 ;;
		denied)
			echo "An error occurred (AccessDenied) when calling the DescribeServerlessCaches operation: not authorized" >&2
			exit 254 ;;
		*)
			jq -n --arg status "${statuses[$index]}" \
				'{ServerlessCaches: [{ServerlessCacheName: "np-my-cache-0f3a6", ARN: "arn:aws:elasticache:us-west-2:222222222222:serverlesscache:np-my-cache-0f3a6", Status: $status}]}' ;;
		esac ;;
	*"elasticache list-tags-for-resource"*) echo "$MOCK_CACHE_TAGS" ;;
	*"elasticache delete-serverless-cache"*)
		last=$(grep -c "elasticache describe-serverless-caches" "$MOCK_LOG")
		read -ra statuses <<<"$MOCK_CACHE_STATUSES"
		current="${statuses[$((last - 1))]:-}"
		case "$current" in
		creating | modifying | deleting)
			echo "An error occurred (InvalidServerlessCacheStateFault) when calling the DeleteServerlessCache operation: cache is ${current}" >&2
			exit 254 ;;
		esac ;;
esac
exit 0
MOCK

	cat > "$MOCK_BIN/np" <<'MOCK'
#!/bin/bash
echo "np $*" >> "$MOCK_LOG"
if [ "$1 $2" != "provider list" ]; then
	echo "{}"
	exit 0
fi
category=""
prev=""
for arg in "$@"; do
	case "$prev" in
	--categories) category="$arg" ;;
	--limit) echo '{"error":"cannot use flag limit when using categories flag"}'; exit 1 ;;
	esac
	prev="$arg"
done
case "$category" in
	cloud-providers) echo "$MOCK_NP_CLOUD_PROVIDERS" ;;
	vpc) echo "$MOCK_NP_VPC_PROVIDERS" ;;
	*) echo '{"results":[]}' ;;
esac
exit 0
MOCK

	cat > "$MOCK_BIN/tofu" <<'MOCK'
#!/bin/bash
echo "tofu $*" >> "$MOCK_LOG"
case "$1" in
	# do_tofu checks the version first: without an answer it would install a real tofu and run it.
	version) echo "OpenTofu v1.12.6" ;;
	output) echo "$MOCK_TOFU_OUTPUTS" ;;
	init|apply|destroy) exit "$MOCK_TOFU_EXIT" ;;
esac
exit 0
MOCK

	chmod +x "$MOCK_BIN"/*
}

service_context() {
	jq -n \
		--arg id "0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718" \
		--arg slug "my-cache" \
		--argjson attrs "${1:-{\}}" \
		--argjson params "${2:-{\}}" \
		'{
			service: {
				id: $id,
				slug: $slug,
				name: "My Cache",
				nrn: "organization=1:account=2:namespace=3:application=4",
				attributes: $attrs
			},
			parameters: $params,
			tags: {
				account_id: "2",
				account: "acc",
				organization_id: "1",
				organization: "org",
				application_id: "4",
				application: "app",
				namespace_id: "3",
				namespace: "ns",
				scope_id: null
			}
		}'
}

link_context() {
	service_context "$1" "$2" | jq \
		--arg id "7d9e2f10-1234-4abc-9def-0123456789ab" \
		--arg slug "Orders API" \
		'.link = {id: $id, slug: $slug, attributes: {}}'
}

full_params() {
	jq -n '{
		access_key_id: "AKIASTATIC",
		secret_access_key: "static-secret"
	}'
}

run_script() {
	local script="$1"
	run bash -c "set -a; source '$SCRIPTS_DIR/$script' >'$BATS_TEST_TMPDIR/stdout' 2>'$BATS_TEST_TMPDIR/stderr'; rc=\$?; env > '$BATS_TEST_TMPDIR/env'; exit \$rc"
	captured_stdout=$(cat "$BATS_TEST_TMPDIR/stdout")
	captured_stderr=$(cat "$BATS_TEST_TMPDIR/stderr")
}

captured() {
	grep "^$1=" "$BATS_TEST_TMPDIR/env" | head -1 | cut -d= -f2-
}

assert_equal() {
	if [ "$1" != "$2" ]; then
		echo "expected: $2"
		echo "actual:   $1"
		return 1
	fi
}

assert_contains() {
	if [[ "$1" != *"$2"* ]]; then
		echo "expected to contain: $2"
		echo "actual: $1"
		return 1
	fi
}

assert_not_contains() {
	if [[ "$1" == *"$2"* ]]; then
		echo "expected not to contain: $2"
		echo "actual: $1"
		return 1
	fi
}

metric_context() {
	jq -n --argjson arguments "$1" '{arguments: $arguments}'
}

cache_service() {
	jq -n '{
		id: "0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718",
		attributes: {
			cache_name: "np-my-cache-0f3a6",
			valkey_arn: "arn:aws:elasticache:us-west-2:222222222222:serverlesscache:np-my-cache-0f3a6"
		}
	}'
}

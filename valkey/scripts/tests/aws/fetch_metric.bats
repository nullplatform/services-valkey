#!/usr/bin/env bats

load helpers

setup() {
	setup_mocks
	export CONTEXT
	CONTEXT=$(metric_context "$(jq -n --argjson service "$(cache_service)" '{
		metric: "CacheHitRate",
		start_time: "2026-10-02T10:00:00.000Z",
		end_time: "2026-10-02T11:00:00.000Z",
		period: 300,
		service_id: "0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718",
		service: $service
	}')")
}

@test "queries cloudwatch for the cache with the window, period and statistic of the metric" {
	run_script fetch_metric
	[ "$status" -eq 0 ]
	assert_contains "$(cat "$MOCK_LOG")" "aws cloudwatch get-metric-statistics --region us-west-2 --namespace AWS/ElastiCache --metric-name CacheHitRate --dimensions Name=clusterId,Value=np-my-cache-0f3a6 --start-time 2026-10-02T10:00:00.000Z --end-time 2026-10-02T11:00:00.000Z --period 300 --statistics Average --output json"
}

@test "returns the datapoints sorted by timestamp in the telemetry format" {
	export MOCK_CW_RESPONSE='{"Label":"CacheHitRate","Datapoints":[{"Timestamp":"2026-10-02T10:05:00+00:00","Average":91.5,"Unit":"Percent"},{"Timestamp":"2026-10-02T10:00:00+00:00","Average":88,"Unit":"Percent"}]}'
	run_script fetch_metric
	[ "$status" -eq 0 ]
	assert_equal "$captured_stdout" '{"metric":"CacheHitRate","type":"gauge","period_in_seconds":300,"unit":"percent","results":[{"selector":{"cache_name":"np-my-cache-0f3a6"},"data":[{"timestamp":"2026-10-02T10:00:00+00:00","value":88},{"timestamp":"2026-10-02T10:05:00+00:00","value":91.5}]}]}'
}

@test "prints only the result and logs nothing when the query succeeds" {
	export MOCK_CW_RESPONSE='{"Label":"CacheHitRate","Datapoints":[{"Timestamp":"2026-10-02T10:00:00+00:00","Average":88}]}'
	run_script fetch_metric
	[ "$status" -eq 0 ]
	assert_equal "$(echo "$captured_stdout" | wc -l | tr -d ' ')" "1"
	echo "$captured_stdout" | jq -e '.results[0].data[0].value == 88'
	assert_equal "$captured_stderr" ""
}

@test "uses the statistic and unit that belong to each metric" {
	for pair in "ElastiCacheProcessingUnits:Sum:count" "BytesUsedForCache:Maximum:bytes" "CurrConnections:Maximum:count" "SuccessfulReadRequestLatency:Average:microseconds" "ThrottledCmds:Sum:count"; do
		IFS=: read -r metric statistic unit <<<"$pair"
		CONTEXT=$(echo "$CONTEXT" | jq --arg metric "$metric" '.arguments.metric = $metric')
		: >"$MOCK_LOG"
		run_script fetch_metric
		[ "$status" -eq 0 ]
		assert_contains "$(cat "$MOCK_LOG")" "--metric-name ${metric} "
		assert_contains "$(cat "$MOCK_LOG")" "--statistics ${statistic} "
		assert_equal "$(echo "$captured_stdout" | jq -r '.unit')" "$unit"
	done
}

@test "rounds the period up to a multiple of sixty seconds" {
	CONTEXT=$(echo "$CONTEXT" | jq '.arguments.period = 90')
	run_script fetch_metric
	[ "$status" -eq 0 ]
	assert_contains "$(cat "$MOCK_LOG")" "--period 120 "
	assert_equal "$(echo "$captured_stdout" | jq '.period_in_seconds')" "120"

	CONTEXT=$(echo "$CONTEXT" | jq '.arguments.period = 15')
	run_script fetch_metric
	assert_contains "$(cat "$MOCK_LOG")" "--period 60 "

	CONTEXT=$(echo "$CONTEXT" | jq 'del(.arguments.period)')
	run_script fetch_metric
	[ "$status" -eq 0 ]
	assert_equal "$(echo "$captured_stdout" | jq '.period_in_seconds')" "60"
}

@test "falls back to the last hour when the request has no window" {
	CONTEXT=$(echo "$CONTEXT" | jq 'del(.arguments.start_time, .arguments.end_time)')
	run_script fetch_metric
	[ "$status" -eq 0 ]
	[[ "$(cat "$MOCK_LOG")" =~ --start-time\ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z\ --end-time\ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z ]]
}

@test "reads the cache from the service when the request carries no attributes" {
	CONTEXT=$(echo "$CONTEXT" | jq 'del(.arguments.service.attributes, .arguments.service_id)')
	export MOCK_NP_SERVICE
	MOCK_NP_SERVICE=$(cache_service)
	run_script fetch_metric
	[ "$status" -eq 0 ]
	assert_contains "$(cat "$MOCK_LOG")" "np service read --id 0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718 --format json"
	assert_contains "$(cat "$MOCK_LOG")" "Value=np-my-cache-0f3a6"
}

@test "returns an empty series without calling cloudwatch while the cache does not exist yet" {
	CONTEXT=$(echo "$CONTEXT" | jq 'del(.arguments.service.attributes)')
	run_script fetch_metric
	[ "$status" -eq 0 ]
	assert_equal "$captured_stdout" '{"metric":"CacheHitRate","type":"gauge","period_in_seconds":300,"unit":"percent","results":[]}'
	assert_equal "$captured_stderr" ""
	assert_not_contains "$(cat "$MOCK_LOG")" "cloudwatch"
}

@test "fails on an unknown metric" {
	CONTEXT=$(echo "$CONTEXT" | jq '.arguments.metric = "CPUUtilization"')
	run_script fetch_metric
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "unknown metric 'CPUUtilization'"
	assert_not_contains "$(cat "$MOCK_LOG")" "cloudwatch"
}

@test "fails on a malformed time window" {
	CONTEXT=$(echo "$CONTEXT" | jq '.arguments.start_time = "yesterday --region evil"')
	run_script fetch_metric
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "is not a UTC ISO 8601 timestamp"
	assert_not_contains "$(cat "$MOCK_LOG")" "cloudwatch"
}

@test "fails when the request does not identify the service" {
	CONTEXT=$(echo "$CONTEXT" | jq 'del(.arguments.service, .arguments.service_id)')
	run_script fetch_metric
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "carries no service id"
}

@test "fails when the cache arn does not carry a valid region" {
	CONTEXT=$(echo "$CONTEXT" | jq '.arguments.service.attributes.valkey_arn = "arn:aws:elasticache:bad region:1:serverlesscache:x"')
	run_script fetch_metric
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "is not an AWS region"
}

@test "fails instead of returning an empty series when cloudwatch rejects the query" {
	export MOCK_CW_EXIT=254
	run_script fetch_metric
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "AccessDenied"
	assert_contains "$captured_stderr" "CloudWatch rejected the CacheHitRate query for np-my-cache-0f3a6 in us-west-2"
}

@test "reports the ecpus per second an idle cache still has available" {
	CONTEXT=$(echo "$CONTEXT" | jq '.arguments.metric = "AvailableECPUPerSecond" | .arguments.start_time = "2026-10-02T10:00:00.000Z" | .arguments.end_time = "2026-10-02T10:15:00.000Z"')
	run_script fetch_metric
	[ "$status" -eq 0 ]
	assert_contains "$(cat "$MOCK_LOG")" "--metric-name ElastiCacheProcessingUnits "
	assert_contains "$(cat "$MOCK_LOG")" "--statistics Sum "
	assert_contains "$(cat "$MOCK_LOG")" "aws elasticache describe-serverless-caches --region us-west-2 --serverless-cache-name np-my-cache-0f3a6"
	assert_equal "$(echo "$captured_stdout" | jq -c '.results[0].data')" '[{"timestamp":"2026-10-02T10:00:00Z","value":30000},{"timestamp":"2026-10-02T10:05:00Z","value":30000},{"timestamp":"2026-10-02T10:10:00Z","value":30000}]'
	assert_equal "$(echo "$captured_stdout" | jq -r '.unit')" "count"
	assert_equal "$captured_stderr" ""
}

@test "subtracts the ecpus used per second from the configured maximum" {
	export MOCK_EC_CACHES='{"ServerlessCaches":[{"CacheUsageLimits":{"ECPUPerSecond":{"Maximum":5000}}}]}'
	export MOCK_CW_RESPONSE='{"Datapoints":[{"Timestamp":"2026-10-02T10:05:00+00:00","Sum":300000}]}'
	CONTEXT=$(echo "$CONTEXT" | jq '.arguments.metric = "AvailableECPUPerSecond" | .arguments.start_time = "2026-10-02T10:00:00.000Z" | .arguments.end_time = "2026-10-02T10:10:00.000Z"')
	run_script fetch_metric
	[ "$status" -eq 0 ]
	assert_equal "$(echo "$captured_stdout" | jq -c '[.results[0].data[].value]')" '[5000,4000]'
}

@test "never reports negative available ecpus" {
	export MOCK_EC_CACHES='{"ServerlessCaches":[{"CacheUsageLimits":{"ECPUPerSecond":{"Maximum":100}}}]}'
	export MOCK_CW_RESPONSE='{"Datapoints":[{"Timestamp":"2026-10-02T10:00:00+00:00","Sum":300000}]}'
	CONTEXT=$(echo "$CONTEXT" | jq '.arguments.metric = "AvailableECPUPerSecond" | .arguments.start_time = "2026-10-02T10:00:00.000Z" | .arguments.end_time = "2026-10-02T10:05:00.000Z"')
	run_script fetch_metric
	[ "$status" -eq 0 ]
	assert_equal "$(echo "$captured_stdout" | jq -c '[.results[0].data[].value]')" '[0]'
}

@test "bills at least the 100 MB minimum for valkey on an empty cache" {
	CONTEXT=$(echo "$CONTEXT" | jq '.arguments.metric = "BilledDataStorage" | .arguments.start_time = "2026-10-02T10:00:00.000Z" | .arguments.end_time = "2026-10-02T10:10:00.000Z"')
	run_script fetch_metric
	[ "$status" -eq 0 ]
	assert_contains "$(cat "$MOCK_LOG")" "--metric-name BytesUsedForCache "
	assert_contains "$(cat "$MOCK_LOG")" "--statistics Maximum "
	assert_equal "$(echo "$captured_stdout" | jq -c '[.results[0].data[].value]')" '[104857600,104857600]'
	assert_equal "$(echo "$captured_stdout" | jq -r '.unit')" "bytes"
}

@test "bills the configured minimum or the usage when either is larger" {
	export MOCK_EC_CACHES='{"ServerlessCaches":[{"CacheUsageLimits":{"DataStorage":{"Minimum":2,"Unit":"GB"}}}]}'
	export MOCK_CW_RESPONSE='{"Datapoints":[{"Timestamp":"2026-10-02T10:05:00+00:00","Maximum":5000000000}]}'
	CONTEXT=$(echo "$CONTEXT" | jq '.arguments.metric = "BilledDataStorage" | .arguments.start_time = "2026-10-02T10:00:00.000Z" | .arguments.end_time = "2026-10-02T10:10:00.000Z"')
	run_script fetch_metric
	[ "$status" -eq 0 ]
	assert_equal "$(echo "$captured_stdout" | jq -c '[.results[0].data[].value]')" '[2147483648,5000000000]'
}

@test "does not read the cache limits for plain cloudwatch metrics" {
	run_script fetch_metric
	[ "$status" -eq 0 ]
	assert_not_contains "$(cat "$MOCK_LOG")" "describe-serverless-caches"
}

@test "fails when the cache limits cannot be read" {
	export MOCK_EC_EXIT=254
	CONTEXT=$(echo "$CONTEXT" | jq '.arguments.metric = "BilledDataStorage"')
	run_script fetch_metric
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "could not read the usage limits of np-my-cache-0f3a6 in us-west-2"
}

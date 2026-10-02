#!/usr/bin/env bats

load helpers

setup() {
	setup_mocks
}

@test "lists the six cache metrics in the telemetry format" {
	run_script list_metrics
	[ "$status" -eq 0 ]
	assert_equal "$(echo "$captured_stdout" | jq -c '[.results[].name]')" '["ElastiCacheProcessingUnits","BytesUsedForCache","CacheHitRate","CurrConnections","SuccessfulReadRequestLatency","ThrottledCmds"]'
	assert_equal "$(echo "$captured_stdout" | jq '[.results[] | select(.unit and .title and (.available_filters | type == "array") and (.available_group_by | type == "array"))] | length')" "6"
}

@test "lists only metrics that fetch_metric can query" {
	run_script list_metrics
	for metric in $(echo "$captured_stdout" | jq -r '.results[].name'); do
		CONTEXT=$(metric_context "$(jq -n --arg metric "$metric" --argjson service "$(cache_service)" '{metric: $metric, service: $service}')")
		export CONTEXT
		run_script fetch_metric
		[ "$status" -eq 0 ]
	done
}

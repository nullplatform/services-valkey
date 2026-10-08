#!/usr/bin/env bats

load helpers

setup() {
	setup_mocks
	SPEC="$SERVICE_PATH/specs/service-spec.json.tpl"
	LINK_SPEC="$SERVICE_PATH/specs/links/connect.json.tpl"
}

prop() {
	jq -c ".attributes.schema.properties.$1" "$SPEC"
}

# The inputs the developer fills in: everything but the outputs the service writes back.
inputs() {
	jq -r '.attributes.schema.properties | to_entries[] | select(.value.readOnly != true and (.value.visibleOn // ["x"]) != []) | .key' "$SPEC" | sort
}

controls() {
	jq -r '[.attributes.schema.uiSchema | .. | objects | select(.type == "Control") | .scope | sub("#/properties/"; "")] | .[]' "$SPEC" | sort
}

# The rule that shows a control, wherever it sits in the layout: its own or an enclosing one's.
rule_of() {
	jq -c --arg scope "#/properties/$1" '
		def walk_rules($inherited):
			if type == "object" then
				(if .rule then .rule else $inherited end) as $rule
				| if .scope == $scope then $rule else ((.elements // [])[] | walk_rules($rule)) end
			else empty end;
		[.attributes.schema.uiSchema | walk_rules(null)][0]' "$SPEC"
}

@test "both specs are valid JSON with the schema under attributes.schema" {
	jq -e '.attributes.schema.type == "object"' "$SPEC"
	jq -e '.attributes.schema.type == "object"' "$LINK_SPEC"
	jq -e '.specification_schema == null' "$SPEC"
}

@test "the service offers its link and the link slug matches" {
	assert_equal "$(jq -r '.available_links[0]' "$SPEC")" "$(jq -r '.slug' "$LINK_SPEC")"
}

@test "the settings AWS fixes at creation can only be set on create" {
	for key in connection_type network_type vpc_id subnet_ids encryption_key kms_key_arn; do
		assert_equal "$(prop "$key" | jq -c '.editableOn')" '["create"]' || { echo "$key"; return 1; }
	done
}

@test "every other input can be changed after creation" {
	for key in $(inputs); do
		case "$key" in connection_type | network_type | vpc_id | subnet_ids | encryption_key | kms_key_arn) continue ;; esac
		assert_equal "$(prop "$key" | jq -c '.editableOn')" '["create","update"]' || { echo "$key"; return 1; }
	done
}

@test "the defaults match the ones build_context applies" {
	assert_equal "$(jq -c '.attributes.schema.properties | [.engine_version, .connection_type, .settings_mode, .network_type, .security_settings, .encryption_key, .automatic_backups, .backup_retention_days, .usage_limits] | map(.default)' "$SPEC")" \
		'["9","vpc","default","ipv4","default","dedicated","disabled",1,"not_set"]'
	grep -q 'choice engine_version 9 ' "$SERVICE_PATH/scripts/aws/build_context"
	grep -q 'choice connection_type vpc ' "$SERVICE_PATH/scripts/aws/build_context"
	grep -q 'choice settings_mode default ' "$SERVICE_PATH/scripts/aws/build_context"
	grep -q 'choice security_settings default ' "$SERVICE_PATH/scripts/aws/build_context"
	grep -q 'choice encryption_key dedicated ' "$SERVICE_PATH/scripts/aws/build_context"
	grep -q 'choice automatic_backups disabled ' "$SERVICE_PATH/scripts/aws/build_context"
	grep -q 'choice usage_limits not_set ' "$SERVICE_PATH/scripts/aws/build_context"
	grep -q 'attr_or backup_retention_days 1)' "$SERVICE_PATH/scripts/aws/build_context"
}

@test "the enum values are the ones the scripts understand" {
	assert_equal "$(prop engine_version | jq -c '.enum')" '["7","8","9"]'
	for pair in connection_type:vpc,public settings_mode:default,customize network_type:ipv4,dual_stack,ipv6 \
		security_settings:default,customize encryption_key:dedicated,existing automatic_backups:disabled,enabled usage_limits:not_set,set; do
		assert_equal "$(prop "${pair%%:*}" | jq -r '[.oneOf[].const] | join(",")')" "${pair#*:}" || { echo "$pair"; return 1; }
	done
}

@test "the numeric limits match the AWS ranges build_context enforces, with 0 as no limit" {
	assert_equal "$(prop backup_retention_days | jq -c '[.minimum, .maximum]')" '[1,35]'
	for key in data_storage_minimum_gb data_storage_maximum_gb; do
		assert_equal "$(prop "$key" | jq -c '[.minimum, .maximum]')" '[0,5000]'
	done
	for key in ecpu_minimum ecpu_maximum; do
		assert_equal "$(prop "$key" | jq -c '[.minimum, .maximum]')" '[0,15000000]'
	done
	grep -q 'data_storage_minimum_gb:1:5000 data_storage_maximum_gb:1:5000 ecpu_minimum:1000:15000000 ecpu_maximum:1000:15000000' "$SERVICE_PATH/scripts/aws/build_context"
}

@test "every control in the form points at a property and every input property has a control" {
	assert_equal "$(controls | uniq)" "$(inputs)"
}

@test "the connection type is offered only on Valkey 9" {
	assert_equal "$(rule_of connection_type)" '{"effect":"SHOW","condition":{"scope":"#/properties/engine_version","schema":{"const":"9"}}}'
}

@test "the customized settings show only when they are chosen" {
	for key in network_type security_settings automatic_backups usage_limits; do
		assert_equal "$(rule_of "$key" | jq -c '.condition')" '{"scope":"#/properties/settings_mode","schema":{"const":"customize"}}' || { echo "$key"; return 1; }
	done
	assert_equal "$(rule_of kms_key_arn | jq -c '.condition.schema')" '{"const":"existing"}'
	for key in backup_retention_days backup_window_start; do
		assert_equal "$(rule_of "$key" | jq -c '.condition')" '{"scope":"#/properties/automatic_backups","schema":{"const":"enabled"}}'
	done
	for key in data_storage_minimum_gb data_storage_maximum_gb ecpu_minimum ecpu_maximum; do
		assert_equal "$(rule_of "$key" | jq -c '.condition')" '{"scope":"#/properties/usage_limits","schema":{"const":"set"}}'
	done
}

@test "the VPC, subnets and security groups are hidden on a public cache" {
	for key in vpc_id subnet_ids security_group_ids; do
		assert_equal "$(rule_of "$key" | jq -c '.condition')" '{"scope":"#/properties/connection_type","schema":{"not":{"const":"public"}}}' || { echo "$key"; return 1; }
	done
}

@test "the service exports the endpoint and the port and nothing secret" {
	assert_equal "$(jq -c '[.attributes.schema.properties | to_entries[] | select(.value.export == true) | .key]' "$SPEC")" '["endpoint","port"]'
	assert_equal "$(jq -c '[.attributes.schema.properties | to_entries[] | select((.value.export | type) == "object" and .value.export.secret == true) | .key]' "$SPEC")" '[]'
}

@test "the link exports its credentials as secrets and the rest as plain values" {
	assert_equal "$(jq -c '[.attributes.schema.properties | to_entries[] | select((.value.export | type) == "object" and .value.export.secret == true) | .key] | sort' "$LINK_SPEC")" '["connection_url","secret_access_key","user_password"]'
	assert_equal "$(jq -c '[.attributes.schema.properties | to_entries[] | select(.value.export == true) | .key] | sort' "$LINK_SPEC")" '["access_key_id","aws_region","cache_name","user_name"]'
	assert_equal "$(jq -c '.attributes.schema.required' "$LINK_SPEC")" '["user_name","connection_url"]'
}

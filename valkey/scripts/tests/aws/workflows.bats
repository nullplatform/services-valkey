#!/usr/bin/env bats

load helpers

setup() {
	setup_mocks
	WORKFLOWS="$SERVICE_PATH/workflows/aws"
}

referenced_files() {
	grep -hoE 'file: \$SERVICE_PATH/[^ ]+' "$WORKFLOWS"/*.yaml | sed 's|file: \$SERVICE_PATH/||' | sort -u
}

step_files() {
	grep -oE 'file: \$SERVICE_PATH/[^ ]+' "$WORKFLOWS/$1.yaml" | sed 's|.*/||' | tr '\n' ' ' | sed 's/ $//'
}

@test "every script a workflow references exists and is executable" {
	[ -n "$(referenced_files)" ]
	for rel in $(referenced_files); do
		[ -x "$SERVICE_PATH/$rel" ] || { echo "missing or not executable: $rel"; return 1; }
	done
}

@test "every workflow starts with steps and each step has a name and a type" {
	for f in "$WORKFLOWS"/*.yaml; do
		head -1 "$f" | grep -q '^steps:$' || { echo "$f does not start with steps:"; return 1; }
		[ "$(grep -c '^  - name:' "$f")" -eq "$(grep -c '^    type: script$' "$f")" ] || { echo "$f: name/type mismatch"; return 1; }
	done
}

@test "every workflow that touches AWS assumes the role first" {
	for f in create update delete link link-update unlink; do
		[ "$(grep -m1 'file:' "$WORKFLOWS/$f.yaml")" = '    file: $SERVICE_PATH/utils/assume_role_step' ] || { echo "$f does not start with assume_role_step"; return 1; }
	done
}

@test "create applies and writes the service outputs" {
	assert_equal "$(step_files create)" "assume_role_step build_context do_tofu write_service_outputs"
	grep -q 'TOFU_ACTION: apply' "$WORKFLOWS/create.yaml"
}

@test "update applies, clears the usage limits the developer removed and writes the service outputs" {
	assert_equal "$(step_files update)" "assume_role_step build_context do_tofu clear_usage_limits write_service_outputs"
	grep -q 'TOFU_ACTION: apply' "$WORKFLOWS/update.yaml"
}

@test "update passes the cache name to the step that clears usage limits" {
	grep -A40 'file: $SERVICE_PATH/scripts/aws/build_context' "$WORKFLOWS/update.yaml" | grep -q 'name: CACHE_NAME'
}

@test "delete removes a cache left outside the state, destroys and then cleans the state" {
	assert_equal "$(step_files delete)" "assume_role_step build_context delete_untracked_cache do_tofu delete_tfstate_objects"
	grep -q 'TOFU_ACTION: destroy' "$WORKFLOWS/delete.yaml"
}

@test "link and link-update apply and write the link outputs, unlink destroys" {
	for action in link link-update; do
		assert_equal "$(step_files $action)" "assume_role_step build_context build_permissions_context do_tofu write_link_outputs"
		grep -q 'TOFU_ACTION: apply' "$WORKFLOWS/$action.yaml"
	done
	grep -q 'TOFU_ACTION: destroy' "$WORKFLOWS/unlink.yaml"
	! grep -q 'write_link_outputs' "$WORKFLOWS/unlink.yaml"
}

@test "the template placeholder script is gone" {
	[ ! -e "$SERVICE_PATH/scripts/example" ]
}

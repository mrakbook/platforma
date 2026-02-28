#!/usr/bin/env bash

PLATFORMA_DFS_VISITING=()
PLATFORMA_DFS_VISITED=()
PLATFORMA_DFS_ORDER=()

platforma::discover_targets_uncached() {
	platforma::require_command yq

	local cfg
	shopt -s nullglob
	for cfg in "${PLATFORMA_ROOT}"/services/*/config.yaml; do
		local target target_path service_key service_name expected_name version runtime port deps_csv caps_csv run_cmd lint_cmd test_cmd health_path
		target="$(basename "$(dirname "${cfg}")")"
		target_path="${cfg#"${PLATFORMA_ROOT}/"}"
		target_path="${target_path%/config.yaml}"

		service_key="$(yq e -r '.service_key // ""' "${cfg}")"
		service_name="$(yq e -r '.service // ""' "${cfg}")"
		version="$(yq e -r '.version // "0.1.0"' "${cfg}")"
		runtime="$(yq e -r '.runtime // "python"' "${cfg}")"
		port="$(yq e -r '.local.config_env.APP_PORT // ""' "${cfg}")"
		deps_csv="$(yq e -r '.platforma.dependencies // [] | join(",")' "${cfg}")"
		caps_csv="$(yq e -r '.platforma.capabilities // ["run","lint","test","build-image"] | join(",")' "${cfg}")"
		run_cmd="$(yq e -r '.platforma.commands.run // ""' "${cfg}")"
		lint_cmd="$(yq e -r '.platforma.commands.lint // ""' "${cfg}")"
		test_cmd="$(yq e -r '.platforma.commands.test // ""' "${cfg}")"
		health_path="$(yq e -r '.platforma.health.path // "/health"' "${cfg}")"

		[[ -n "${service_key}" ]] || platforma::die "Missing service_key in ${cfg}"
		expected_name="platforma-svc-${service_key}"
		[[ "${service_name}" == "${expected_name}" ]] || platforma::die "Invalid service name in ${cfg}: expected ${expected_name}, got ${service_name}"
		[[ "${target}" == "${service_key}" ]] || platforma::die "Invalid target key in ${cfg}: directory '${target}' must match service_key '${service_key}'"

		printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
			"${target}" "${service_key}" "${service_name}" "${version}" "${runtime}" "${target_path}" "${port}" \
			"${deps_csv}" "${caps_csv}" "${run_cmd}" "${lint_cmd}" "${test_cmd}" "${health_path}"
	done | sort
	shopt -u nullglob
}

platforma::validate_discovery_catalog() {
	local catalog="$1"
	[[ -n "${catalog}" ]] || platforma::die "No target configs found under services/*/config.yaml"

	local -a targets=()
	local -a service_keys=()
	local -a services=()

	local line
	while IFS= read -r line; do
		[[ -n "${line}" ]] || continue

		local target service_key service_name version runtime path
		target="$(platforma::record_field "${line}" 0)"
		service_key="$(platforma::record_field "${line}" 1)"
		service_name="$(platforma::record_field "${line}" 2)"
		version="$(platforma::record_field "${line}" 3)"
		runtime="$(platforma::record_field "${line}" 4)"
		path="$(platforma::record_field "${line}" 5)"

		[[ -n "${target}" ]] || platforma::die "Catalog invariant failed: empty target name"
		[[ -n "${service_key}" ]] || platforma::die "Catalog invariant failed: empty service_key for target '${target}'"
		[[ -n "${service_name}" ]] || platforma::die "Catalog invariant failed: empty service name for target '${target}'"
		[[ -n "${runtime}" ]] || platforma::die "Catalog invariant failed: empty runtime for target '${target}'"
		[[ -n "${version}" ]] || platforma::die "Catalog invariant failed: empty version for target '${target}'"
		platforma::validate_semver "${version}" || platforma::die "Catalog invariant failed: invalid semver '${version}' for target '${target}'"

		local expected_service expected_path
		expected_service="platforma-svc-${service_key}"
		expected_path="services/${target}"
		[[ "${service_name}" == "${expected_service}" ]] || platforma::die "Catalog invariant failed: target '${target}' must use service '${expected_service}', got '${service_name}'"
		[[ "${target}" == "${service_key}" ]] || platforma::die "Catalog invariant failed: target '${target}' must match service_key '${service_key}'"
		[[ "${path}" == "${expected_path}" ]] || platforma::die "Catalog invariant failed: target '${target}' must use path '${expected_path}', got '${path}'"

		if platforma::array_contains "${target}" "${targets[@]:-}"; then
			platforma::die "Catalog invariant failed: duplicate target '${target}'"
		fi
		if platforma::array_contains "${service_key}" "${service_keys[@]:-}"; then
			platforma::die "Catalog invariant failed: duplicate service_key '${service_key}'"
		fi
		if platforma::array_contains "${service_name}" "${services[@]:-}"; then
			platforma::die "Catalog invariant failed: duplicate service name '${service_name}'"
		fi

		targets+=("${target}")
		service_keys+=("${service_key}")
		services+=("${service_name}")
	done < <(printf '%s\n' "${catalog}")

	while IFS= read -r line; do
		[[ -n "${line}" ]] || continue

		local target deps_csv caps_csv
		target="$(platforma::record_field "${line}" 0)"
		deps_csv="$(platforma::record_field "${line}" 7)"
		caps_csv="$(platforma::record_field "${line}" 8)"

		local dep
		local -a deps=()
		IFS=',' read -r -a deps <<<"${deps_csv}"
		for dep in "${deps[@]-}"; do
			[[ -n "${dep}" ]] || continue
			[[ "${dep}" != "${target}" ]] || platforma::die "Catalog invariant failed: target '${target}' cannot depend on itself"
			platforma::array_contains "${dep}" "${targets[@]:-}" || platforma::die "Catalog invariant failed: target '${target}' depends on unknown target '${dep}'"
		done

		local cap
		local -a caps=()
		local -a seen_caps=()
		IFS=',' read -r -a caps <<<"${caps_csv}"
		for cap in "${caps[@]-}"; do
			[[ -n "${cap}" ]] || continue
			case "${cap}" in
				run | lint | test | build-image) ;;
				*) platforma::die "Catalog invariant failed: target '${target}' has unsupported capability '${cap}'" ;;
			esac
			if platforma::array_contains "${cap}" "${seen_caps[@]:-}"; then
				platforma::die "Catalog invariant failed: target '${target}' has duplicate capability '${cap}'"
			fi
			seen_caps+=("${cap}")
		done
	done < <(printf '%s\n' "${catalog}")
}

platforma::discover_targets() {
	if [[ "${PLATFORMA_DISCOVERY_CACHE_VALID}" != "1" ]]; then
		PLATFORMA_DISCOVERY_CACHE="$(platforma::discover_targets_uncached)"
		platforma::validate_discovery_catalog "${PLATFORMA_DISCOVERY_CACHE}"
		PLATFORMA_DISCOVERY_CACHE_VALID=1
	fi
	if [[ -n "${PLATFORMA_DISCOVERY_CACHE}" ]]; then
		printf '%s\n' "${PLATFORMA_DISCOVERY_CACHE}"
	fi
}

platforma::record_for_target() {
	local target="$1"
	local line
	while IFS= read -r line; do
		[[ -n "${line}" ]] || continue
		local name="${line%%|*}"
		if [[ "${name}" == "${target}" ]]; then
			printf '%s\n' "${line}"
			return 0
		fi
	done < <(platforma::discover_targets)
	return 1
}

platforma::record_field() {
	local record="$1"
	local index="$2"
	local fields=()
	IFS='|' read -r -a fields <<<"${record}"
	printf '%s' "${fields[${index}]:-}"
}

platforma::target_exists() {
	platforma::record_for_target "$1" >/dev/null 2>&1
}

platforma::profile_targets() {
	local profile="$1"
	local out
	out="$(yq e -r ".profiles.${profile}.targets // [] | .[]" "${PLATFORMA_CONFIG_FILE}" 2>/dev/null || true)"
	if [[ -n "${out}" ]]; then
		printf '%s\n' "${out}"
		return 0
	fi

	local line
	while IFS= read -r line; do
		[[ -n "${line}" ]] || continue
		printf '%s\n' "${line%%|*}"
	done < <(platforma::discover_targets)
}

platforma::dependencies_for_target() {
	local target="$1"
	local record deps_csv
	record="$(platforma::record_for_target "${target}" || true)"
	[[ -n "${record}" ]] || platforma::die "Unknown target: ${target}"
	deps_csv="$(platforma::record_field "${record}" 7)"

	local -a deps=()
	local dep
	IFS=',' read -r -a deps <<<"${deps_csv}"
	for dep in "${deps[@]-}"; do
		[[ -n "${dep}" ]] && printf '%s\n' "${dep}"
	done
}

platforma::dfs_order_target() {
	local target="$1"
	platforma::target_exists "${target}" || platforma::die "Unknown dependency target: ${target}"

	if platforma::array_contains "${target}" "${PLATFORMA_DFS_VISITED[@]:-}"; then
		return 0
	fi
	if platforma::array_contains "${target}" "${PLATFORMA_DFS_VISITING[@]:-}"; then
		platforma::die "Dependency cycle detected at target '${target}'"
	fi

	PLATFORMA_DFS_VISITING+=("${target}")

	local dep
	while IFS= read -r dep; do
		[[ -n "${dep}" ]] || continue
		platforma::dfs_order_target "${dep}"
	done < <(platforma::dependencies_for_target "${target}")

	local remaining
	remaining="$(platforma::array_remove "${target}" "${PLATFORMA_DFS_VISITING[@]:-}")"
	IFS=' ' read -r -a PLATFORMA_DFS_VISITING <<<"${remaining}"
	PLATFORMA_DFS_VISITED+=("${target}")
	PLATFORMA_DFS_ORDER+=("${target}")
}

platforma::ordered_targets_for_profile() {
	local profile="$1"
	PLATFORMA_DFS_VISITING=()
	PLATFORMA_DFS_VISITED=()
	PLATFORMA_DFS_ORDER=()

	local target
	while IFS= read -r target; do
		[[ -n "${target}" ]] || continue
		platforma::dfs_order_target "${target}"
	done < <(platforma::profile_targets "${profile}")

	printf '%s\n' "${PLATFORMA_DFS_ORDER[@]:-}"
}

platforma::list_targets() {
	printf '%-16s %-24s %-8s %-8s %s\n' "TARGET" "SERVICE" "VERSION" "RUNTIME" "PATH"
	local line
	while IFS= read -r line; do
		[[ -n "${line}" ]] || continue
		printf '%-16s %-24s %-8s %-8s %s\n' \
			"$(platforma::record_field "${line}" 0)" \
			"$(platforma::record_field "${line}" 2)" \
			"$(platforma::record_field "${line}" 3)" \
			"$(platforma::record_field "${line}" 4)" \
			"$(platforma::record_field "${line}" 5)"
	done < <(platforma::discover_targets)
}

platforma::catalog_json() {
	local first=1
	printf '['
	local line
	while IFS= read -r line; do
		[[ -n "${line}" ]] || continue
		local target service_key service_name version runtime path port deps_csv caps_csv health_path
		target="$(platforma::record_field "${line}" 0)"
		service_key="$(platforma::record_field "${line}" 1)"
		service_name="$(platforma::record_field "${line}" 2)"
		version="$(platforma::record_field "${line}" 3)"
		runtime="$(platforma::record_field "${line}" 4)"
		path="$(platforma::record_field "${line}" 5)"
		port="$(platforma::record_field "${line}" 6)"
		deps_csv="$(platforma::record_field "${line}" 7)"
		caps_csv="$(platforma::record_field "${line}" 8)"
		health_path="$(platforma::record_field "${line}" 12)"

		if [[ "${first}" == "0" ]]; then
			printf ','
		fi
		first=0

		printf '{'
		printf '"target":"%s",' "${target}"
		printf '"service_key":"%s",' "${service_key}"
		printf '"service":"%s",' "${service_name}"
		printf '"version":"%s",' "${version}"
		printf '"runtime":"%s",' "${runtime}"
		printf '"path":"%s",' "${path}"
		printf '"port":%s,' "${port:-0}"

		printf '"dependencies":['
		local dep_first=1 dep
		local -a deps=()
		IFS=',' read -r -a deps <<<"${deps_csv}"
		for dep in "${deps[@]-}"; do
			[[ -n "${dep}" ]] || continue
			if [[ "${dep_first}" == "0" ]]; then printf ','; fi
			dep_first=0
			printf '"%s"' "${dep}"
		done
		printf '],'

		printf '"capabilities":['
		local cap_first=1 cap
		local -a caps=()
		IFS=',' read -r -a caps <<<"${caps_csv}"
		for cap in "${caps[@]-}"; do
			[[ -n "${cap}" ]] || continue
			if [[ "${cap_first}" == "0" ]]; then printf ','; fi
			cap_first=0
			printf '"%s"' "${cap}"
		done
		printf '],'

		printf '"health_path":"%s"' "${health_path}"
		printf '}'
	done < <(platforma::discover_targets)
	printf ']\n'
}

platforma::graph_for_profile() {
	local profile="$1"
	local target
	while IFS= read -r target; do
		[[ -n "${target}" ]] || continue
		local deps_csv
		deps_csv="$(platforma::record_field "$(platforma::record_for_target "${target}")" 7)"
		if [[ -z "${deps_csv}" ]]; then
			printf '%s\n' "${target}"
			continue
		fi

		local -a deps=()
		local dep
		IFS=',' read -r -a deps <<<"${deps_csv}"
		for dep in "${deps[@]-}"; do
			[[ -n "${dep}" ]] || continue
			printf '%s -> %s\n' "${dep}" "${target}"
		done
	done < <(platforma::ordered_targets_for_profile "${profile}")
}

platforma::capabilities() {
	local only_target="${1:-}"
	printf '%-16s %-4s %-4s %-4s %-11s\n' "TARGET" "RUN" "LINT" "TEST" "BUILD-IMAGE"

	local line
	while IFS= read -r line; do
		[[ -n "${line}" ]] || continue
		local target caps
		target="$(platforma::record_field "${line}" 0)"
		[[ -n "${only_target}" && "${target}" != "${only_target}" ]] && continue
		caps="$(platforma::record_field "${line}" 8)"

		local run="no" lint="no" test="no" build="no"
		platforma::csv_contains "${caps}" "run" && run="yes"
		platforma::csv_contains "${caps}" "lint" && lint="yes"
		platforma::csv_contains "${caps}" "test" && test="yes"
		platforma::csv_contains "${caps}" "build-image" && build="yes"

		printf '%-16s %-4s %-4s %-4s %-11s\n' "${target}" "${run}" "${lint}" "${test}" "${build}"
	done < <(platforma::discover_targets)
}

platforma::validate_service_naming() {
	local issues=0
	local line
	while IFS= read -r line; do
		[[ -n "${line}" ]] || continue
		local key name expected
		key="$(platforma::record_field "${line}" 1)"
		name="$(platforma::record_field "${line}" 2)"
		expected="platforma-svc-${key}"
		if [[ "${name}" != "${expected}" ]]; then
			platforma::log "ERROR" "service name mismatch for ${key}: ${name} (expected ${expected})"
			issues=$((issues + 1))
		fi
	done < <(platforma::discover_targets)

	[[ "${issues}" -eq 0 ]] || return 1
	return 0
}

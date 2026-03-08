#!/usr/bin/env bash

platforma::migration_schema_dir() {
	local target="$1"
	printf '%s/services/%s/database/schemas' "${PLATFORMA_ROOT}" "${target}"
}

platforma::migration_files_for_target() {
	local target="$1"
	local schema_dir
	schema_dir="$(platforma::migration_schema_dir "${target}")"
	[[ -d "${schema_dir}" ]] || return 0

	local file
	while IFS= read -r file; do
		[[ -n "${file}" ]] || continue
		printf '%s\n' "${file}"
	done < <(find "${schema_dir}" -maxdepth 1 -type f -name '*.sql' | sort)
}

platforma::migration_checksum() {
	local file="$1"
	if command -v shasum >/dev/null 2>&1; then
		shasum -a 256 "${file}" | awk '{print $1}'
		return 0
	fi
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "${file}" | awk '{print $1}'
		return 0
	fi
	platforma::die "Missing checksum command: shasum or sha256sum"
}

platforma::migrations_verify_target() {
	local target="$1"
	platforma::target_exists "${target}" || platforma::die "Unknown migration target: ${target}"

	local schema_dir
	schema_dir="$(platforma::migration_schema_dir "${target}")"
	if [[ ! -d "${schema_dir}" ]]; then
		platforma::log "INFO" "migrations verify: ${target} has no schema directory (${schema_dir}), skipping"
		return 0
	fi

	local previous_seq=-1
	local issues=0
	local file_count=0
	local file
	while IFS= read -r file; do
		[[ -n "${file}" ]] || continue
		file_count=$((file_count + 1))
		local base
		base="$(basename "${file}")"

		if [[ ! "${base}" =~ ^([0-9]{3})_[A-Za-z0-9_]+\.sql$ ]]; then
			platforma::log "ERROR" "migrations verify: ${target} has invalid migration name '${base}'"
			issues=$((issues + 1))
			continue
		fi

		local seq
		seq=$((10#${BASH_REMATCH[1]}))
		if [[ "${previous_seq}" -ge 0 ]]; then
			if [[ "${seq}" -le "${previous_seq}" ]]; then
				platforma::log "ERROR" "migrations verify: ${target} migration order is not increasing at '${base}'"
				issues=$((issues + 1))
			fi
			if [[ "${seq}" -ne $((previous_seq + 1)) ]]; then
				platforma::log "ERROR" "migrations verify: ${target} migration sequence gap before '${base}'"
				issues=$((issues + 1))
			fi
		fi
		previous_seq="${seq}"

		if [[ ! -s "${file}" ]]; then
			platforma::log "ERROR" "migrations verify: ${target} migration '${base}' is empty"
			issues=$((issues + 1))
		fi

		local drop_hits
		drop_hits="$(rg -n -i '^\s*drop\s+(table|column)\b' "${file}" || true)"
		if [[ -n "${drop_hits}" ]]; then
			platforma::log "ERROR" "migrations verify: ${target} migration '${base}' contains destructive drop statement"
			printf '%s\n' "${drop_hits}" >&2
			issues=$((issues + 1))
		fi
	done < <(platforma::migration_files_for_target "${target}")

	if [[ "${file_count}" -eq 0 ]]; then
		platforma::log "INFO" "migrations verify: ${target} has no migration files, skipping"
		return 0
	fi

	[[ "${issues}" -eq 0 ]] || return 1
	platforma::log "INFO" "migrations verify: ${target} passed (${file_count} migration files)"
	return 0
}

platforma::migrations_verify() {
	local only_target="${1:-}"
	local issues=0
	local verified=0

	if [[ -n "${only_target}" ]]; then
		platforma::migrations_verify_target "${only_target}" || issues=$((issues + 1))
		verified=1
	else
		local line target
		while IFS= read -r line; do
			[[ -n "${line}" ]] || continue
			target="$(platforma::record_field "${line}" 0)"
			platforma::migrations_verify_target "${target}" || issues=$((issues + 1))
			verified=$((verified + 1))
		done < <(platforma::discover_targets)
	fi

	[[ "${issues}" -eq 0 ]] || platforma::die "migrations verify failed with ${issues} issue(s)"
	platforma::log "INFO" "migrations verify passed for ${verified} target(s)"
}

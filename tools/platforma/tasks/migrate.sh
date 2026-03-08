#!/usr/bin/env bash

platforma::migration_state_dir() {
	printf '%s/tools/platforma/state/migrations' "${PLATFORMA_ROOT}"
}

platforma::migration_state_file() {
	local target="$1"
	printf '%s/%s.applied' "$(platforma::migration_state_dir)" "${target}"
}

platforma::migrate_target() {
	local target="$1"
	local dry_run="${2:-0}"

	platforma::target_exists "${target}" || platforma::die "Unknown migration target: ${target}"
	platforma::migrations_verify_target "${target}"

	local schema_dir
	schema_dir="$(platforma::migration_schema_dir "${target}")"
	[[ -d "${schema_dir}" ]] || platforma::die "No migration directory for target '${target}' (${schema_dir})"

	local state_dir state_file
	state_dir="$(platforma::migration_state_dir)"
	state_file="$(platforma::migration_state_file "${target}")"
	if [[ "${dry_run}" != "1" ]]; then
		mkdir -p "${state_dir}"
		touch "${state_file}"
	fi

	local pending=0
	local applied=0
	local file
	while IFS= read -r file; do
		[[ -n "${file}" ]] || continue
		local base checksum
		base="$(basename "${file}")"
		checksum="$(platforma::migration_checksum "${file}")"
		pending=$((pending + 1))

		if [[ "${dry_run}" == "1" ]]; then
			printf 'DRY-RUN migrate %s: would apply %s (sha256=%s)\n' "${target}" "${base}" "${checksum}"
			continue
		fi

		if rg -q "^${base}\\|${checksum}\\|" "${state_file}"; then
			platforma::log "INFO" "migrate ${target}: ${base} already applied"
			continue
		fi

		printf '%s|%s|%s\n' "${base}" "${checksum}" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >>"${state_file}"
		applied=$((applied + 1))
		platforma::log "INFO" "migrate ${target}: applied ${base}"
	done < <(platforma::migration_files_for_target "${target}")

	if [[ "${pending}" -eq 0 ]]; then
		platforma::log "INFO" "migrate ${target}: no migration files found"
		return 0
	fi

	if [[ "${dry_run}" == "1" ]]; then
		platforma::log "INFO" "migrate ${target}: dry-run complete (${pending} planned)"
	else
		platforma::log "INFO" "migrate ${target}: complete (${applied}/${pending} applied)"
	fi
}

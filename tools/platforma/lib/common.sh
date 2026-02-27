#!/usr/bin/env bash

platforma::log() {
	local level="$1"
	shift || true
	printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${level}" "$*" >&2
}

platforma::die() {
	platforma::log "ERROR" "$*"
	exit 1
}

platforma::require_command() {
	local cmd="$1"
	command -v "${cmd}" >/dev/null 2>&1 || platforma::die "Missing required command: ${cmd}"
}

platforma::ensure_state_dirs() {
	mkdir -p "${PLATFORMA_PIDS_DIR}" "${PLATFORMA_LOGS_DIR}"
}

platforma::default_env() {
	yq e -r '.defaults.env // "local"' "${PLATFORMA_CONFIG_FILE}" 2>/dev/null || printf 'local'
}

platforma::default_profile() {
	yq e -r '.defaults.profile // "core"' "${PLATFORMA_CONFIG_FILE}" 2>/dev/null || printf 'core'
}

platforma::csv_contains() {
	local csv="$1"
	local needle="$2"
	local -a items=()
	IFS=',' read -r -a items <<<"${csv}"
	local item
	for item in "${items[@]-}"; do
		[[ "${item}" == "${needle}" ]] && return 0
	done
	return 1
}

platforma::shell_join() {
	local out=""
	local arg
	for arg in "$@"; do
		local q
		q="$(printf '%q' "${arg}")"
		if [[ -z "${out}" ]]; then
			out="${q}"
		else
			out+=" ${q}"
		fi
	done
	printf '%s' "${out}"
}

platforma::array_contains() {
	local needle="$1"
	shift || true
	local item
	for item in "$@"; do
		[[ "${item}" == "${needle}" ]] && return 0
	done
	return 1
}

platforma::array_remove() {
	local needle="$1"
	shift || true
	local out=()
	local item
	for item in "$@"; do
		[[ "${item}" == "${needle}" ]] && continue
		out+=("${item}")
	done
	printf '%s\n' "${out[@]:-}"
}

platforma::pid_file() {
	local target="$1"
	printf '%s/%s.pid' "${PLATFORMA_PIDS_DIR}" "${target}"
}

platforma::log_file() {
	local target="$1"
	printf '%s/%s.log' "${PLATFORMA_LOGS_DIR}" "${target}"
}

platforma::pid_running() {
	local pid="$1"
	kill -0 "${pid}" >/dev/null 2>&1
}

platforma::validate_semver() {
	local value="$1"
	[[ "${value}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

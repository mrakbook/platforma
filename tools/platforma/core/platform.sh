#!/usr/bin/env bash

platforma::up_profile() {
	local profile="$1"
	local env_name="$2"

	local target
	while IFS= read -r target; do
		[[ -n "${target}" ]] || continue
		platforma::run_task run "${target}" "${env_name}" 1
	done < <(platforma::ordered_targets_for_profile "${profile}")
}

platforma::restart_profile() {
	local profile="$1"
	local env_name="$2"

	platforma::down

	local target
	while IFS= read -r target; do
		[[ -n "${target}" ]] || continue
		platforma::run_task run "${target}" "${env_name}" 1
	done < <(platforma::ordered_targets_for_profile "${profile}")
}

platforma::status() {
	platforma::ensure_state_dirs
	printf '%-16s %-10s %s\n' "TARGET" "STATUS" "PID"

	local line
	while IFS= read -r line; do
		[[ -n "${line}" ]] || continue
		local target pid_file pid status
		target="$(platforma::record_field "${line}" 0)"
		pid_file="$(platforma::pid_file "${target}")"
		status="stopped"
		pid="-"

		if [[ -f "${pid_file}" ]]; then
			pid="$(cat "${pid_file}" 2>/dev/null || true)"
			if [[ -n "${pid}" ]] && platforma::pid_running "${pid}"; then
				status="running"
			else
				status="stale"
			fi
		fi

		printf '%-16s %-10s %s\n' "${target}" "${status}" "${pid}"
	done < <(platforma::discover_targets)
}

platforma::down() {
	platforma::ensure_state_dirs

	local line
	while IFS= read -r line; do
		[[ -n "${line}" ]] || continue
		local target pid_file pid
		target="$(platforma::record_field "${line}" 0)"
		pid_file="$(platforma::pid_file "${target}")"
		[[ -f "${pid_file}" ]] || continue

		pid="$(cat "${pid_file}" 2>/dev/null || true)"
		[[ -n "${pid}" ]] || {
			rm -f "${pid_file}"
			continue
		}

		if platforma::pid_running "${pid}"; then
			kill "${pid}" >/dev/null 2>&1 || true
			sleep 1
			if platforma::pid_running "${pid}"; then
				kill -9 "${pid}" >/dev/null 2>&1 || true
			fi
			platforma::log "INFO" "stopped ${target} (pid ${pid})"
		fi

		rm -f "${pid_file}"
	done < <(platforma::discover_targets)
}

platforma::health() {
	local profile="$1"
	platforma::require_command curl
	printf '%-16s %-8s %s\n' "TARGET" "STATUS" "URL"

	local target
	while IFS= read -r target; do
		[[ -n "${target}" ]] || continue
		local record port path url
		record="$(platforma::record_for_target "${target}")"
		port="$(platforma::record_field "${record}" 6)"
		path="$(platforma::record_field "${record}" 12)"
		url="http://127.0.0.1:${port}${path}"

		if curl -fsS "${url}" >/dev/null 2>&1; then
			printf '%-16s %-8s %s\n' "${target}" "ok" "${url}"
		else
			printf '%-16s %-8s %s\n' "${target}" "down" "${url}"
		fi
	done < <(platforma::ordered_targets_for_profile "${profile}")
}

platforma::logs() {
	local target="${1:-}"
	local follow="${2:-0}"
	platforma::ensure_state_dirs

	if [[ -n "${target}" ]]; then
		local file
		file="$(platforma::log_file "${target}")"
		[[ -f "${file}" ]] || platforma::die "No log file for target '${target}'"

		if [[ "${follow}" == "1" ]]; then
			tail -f "${file}"
		else
			tail -n 200 "${file}"
		fi
		return 0
	fi

	local line
	while IFS= read -r line; do
		[[ -n "${line}" ]] || continue
		local name file
		name="$(platforma::record_field "${line}" 0)"
		file="$(platforma::log_file "${name}")"
		[[ -f "${file}" ]] || continue
		printf '===== %s =====\n' "${name}"
		tail -n 50 "${file}"
	done < <(platforma::discover_targets)
}

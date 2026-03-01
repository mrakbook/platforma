#!/usr/bin/env bash

platforma::doctor() {
	local profile="$1"
	local issues=0

	printf '%-14s %-7s %s\n' "CHECK" "STATUS" "DETAIL"

	local catalog target_count
	catalog="$(platforma::discover_targets)"
	target_count="$(printf '%s\n' "${catalog}" | awk 'NF { count += 1 } END { print count + 0 }')"
	if [[ "${target_count}" -gt 0 ]]; then
		printf '%-14s %-7s %s\n' "discovery" "ok" "${target_count} targets discovered"
	else
		printf '%-14s %-7s %s\n' "discovery" "fail" "no targets discovered"
		issues=$((issues + 1))
	fi

	local profile_target_count=0
	local profile_target
	while IFS= read -r profile_target; do
		[[ -n "${profile_target}" ]] || continue
		profile_target_count=$((profile_target_count + 1))
		if ! platforma::target_exists "${profile_target}"; then
			printf '%-14s %-7s %s\n' "profile" "fail" "unknown profile target '${profile_target}'"
			issues=$((issues + 1))
		fi
	done < <(platforma::profile_targets "${profile}")

	if [[ "${profile_target_count}" -gt 0 ]]; then
		printf '%-14s %-7s %s\n' "profile" "ok" "${profile_target_count} targets in profile '${profile}'"
	else
		printf '%-14s %-7s %s\n' "profile" "fail" "profile '${profile}' resolved to zero targets"
		issues=$((issues + 1))
	fi

	local ordered
	ordered="$(platforma::ordered_targets_for_profile "${profile}")"
	local ordered_count
	ordered_count="$(printf '%s\n' "${ordered}" | awk 'NF { count += 1 } END { print count + 0 }')"
	printf '%-14s %-7s %s\n' "order" "ok" "${ordered_count} targets resolved in dependency order"

	local missing_run=0
	local target record caps
	while IFS= read -r target; do
		[[ -n "${target}" ]] || continue
		record="$(platforma::record_for_target "${target}")"
		caps="$(platforma::record_field "${record}" 8)"
		if ! platforma::csv_contains "${caps}" "run"; then
			missing_run=$((missing_run + 1))
			issues=$((issues + 1))
		fi
	done < <(printf '%s\n' "${ordered}")

	if [[ "${missing_run}" -eq 0 ]]; then
		printf '%-14s %-7s %s\n' "capabilities" "ok" "all profile targets support run"
	else
		printf '%-14s %-7s %s\n' "capabilities" "fail" "${missing_run} profile targets missing run capability"
	fi

	[[ "${issues}" -eq 0 ]] || platforma::die "doctor failed with ${issues} issue(s)"
	platforma::log "INFO" "doctor checks passed for profile '${profile}'"
}

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

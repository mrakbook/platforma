#!/usr/bin/env bash

platforma::target_env_export() {
	local target="$1"
	local env_name="$2"
	local record cfg
	record="$(platforma::record_for_target "${target}" || true)"
	[[ -n "${record}" ]] || platforma::die "Unknown target: ${target}"

	cfg="${PLATFORMA_ROOT}/$(platforma::record_field "${record}" 5)/config.yaml"
	while IFS= read -r line; do
		[[ -n "${line}" ]] || continue
		local key="${line%%=*}"
		local value="${line#*=}"
		export "${key}=${value}"
	done < <(yq e -r ".${env_name}.config_env // {} | to_entries[] | .key + \"=\" + (.value|tostring)" "${cfg}" 2>/dev/null || true)
}

platforma::task_command() {
	local task="$1"
	local record="$2"
	local runtime value
	runtime="$(platforma::record_field "${record}" 4)"

	case "${task}" in
	run)
		value="$(platforma::record_field "${record}" 9)"
		[[ -n "${value}" ]] && {
			printf '%s' "${value}"
			return 0
		}
		;;
	lint)
		value="$(platforma::record_field "${record}" 10)"
		[[ -n "${value}" ]] && {
			printf '%s' "${value}"
			return 0
		}
		;;
	test)
		value="$(platforma::record_field "${record}" 11)"
		[[ -n "${value}" ]] && {
			printf '%s' "${value}"
			return 0
		}
		;;
	build-image)
		printf '%s' 'echo "build-image is a demo no-op"'
		return 0
		;;
	esac

	case "${runtime}" in
	python)
		case "${task}" in
		run) printf '%s' 'python3 src/main.py' ;;
		lint) printf '%s' 'python3 -c "import ast,pathlib; ast.parse(pathlib.Path(\"src/main.py\").read_text())"' ;;
		test) printf '%s' 'python3 -m unittest discover -s tests -p "test_*.py"' ;;
		build-image) printf '%s' 'echo "build-image is a demo no-op"' ;;
		*) printf '%s' '' ;;
		esac
		;;
	*)
		printf '%s' ''
		;;
	esac
}

platforma::run_task() {
	local task="$1"
	local target="$2"
	local env_name="$3"
	local background="$4"
	shift 4 || true

	local record
	record="$(platforma::record_for_target "${target}" || true)"
	[[ -n "${record}" ]] || platforma::die "Unknown target: ${target}"

	local caps
	caps="$(platforma::record_field "${record}" 8)"
	platforma::csv_contains "${caps}" "${task}" || platforma::die "Target '${target}' does not support task '${task}'"

	platforma::target_env_export "${target}" "${env_name}"

	local command
	command="$(platforma::task_command "${task}" "${record}")"
	[[ -n "${command}" ]] || platforma::die "No command for task '${task}' on target '${target}'"

	if [[ "$#" -gt 0 ]]; then
		command+=" $(platforma::shell_join "$@")"
	fi

	local target_path target_abs
	target_path="$(platforma::record_field "${record}" 5)"
	target_abs="${PLATFORMA_ROOT}/${target_path}"

	if [[ "${background}" == "1" ]]; then
		platforma::ensure_state_dirs
		local pid_file log_file
		pid_file="$(platforma::pid_file "${target}")"
		log_file="$(platforma::log_file "${target}")"

		if [[ -f "${pid_file}" ]]; then
			local existing_pid
			existing_pid="$(cat "${pid_file}" 2>/dev/null || true)"
			if [[ -n "${existing_pid}" ]] && platforma::pid_running "${existing_pid}"; then
				platforma::log "WARN" "${target} already running with pid ${existing_pid}"
				return 0
			fi
			rm -f "${pid_file}"
		fi

		(
			cd "${target_abs}" || exit 1
			nohup bash -lc "${command}" >>"${log_file}" 2>&1 &
			echo "$!" >"${pid_file}"
		)

		local pid
		pid="$(cat "${pid_file}")"
		platforma::log "INFO" "started ${target} (pid ${pid})"
		return 0
	fi

	(
		cd "${target_abs}" || exit 1
		bash -lc "${command}"
	)
}

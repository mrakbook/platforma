#!/usr/bin/env bash

platforma::versions_sync_check() {
	local issues=0
	local line

	while IFS= read -r line; do
		[[ -n "${line}" ]] || continue
		local target version path pyproject pyproject_version
		target="$(platforma::record_field "${line}" 0)"
		version="$(platforma::record_field "${line}" 3)"
		path="$(platforma::record_field "${line}" 5)"

		if ! platforma::validate_semver "${version}"; then
			platforma::log "ERROR" "invalid version for ${target}: ${version}"
			issues=$((issues + 1))
		fi

		pyproject="${PLATFORMA_ROOT}/${path}/pyproject.toml"
		if [[ -f "${pyproject}" ]]; then
			pyproject_version="$(sed -n 's/^version = "\([0-9]\+\.[0-9]\+\.[0-9]\+\)"/\1/p' "${pyproject}" | head -n 1)"
			if [[ -n "${pyproject_version}" && "${pyproject_version}" != "${version}" ]]; then
				platforma::log "ERROR" "version mismatch for ${target}: config=${version}, pyproject=${pyproject_version}"
				issues=$((issues + 1))
			fi
		fi
	done < <(platforma::discover_targets)

	platforma::validate_service_naming || issues=$((issues + 1))

	[[ "${issues}" -eq 0 ]] || platforma::die "versions sync-check failed with ${issues} issue(s)"
	platforma::log "INFO" "versions sync-check passed"
}

platforma::bump_semver() {
	local version="$1"
	local bump="$2"
	platforma::validate_semver "${version}" || platforma::die "Invalid semver: ${version}"

	local major minor patch
	IFS='.' read -r major minor patch <<<"${version}"

	case "${bump}" in
	major)
		major=$((major + 1))
		minor=0
		patch=0
		;;
	minor)
		minor=$((minor + 1))
		patch=0
		;;
	patch)
		patch=$((patch + 1))
		;;
	*)
		platforma::die "Unsupported bump: ${bump}"
		;;
	esac

	printf '%s.%s.%s' "${major}" "${minor}" "${patch}"
}

platforma::versions_service_bump() {
	local target="$1"
	local bump="$2"
	local record path cfg current new_version pyproject

	record="$(platforma::record_for_target "${target}" || true)"
	[[ -n "${record}" ]] || platforma::die "Unknown target: ${target}"
	path="$(platforma::record_field "${record}" 5)"
	cfg="${PLATFORMA_ROOT}/${path}/config.yaml"
	current="$(yq e -r '.version // ""' "${cfg}")"
	[[ -n "${current}" ]] || platforma::die "Missing version in ${cfg}"

	new_version="$(platforma::bump_semver "${current}" "${bump}")"
	yq -i ".version = \"${new_version}\"" "${cfg}"

	pyproject="${PLATFORMA_ROOT}/${path}/pyproject.toml"
	if [[ -f "${pyproject}" ]]; then
		sed -i.bak "s/^version = \"${current}\"/version = \"${new_version}\"/" "${pyproject}" && rm -f "${pyproject}.bak"
	fi

	platforma::log "INFO" "bumped ${target}: ${current} -> ${new_version}"
}

platforma::versions_platform_bump() {
	local bump="$1"
	local cfg="${PLATFORMA_ROOT}/config.yaml"
	local current new_version

	current="$(yq e -r '.platform.version // "0.1.0"' "${cfg}")"
	new_version="$(platforma::bump_semver "${current}" "${bump}")"
	yq -i ".platform.version = \"${new_version}\"" "${cfg}"
	platforma::log "INFO" "bumped platform version: ${current} -> ${new_version}"
}

platforma::versions_module_bump() {
	local bump="$1"
	local cfg="${PLATFORMA_CONFIG_FILE}"
	local current new_version

	current="$(yq e -r '.module.version // "0.1.0"' "${cfg}")"
	new_version="$(platforma::bump_semver "${current}" "${bump}")"
	yq -i ".module.version = \"${new_version}\"" "${cfg}"
	platforma::log "INFO" "bumped module version: ${current} -> ${new_version}"
}

platforma::quality_hardening() {
	platforma::require_command rg

	local search_paths=()
	local path
	for path in README.md docs tools services posts .github/workflows; do
		if [[ -e "${PLATFORMA_ROOT}/${path}" ]]; then
			search_paths+=("${PLATFORMA_ROOT}/${path}")
		fi
	done

	local matches
	matches="$(rg -n --no-heading '(\./v[a-z]{2}\b|[a-z]{3}::|tools/v[a-z]{2}|docs/v[a-z]{2})' "${search_paths[@]}" || true)"
	if [[ -n "${matches}" ]]; then
		printf '%s\n' "${matches}" >&2
		platforma::die "quality hardening failed: legacy command references found"
	fi

	platforma::log "INFO" "quality hardening passed"
}

platforma::quality_compat() {
	platforma::validate_service_naming || platforma::die "quality compat failed"
	platforma::log "INFO" "quality compat passed"
}

platforma::quality_all() {
	platforma::quality_hardening
	platforma::quality_compat
	platforma::log "INFO" "quality all passed"
}

platforma::ci_contract_check() {
	platforma::quality_hardening
	platforma::log "INFO" "ci contract-check passed"
}

platforma::ci_release_gate() {
	platforma::migrations_verify
	platforma::versions_sync_check
	platforma::ci_contract_check
	platforma::quality_all
	platforma::log "INFO" "ci release-gate passed"
}

platforma::migrations_verify() {
	platforma::log "INFO" "no migration workflows in demo mode"
}

platforma::help() {
	cat <<'EOF'
Usage:
  ./platforma <command> [subcommand] [options]

Commands:
  run <target>                     Run target in foreground
  lint <target|--all>              Run lint task
  test <target|--all>              Run test task
  build-image <target>             Demo image build task

  up [--profile <name>]            Start profile targets in background
  doctor [--profile <name>]        Run local preflight checks
  down                             Stop all running targets
  restart [--profile <name>]       Restart profile targets
  status                           Show target process status
  health [--profile <name>]        Show health checks
  logs [target] [--follow]         Show logs

  targets list
  targets catalog [--json]
  targets graph [--profile <name>]
  targets capabilities [target]

  versions sync-check
  versions service <target> <major|minor|patch>
  versions platform <major|minor|patch>
  versions module <major|minor|patch>

  migrations verify

  ci contract-check
  ci release-gate

  quality hardening
  quality compat
  quality all
EOF
}

platforma::main() {
	platforma::require_command yq

	local command="${1:-help}"
	shift || true

	local env_name profile
	env_name="$(platforma::default_env)"
	profile="$(platforma::default_profile)"

	case "${command}" in
	help | -h | --help)
		platforma::help
		;;

	targets)
		local sub="${1:-list}"
		[[ $# -gt 0 ]] && shift || true
		case "${sub}" in
		list)
			platforma::list_targets
			;;
		catalog)
			if [[ "${1:-}" == "--json" ]]; then
				platforma::catalog_json
			else
				platforma::list_targets
			fi
			;;
		graph)
			while [[ $# -gt 0 ]]; do
				case "$1" in
				--profile)
					profile="$2"
					shift 2
					;;
				--profile=*)
					profile="${1#*=}"
					shift
					;;
				*)
					shift
					;;
				esac
			done
			platforma::graph_for_profile "${profile}"
			;;
		capabilities)
			platforma::capabilities "${1:-}"
			;;
		*)
			platforma::die "Unknown targets subcommand: ${sub}"
			;;
		esac
		;;

	run | lint | test | build-image)
		local task="${command}"
		local target="${1:-}"
		[[ -n "${target}" ]] || platforma::die "${task} requires a target"
		shift || true

		while [[ $# -gt 0 ]]; do
			case "$1" in
			--env)
				env_name="$2"
				shift 2
				;;
			--env=*)
				env_name="${1#*=}"
				shift
				;;
			--profile)
				profile="$2"
				shift 2
				;;
			--profile=*)
				profile="${1#*=}"
				shift
				;;
			*)
				break
				;;
			esac
		done

		if [[ "${target}" == "--all" && ("${task}" == "lint" || "${task}" == "test") ]]; then
			local t
			while IFS= read -r t; do
				[[ -n "${t}" ]] || continue
				platforma::run_task "${task}" "${t}" "${env_name}" 0 "$@"
			done < <(platforma::ordered_targets_for_profile "${profile}")
		else
			platforma::run_task "${task}" "${target}" "${env_name}" 0 "$@"
		fi
		;;

	up)
		while [[ $# -gt 0 ]]; do
			case "$1" in
			--profile)
				profile="$2"
				shift 2
				;;
			--profile=*)
				profile="${1#*=}"
				shift
				;;
			--env)
				env_name="$2"
				shift 2
				;;
			--env=*)
				env_name="${1#*=}"
				shift
				;;
			*)
				shift
				;;
			esac
		done
		platforma::up_profile "${profile}" "${env_name}"
		;;

	doctor)
		while [[ $# -gt 0 ]]; do
			case "$1" in
			--profile)
				profile="$2"
				shift 2
				;;
			--profile=*)
				profile="${1#*=}"
				shift
				;;
			*)
				shift
				;;
			esac
		done
		platforma::doctor "${profile}"
		;;

	down)
		platforma::down
		;;

	restart)
		while [[ $# -gt 0 ]]; do
			case "$1" in
			--profile)
				profile="$2"
				shift 2
				;;
			--profile=*)
				profile="${1#*=}"
				shift
				;;
			--env)
				env_name="$2"
				shift 2
				;;
			--env=*)
				env_name="${1#*=}"
				shift
				;;
			*)
				shift
				;;
			esac
		done
		platforma::restart_profile "${profile}" "${env_name}"
		;;

	status)
		platforma::status
		;;

	health)
		while [[ $# -gt 0 ]]; do
			case "$1" in
			--profile)
				profile="$2"
				shift 2
				;;
			--profile=*)
				profile="${1#*=}"
				shift
				;;
			*)
				shift
				;;
			esac
		done
		platforma::health "${profile}"
		;;

	logs)
		local target=""
		local follow=0
		while [[ $# -gt 0 ]]; do
			case "$1" in
			--follow)
				follow=1
				shift
				;;
			*)
				target="$1"
				shift
				;;
			esac
		done
		platforma::logs "${target}" "${follow}"
		;;

	versions)
		local sub="${1:-}"
		[[ -n "${sub}" ]] || platforma::die "versions requires a subcommand"
		shift || true
		case "${sub}" in
		sync-check)
			platforma::versions_sync_check
			;;
		sync-projections | sync-projections-check | render)
			platforma::versions_sync_check
			;;
		service)
			[[ $# -ge 2 ]] || platforma::die "versions service requires <target> <major|minor|patch>"
			platforma::versions_service_bump "$1" "$2"
			;;
		platform)
			[[ $# -ge 1 ]] || platforma::die "versions platform requires <major|minor|patch>"
			platforma::versions_platform_bump "$1"
			;;
		module)
			[[ $# -ge 1 ]] || platforma::die "versions module requires <major|minor|patch>"
			platforma::versions_module_bump "$1"
			;;
		*)
			platforma::die "Unknown versions subcommand: ${sub}"
			;;
		esac
		;;

	migrations)
		local sub="${1:-verify}"
		case "${sub}" in
		verify | up)
			platforma::migrations_verify
			;;
		*)
			platforma::die "Unknown migrations subcommand: ${sub}"
			;;
		esac
		;;

	ci)
		local sub="${1:-}"
		[[ -n "${sub}" ]] || platforma::die "ci requires a subcommand"
		case "${sub}" in
		contract-check)
			platforma::ci_contract_check
			;;
		release-gate)
			platforma::ci_release_gate
			;;
		*)
			platforma::die "Unknown ci subcommand: ${sub}"
			;;
		esac
		;;

	quality)
		local sub="${1:-all}"
		case "${sub}" in
		hardening)
			platforma::quality_hardening
			;;
		compat)
			platforma::quality_compat
			;;
		all)
			platforma::quality_all
			;;
		*)
			platforma::die "Unknown quality subcommand: ${sub}"
			;;
		esac
		;;

	*)
		platforma::die "Unknown command: ${command}. Run './platforma help'."
		;;
	esac
}

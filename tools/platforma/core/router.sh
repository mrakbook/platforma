#!/usr/bin/env bash

platforma::help() {
	cat <<'EOF'
Usage:
  ./platforma <command> [subcommand] [options]

Commands:
  run <target>                     Run target in foreground
  lint <target|--all>              Run lint task
  test <target|--all>              Run test task
  build-image <target>             Demo image build task
  migrate <target> [--dry-run]     Execute target migrations

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

  migrations verify [target]

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

	migrate)
		local target="${1:-}"
		[[ -n "${target}" ]] || platforma::die "migrate requires <target>"
		shift || true

		local dry_run=0
		while [[ $# -gt 0 ]]; do
			case "$1" in
			--dry-run)
				dry_run=1
				shift
				;;
			*)
				platforma::die "Unknown migrate option: $1"
				;;
			esac
		done
		platforma::migrate_target "${target}" "${dry_run}"
		;;

	migrations)
		local sub="${1:-verify}"
		[[ $# -gt 0 ]] && shift || true
		case "${sub}" in
		verify)
			platforma::migrations_verify "${1:-}"
			;;
		up)
			[[ $# -ge 1 ]] || platforma::die "migrations up requires <target>; use 'migrate <target>'"
			platforma::migrate_target "$1" 0
			;;
		*)
			platforma::die "Unknown migrations subcommand: ${sub}"
			;;
		esac
		;;

	ci)
		local sub="${1:-}"
		[[ -n "${sub}" ]] || platforma::die "ci requires a subcommand"
		shift || true
		case "${sub}" in
		contract-check)
			[[ $# -eq 0 ]] || platforma::die "Unknown ci option: $1"
			platforma::ci_contract_check
			;;
		release-gate)
			[[ $# -eq 0 ]] || platforma::die "Unknown ci option: $1"
			platforma::ci_release_gate
			;;
		*)
			platforma::die "Unknown ci subcommand: ${sub}"
			;;
		esac
		;;

	quality)
		local sub="${1:-all}"
		[[ $# -gt 0 ]] && shift || true
		case "${sub}" in
		hardening)
			[[ $# -eq 0 ]] || platforma::die "Unknown quality option: $1"
			platforma::quality_hardening
			;;
		compat)
			[[ $# -eq 0 ]] || platforma::die "Unknown quality option: $1"
			platforma::quality_compat
			;;
		all)
			[[ $# -eq 0 ]] || platforma::die "Unknown quality option: $1"
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

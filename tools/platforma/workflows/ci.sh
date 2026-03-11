#!/usr/bin/env bash

platforma::ci_contract_check_workflows() {
	local workflow_dir="${PLATFORMA_ROOT}/.github/workflows"
	if [[ ! -d "${workflow_dir}" ]]; then
		platforma::log "INFO" "ci contract-check: no workflow directory found, skipping workflow scan"
		return 0
	fi

	local workflow_files=()
	local file
	while IFS= read -r file; do
		[[ -n "${file}" ]] || continue
		workflow_files+=("${file}")
	done < <(find "${workflow_dir}" -type f \( -name '*.yml' -o -name '*.yaml' \) | sort)

	if [[ "${#workflow_files[@]}" -eq 0 ]]; then
		platforma::log "INFO" "ci contract-check: no workflow files found, skipping workflow scan"
		return 0
	fi

	local missing_contract=()
	for file in "${workflow_files[@]}"; do
		rg -q --fixed-strings './platforma' "${file}" || missing_contract+=("${file}")
	done

	if [[ "${#missing_contract[@]}" -gt 0 ]]; then
		printf '%s\n' "ci contract-check: workflows missing ./platforma contract:" >&2
		printf ' - %s\n' "${missing_contract[@]}" >&2
		platforma::die "ci contract-check failed: workflow command contract violation"
	fi

	local forbidden_matches
	forbidden_matches="$(rg -n --no-heading \
		-e '(^|[^[:alnum:]_])\./v[a-z]{2}\b' \
		-e '(^|[^[:alnum:]_])v[a-z]{2}::' \
		-e '(^|[^[:alnum:]_])(python3?|uv|bash)\s+services/[A-Za-z0-9._/-]+' \
		-e '(^|[^[:alnum:]_])\./services/[A-Za-z0-9._/-]+' \
		"${workflow_files[@]}" || true)"

	if [[ -n "${forbidden_matches}" ]]; then
		printf '%s\n' "${forbidden_matches}" >&2
		platforma::die "ci contract-check failed: forbidden workflow command patterns found"
	fi
}

platforma::ci_contract_check() {
	platforma::quality_hardening
	platforma::ci_contract_check_workflows
	platforma::log "INFO" "ci contract-check passed"
}

platforma::ci_release_gate() {
	platforma::migrations_verify
	platforma::versions_sync_check
	platforma::ci_contract_check
	platforma::quality_all
	platforma::log "INFO" "ci release-gate passed"
}

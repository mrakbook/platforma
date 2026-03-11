#!/usr/bin/env bash

platforma::quality_hardening() {
	platforma::require_command rg

	local search_paths=()
	local candidate
	for candidate in \
		"${PLATFORMA_ROOT}/platforma" \
		"${PLATFORMA_ROOT}/README.md" \
		"${PLATFORMA_ROOT}/docs/platforma" \
		"${PLATFORMA_ROOT}/tools/platforma" \
		"${PLATFORMA_ROOT}/services"; do
		[[ -e "${candidate}" ]] || continue
		search_paths+=("${candidate}")
	done

	local matches
	matches="$(rg -n --no-heading \
		--glob '!**/state/**' \
		--glob '!**/database/schemas/**' \
		-e '(^|[^[:alnum:]_])\./v[a-z]{2}\b' \
		-e '(^|[^[:alnum:]_])v[a-z]{2}::' \
		-e '(^|[^[:alnum:]_])(tools|docs)/v[a-z]{2}\b' \
		"${search_paths[@]}" || true)"

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

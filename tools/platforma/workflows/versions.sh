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

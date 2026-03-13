#!/usr/bin/env python3

import json
import os
import sys
from typing import Iterable


GLOBAL_CHANGE_PREFIXES = (
    "platforma",
    "config.yaml",
    "tools/platforma/",
    ".github/workflows/",
)


def parse_catalog() -> list[dict]:
    raw = os.environ.get("CATALOG_JSON", "")
    if not raw:
        raise ValueError("CATALOG_JSON is required")
    catalog = json.loads(raw)
    if not isinstance(catalog, list):
        raise ValueError("CATALOG_JSON must be a JSON array")
    return catalog


def parse_changed_files() -> list[str]:
    raw = os.environ.get("CHANGED_FILES", "")
    return [line.strip() for line in raw.splitlines() if line.strip()]


def parse_selected_targets() -> list[str]:
    raw = os.environ.get("SELECTED_TARGETS", "")
    selected: list[str] = []
    for chunk in raw.replace("\n", ",").split(","):
        target = chunk.strip()
        if target:
            selected.append(target)
    return selected


def is_global_change(path: str) -> bool:
    for prefix in GLOBAL_CHANGE_PREFIXES:
        if prefix.endswith("/"):
            if path.startswith(prefix):
                return True
            continue
        if path == prefix or path.startswith(prefix + "/"):
            return True
    return False


def resolve_selected(catalog: list[dict], targets: Iterable[str]) -> list[dict]:
    requested = list(targets)
    known_targets = {item["target"] for item in catalog}
    unknown = [target for target in requested if target not in known_targets]
    if unknown:
        raise ValueError(f"unknown selected target(s): {', '.join(sorted(unknown))}")
    requested_set = set(requested)
    return [item for item in catalog if item["target"] in requested_set]


def resolve_changed(catalog: list[dict], changed_files: list[str]) -> tuple[list[dict], str]:
    if not changed_files:
        return [], "no-changes"

    if any(is_global_change(path) for path in changed_files):
        return catalog, "global-change"

    selected_targets: list[str] = []
    for item in catalog:
        target_path = item["path"].rstrip("/")
        target_prefix = target_path + "/"
        if any(path == target_path or path.startswith(target_prefix) for path in changed_files):
            selected_targets.append(item["target"])

    if not selected_targets:
        return [], "no-target-changes"

    selected_set = set(selected_targets)
    return [item for item in catalog if item["target"] in selected_set], "target-changes"


def write_output(name: str, value: str) -> None:
    output_path = os.environ.get("GITHUB_OUTPUT")
    if not output_path:
        raise ValueError("GITHUB_OUTPUT is required")
    with open(output_path, "a", encoding="utf-8") as handle:
        handle.write(f"{name}={value}\n")


def main() -> int:
    catalog = parse_catalog()
    scope_mode = os.environ.get("SCOPE_MODE", "changed").strip() or "changed"
    selected_targets = parse_selected_targets()
    changed_files = parse_changed_files()

    if scope_mode == "all":
        resolved = catalog
        scope_reason = "manual-all"
    elif scope_mode == "selected":
        if not selected_targets:
            raise ValueError("SELECTED_TARGETS is required when SCOPE_MODE=selected")
        resolved = resolve_selected(catalog, selected_targets)
        scope_reason = "manual-selected"
    elif scope_mode == "changed":
        resolved, scope_reason = resolve_changed(catalog, changed_files)
    else:
        raise ValueError(f"unsupported scope mode: {scope_mode}")

    target_names = [item["target"] for item in resolved]
    matrix = {"include": resolved}

    write_output("matrix", json.dumps(matrix, separators=(",", ":")))
    write_output("has_targets", "true" if resolved else "false")
    write_output("target_names", ",".join(target_names))
    write_output("scope_mode", scope_mode)
    write_output("scope_reason", scope_reason)

    print(f"Resolved scope mode: {scope_mode}")
    print(f"Resolved scope reason: {scope_reason}")
    print(f"Resolved targets: {', '.join(target_names) if target_names else '<none>'}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # pragma: no cover - workflow helper error path
        print(f"resolve_dev_cd_scope.py: {exc}", file=sys.stderr)
        raise SystemExit(1)

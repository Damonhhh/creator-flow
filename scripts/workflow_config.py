"""Shared local JSON configuration helpers for the public workflow."""

from __future__ import annotations

import json
import os
from collections.abc import Sequence
from pathlib import Path
from typing import Any


def _require_dotted_key(config: dict[str, Any], dotted_key: str) -> None:
    cursor: Any = config
    for part in dotted_key.split("."):
        if not isinstance(cursor, dict) or part not in cursor:
            raise ValueError(f"Missing required config key: {dotted_key}")
        cursor = cursor[part]


def load_workflow_config(
    repo_root: Path,
    name: str,
    explicit_path: Path | None = None,
    required_keys: Sequence[str] = (),
) -> dict[str, Any]:
    """Load an explicit config or config/<name>.local.json without using examples."""

    root = Path(repo_root).resolve()
    config_path = (
        Path(explicit_path).expanduser()
        if explicit_path is not None
        else root / "config" / f"{name}.local.json"
    )
    if not config_path.is_absolute():
        config_path = root / config_path
    config_path = config_path.resolve()
    if not config_path.is_file():
        example = root / "config" / f"{name}.example.json"
        raise FileNotFoundError(
            f"Missing local config '{name}'. Copy and edit: {example}"
        )
    try:
        parsed = json.loads(config_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ValueError(f"Invalid JSON in local config '{name}': {config_path}") from exc
    if not isinstance(parsed, dict):
        raise ValueError(f"Local config '{name}' must contain a JSON object")
    for dotted_key in required_keys:
        if dotted_key:
            _require_dotted_key(parsed, dotted_key)
    return parsed


def resolve_config_path(repo_root: Path, value: str | None) -> Path | None:
    """Resolve environment variables and a path relative to the repository root."""

    if value is None or not value.strip():
        return None
    path = Path(os.path.expandvars(value)).expanduser()
    return path.resolve() if path.is_absolute() else (Path(repo_root) / path).resolve()

"""Small dependency-free path resolvers shared by optional media adapters."""

from __future__ import annotations

import os
from pathlib import Path


def _expand_path(value: str) -> Path:
    return Path(os.path.expandvars(value)).expanduser().resolve()


def resolve_required_directory(
    cli_value: str | None,
    environment_variable: str,
    label: str,
) -> Path:
    """Resolve CLI before environment and require an existing directory."""

    raw = cli_value.strip() if cli_value and cli_value.strip() else os.getenv(environment_variable, "").strip()
    if not raw:
        raise ValueError(
            f"Missing {label}. Pass the CLI option or set {environment_variable}."
        )
    path = _expand_path(raw)
    if not path.is_dir():
        raise FileNotFoundError(f"{label} directory does not exist: {path}")
    return path


def resolve_cache_directory(
    cli_value: str | None,
    environment_variable: str,
    platform_default: Path,
) -> Path:
    """Resolve CLI before environment and then use a platform-local default."""

    raw = cli_value.strip() if cli_value and cli_value.strip() else os.getenv(environment_variable, "").strip()
    return _expand_path(raw) if raw else Path(platform_default).expanduser().resolve()

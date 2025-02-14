from __future__ import annotations

from dataclasses import dataclass
from importlib import resources
from pathlib import Path

import tomllib

from nmgr.log import logger


@dataclass
class Config:
    base_dir: Path
    ignore_dirs: list[str]
    infra_jobs: list[str]
    job_configs: list[str]
    filters: dict[str, dict]

    @classmethod
    def from_toml(cls, config_path: Path) -> Config:
        if not config_path.exists():
            cls.create_default(config_path)

        try:
            with config_path.open("rb") as f:
                data = tomllib.load(f)
        except tomllib.TOMLDecodeError as e:
            raise RuntimeError(f"Invalid TOML syntax: {e}")

        cfg = data.get("general", {})
        return cls(
            base_dir=Path(cfg.get("base_dir", "")).expanduser(),
            ignore_dirs=cfg.get("ignore_dirs", []),
            infra_jobs=cfg.get("infra_jobs", []),
            job_configs=cfg.get("job_configs", []),
            filters=data.get("filter", {}),
        )

    @staticmethod
    def create_default(config_path: Path) -> None:
        with resources.path("nmgr.data", "config.toml") as template:
            config = Path(template).read_text(encoding="utf-8")

        config_path.parent.mkdir(parents=True, exist_ok=True)
        config_path.write_text(config, encoding="utf-8")
        logger.info(f"Generated default config at {config_path}")

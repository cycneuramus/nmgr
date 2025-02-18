from __future__ import annotations

import re
from collections.abc import Iterable
from dataclasses import dataclass
from functools import cached_property
from pathlib import Path

from nmgr.config import Config
from nmgr.log import logger


@dataclass
class NomadJob:
    name: str
    spec_path: Path
    config_paths: list[Path]

    @cached_property
    def spec(self) -> str:
        return self.spec_path.read_text()

    @property
    def configs(self) -> Iterable[str]:
        for path in self.config_paths:
            try:
                yield path.read_text()
            except Exception as e:
                logger.warning(f"Error reading {path}: {str(e)}")


class JobRegistrar:
    """Locates and registers Nomad job specs and accompanying config files"""

    def __init__(self, config: Config) -> None:
        self.config = config

    def find_jobs(self) -> list[NomadJob]:
        jobs: list = []
        if not self.config.base_dir.is_dir():
            logger.warning(f"Base directory not found: {self.config.base_dir}")
            return jobs

        for path in self.config.base_dir.iterdir():
            if not path.is_dir() or path.name in self.config.ignore_dirs:
                logger.debug(f"Skipping: {path}")
                continue

            for spec_path in path.glob("*.hcl"):
                try:
                    jobs.append(self._register_job(spec_path))
                except ValueError as e:
                    logger.warning(f"Failed to load {spec_path}: {e}")
        return jobs

    def _register_job(self, spec_path: Path) -> NomadJob:
        return NomadJob(
            name=self._extract_job_name(spec_path),
            spec_path=spec_path,
            config_paths=self._find_configs(spec_path.parent),
        )

    def _find_configs(self, job_dir: Path) -> list[Path]:
        configs: list = []
        for pattern in self.config.job_configs:
            configs.extend(job_dir.glob(pattern))
        return [config for config in configs if config.is_file()]

    @staticmethod
    def _extract_job_name(spec_path: Path) -> str:
        """Scans for 'job "foo"' in the spec to extract the job name"""
        with spec_path.open() as f:
            for line in f:
                match = re.search(r'job\s+"([^"]+)"', line)
                if match:
                    return match.group(1)
        raise ValueError("Missing job name in spec")

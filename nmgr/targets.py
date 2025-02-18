from __future__ import annotations

from abc import ABC, abstractmethod

from nmgr.config import Config
from nmgr.jobs import NomadJob
from nmgr.log import logger


class Target(ABC):
    """Abstract base class for filtering Nomad jobs by user-requested target"""

    _registry: dict[str, type[Target]] = {}

    @classmethod
    def register(cls, target: str):
        def decorator(subcls: type[Target]) -> type[Target]:
            cls._registry[target] = subcls
            return subcls

        return decorator

    @classmethod
    def get(cls, target: str, config: Config) -> Target:
        # 1) Built-in target?
        if target in cls._registry:
            logger.debug(f"Target '{target}' matches built-in filter")
            return cls._registry[target]()

        # 2) Config-defined target?
        if target in config.filters:
            logger.debug(f"Target '{target}' matches config-defined filter")
            filter_cfg = config.filters[target]
            return ContentTarget(
                keywords=filter_cfg.get("keywords", []),
                extended_search=filter_cfg.get("extended_search", False),
                exclude_infra=filter_cfg.get("exclude_infra", True),
            )

        # 3) Fallback: assume target is a job name
        logger.debug(f"Target '{target}' not found, treating as job name")
        return NameTarget(target)

    @abstractmethod
    def filter(self, jobs: list[NomadJob], config: Config) -> list[NomadJob]:
        pass


@Target.register("infra")
class InfraTarget(Target):
    """Returns infrastructure jobs, respecting their order in config"""

    def filter(self, jobs: list[NomadJob], config: Config) -> list[NomadJob]:
        ordered = []
        for infra_name in config.infra_jobs:
            for job in jobs:
                if job.name == infra_name:
                    ordered.append(job)
        return ordered


@Target.register("services")
class ServicesTarget(Target):
    """Returns service (i.e. non-infrastructure) jobs"""

    def filter(self, jobs: list[NomadJob], config: Config) -> list[NomadJob]:
        return [job for job in jobs if job.name not in config.infra_jobs]


@Target.register("all")
class AllTarget(Target):
    """Returns both infra and service jobs, always ordering infra jobs first"""

    def filter(self, jobs: list[NomadJob], config: Config) -> list[NomadJob]:
        infra = InfraTarget().filter(jobs, config)
        services = ServicesTarget().filter(jobs, config)
        return infra + services


class NameTarget(Target):
    """Fallback target that returns a single specific job by name"""

    def __init__(self, name: str) -> None:
        self.name = name

    def filter(self, jobs: list[NomadJob], config: Config) -> list[NomadJob]:
        return [job for job in jobs if job.name == self.name]


class ContentTarget(Target):
    """Parametric target for searching job specs and/or configs."""

    def __init__(
        self,
        keywords: list[str],
        extended_search: bool = False,
        exclude_infra: bool = True,
    ) -> None:
        self.keywords = keywords
        self.extended_search = extended_search
        self.exclude_infra = exclude_infra

    def filter(self, jobs: list[NomadJob], config: Config) -> list[NomadJob]:
        matched = []
        for job in jobs:
            sources = [job.spec]
            if self.extended_search:
                sources.extend(job.configs)

            for text in sources:
                if any(keyword in text for keyword in self.keywords):
                    if self.exclude_infra and job.name in config.infra_jobs:
                        continue
                    matched.append(job)
                    break  # one match is sufficient
        return matched

from __future__ import annotations

from abc import ABC, abstractmethod

from nmgr.config import Config
from nmgr.jobs import NomadJob
from nmgr.log import logger


class Filter(ABC):
    """Abstract base class for filtering Nomad jobs by user-requested target"""

    _registry: dict[str, type[Filter]] = {}

    @classmethod
    def register(cls, target: str):
        def decorator(subcls: type[Filter]) -> type[Filter]:
            cls._registry[target] = subcls
            return subcls

        return decorator

    @classmethod
    def get(cls, target: str, config: Config) -> Filter:
        # 1) Built-in filter?
        if target in cls._registry:
            logger.debug(f"Target '{target}' matches built-in filter")
            return cls._registry[target]()

        # 2) Config-defined filter?
        if target in config.filters:
            logger.debug(f"Target '{target}' matches config-defined filter")
            filter_cfg = config.filters[target]
            return ContentFilter(
                keywords=filter_cfg.get("keywords", []),
                extended_search=filter_cfg.get("extended_search", False),
                exclude_infra=filter_cfg.get("exclude_infra", True),
            )

        # 3) Fallback: assume target is a job name
        logger.debug(f"Target '{target}' not matching any filter, treating as job name")
        return NameFilter(target)

    @abstractmethod
    def filter(self, jobs: list[NomadJob], config: Config) -> list[NomadJob]:
        pass


@Filter.register("infra")
class InfraFilter(Filter):
    """Returns infrastructure jobs, respecting their order in config"""

    def filter(self, jobs: list[NomadJob], config: Config) -> list[NomadJob]:
        ordered = []
        for infra_name in config.infra_jobs:
            for job in jobs:
                if job.name == infra_name:
                    ordered.append(job)
        return ordered


@Filter.register("services")
class ServicesFilter(Filter):
    """Returns service (i.e. non-infrastructure) jobs"""

    def filter(self, jobs: list[NomadJob], config: Config) -> list[NomadJob]:
        return [job for job in jobs if job.name not in config.infra_jobs]


@Filter.register("all")
class AllFilter(Filter):
    """Returns both infra and service jobs, always ordering infra jobs first"""

    def filter(self, jobs: list[NomadJob], config: Config) -> list[NomadJob]:
        infra = InfraFilter().filter(jobs, config)
        services = ServicesFilter().filter(jobs, config)
        return infra + services


class NameFilter(Filter):
    """Fallback filter that returns a single specific job by name"""

    def __init__(self, name: str):
        self.name = name

    def filter(self, jobs: list[NomadJob], config: Config) -> list[NomadJob]:
        return [job for job in jobs if job.name == self.name]


class ContentFilter(Filter):
    """Parametric filter for searching job specs and/or configs."""

    def __init__(
        self,
        keywords: list[str],
        extended_search: bool = False,
        exclude_infra: bool = True,
    ):
        self.keywords = keywords
        self.extended_search = extended_search
        self.exclude_infra = exclude_infra

    def filter(self, jobs: list[NomadJob], config: Config) -> list[NomadJob]:
        matched = []
        for job in jobs:
            text = job.spec + job.configs if self.extended_search else job.spec
            if any(keyword in text for keyword in self.keywords):
                if self.exclude_infra and job.name in config.infra_jobs:
                    continue
                matched.append(job)
        return matched

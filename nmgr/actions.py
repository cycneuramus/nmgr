from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Callable

from nmgr.config import Config
from nmgr.jobs import NomadJob
from nmgr.log import logger
from nmgr.nomad import NomadClient


class Action(ABC):
    """Abstract base class for handling user-requested actions on Nomad jobs"""

    _registry: dict[str, type[Action]] = {}

    def __init__(self, nomad: NomadClient, config: Config) -> None:
        self.nomad = nomad
        self.config = config

    @classmethod
    def register(cls, action: str) -> Callable[[type[Action]], type[Action]]:
        """Decorator to register a subclass as handling a specific action"""

        def decorator(subcls: type[Action]) -> type[Action]:
            cls._registry[action] = subcls
            return subcls

        return decorator

    @classmethod
    def get(cls, action: str, nomad: NomadClient, config: Config) -> Action:
        """Construct an Action instance registred to handle action_name"""

        try:
            handler_cls = cls._registry[action]
        except KeyError:
            raise ValueError(f"Unknown action: {action}")
        return handler_cls(nomad, config)

    @abstractmethod
    def handle(self, jobs: list[NomadJob]) -> None:
        pass


@Action.register("up")
class UpAction(Action):
    """Runs job if not running or spec has changed"""

    def handle(self, jobs: list[NomadJob]) -> None:
        for job in jobs:
            if self.nomad.is_running(job.name):
                logger.debug(f"Job {job.name} is already running; skipping")
                continue

            logger.debug(f"Bringing job UP: {job.name}")
            self.nomad.run_job(job)


@Action.register("down")
class DownAction(Action):
    """Stops job if running"""

    def handle(self, jobs: list[NomadJob]) -> None:
        for job in jobs:
            if not self.nomad.is_running(job.name):
                logger.debug(f"Job {job.name} is not running; skipping")
                continue

            logger.debug(f"Bringing job DOWN: {job.name}")
            self.nomad.stop_job(job.name)


@Action.register("list")
@Action.register("find")
class ListAction(Action):
    """Lists jobs"""

    def handle(self, jobs: list[NomadJob]) -> None:
        for job in jobs:
            print(job.name)


@Action.register("image")
class ImageAction(Action):
    """Prints container image information for job"""

    def handle(self, jobs: list[NomadJob]) -> None:
        for job in jobs:
            live = self.nomad.get_live_image(job.name)
            spec = self.nomad.get_spec_image(job.spec)
            print(f"Live images:\n{live}\n\nSpec images:\n{spec}")


@Action.register("logs")
class LogsAction(Action):
    """Tails the logs for a given task in a job"""

    def handle(self, jobs: list[NomadJob]) -> None:
        if len(jobs) > 1:
            logger.error("Logs cannot be shown for more than one job at a time")
            return

        job = jobs[0]
        tasks = self.nomad._extract_tasks(job.name)

        if len(tasks) == 1:
            # Auto-select the only task
            task = tasks[0]
        else:
            print(f"Tasks for job {job.name}:")
            for i, opt in enumerate(tasks, start=1):
                print(f"{i}. {opt}")

            while True:
                choice = input("\nSelect a task (number): ").strip()
                if choice.isdigit() and 1 <= int(choice) <= len(tasks):
                    task = tasks[int(choice) - 1]
                    break
                print("Invalid input; please enter a valid number")

        self.nomad.tail_logs(task_name=task, job_name=job.name)


@Action.register("reconcile")
class ReconcileAction(Action):
    """Restarts job if its live image differs from spec image"""

    def handle(self, jobs: list[NomadJob]) -> None:
        for job in jobs:
            if not self.nomad.is_running(job.name):
                logger.debug(f"Job {job.name} is not running; skipping")
                continue

            live_image = self.nomad.get_live_image(job.name)
            spec_image = self.nomad.get_spec_image(job.spec)

            logger.debug(f"Live images:\n{live_image}")
            logger.debug(f"Spec images:\n{spec_image}")

            if live_image == spec_image:
                logger.debug(f"No changes for {job.name}; skipping")
                continue

            # Skip (likely critical) infrastructure jobs by default
            if job.name in self.config.infra_jobs:
                logger.info(f"Skipping infra job: {job.name}")
                continue

            logger.info(f"Reconciling job {job.name}: image changed. Restarting...")
            self.nomad.run_job(job)

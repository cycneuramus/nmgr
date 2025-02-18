from __future__ import annotations

import re
import subprocess
from typing import Optional

from nmgr.config import Config
from nmgr.jobs import NomadJob
from nmgr.log import logger


class NomadClient:
    """Wraps interactions with the Nomad CLI"""

    def __init__(
        self, config: Config, dry_run: bool = False, detach: bool = False
    ) -> None:
        self.config = config
        self.dry_run = dry_run
        self.detach = detach

    def run_job(self, job: NomadJob) -> None:
        cmd = ["nomad", "run"]
        # Skip detach on infra jobs to let Nomad declare them healthy before proceeding
        if self.detach and job.name not in self.config.infra_jobs:
            cmd.append("-detach")
        cmd.append(job.spec_path.name)

        self._execute(cmd, cwd=str(job.spec_path.parent))
        logger.debug(f"Started job: {job.name}")

    def stop_job(self, job_name: str) -> None:
        self._execute(["nomad", "stop", "-purge", job_name])
        logger.debug(f"Stopped job: {job_name}")

    def is_running(self, job_name: str) -> bool:
        result = self._execute(
            ["nomad", "job", "status", "-short", job_name],
            check=False,
            capture_output=True,
        )
        # Check whether line containing "Status" ends with "running"
        status_line = [line for line in result.stdout.splitlines() if "Status" in line]
        if not status_line:
            return False
        return status_line[0].split()[-1].lower() == "running"

    def tail_logs(self, task_name: str, job_name: str) -> None:
        self._execute(["nomad", "logs", "-f", "-task", task_name, "-job", job_name])

    def inspect_job(self, job_name: str) -> str:
        try:
            result = self._execute(
                ["nomad", "job", "inspect", "-hcl", job_name], capture_output=True
            )
            return result.stdout
        except subprocess.CalledProcessError as e:
            logger.error(f"Error inspecting job {job_name}: {e.stderr}")
            return ""

    def get_live_image(self, job_name: str) -> str:
        live_spec = self.inspect_job(job_name)
        return self._extract_images(live_spec)

    def get_spec_image(self, spec: str) -> str:
        return self._extract_images(spec)

    def _extract_tasks(self, job_name: str) -> list[str]:
        live_spec = self.inspect_job(job_name)
        matches = re.findall(r'task\s+"([^"]+)"', live_spec)
        if matches:
            return matches
        logger.warning(f"No tasks found for job: {job_name}")
        return []

    @staticmethod
    def _extract_images(spec: str) -> str:
        """
        Scans for lines such as:
            image = "foo/bar"

        or blocks such as:
            image = {
                kutt = "docker.io/kutt/kutt:v3.2.2"
                valkey = "docker.io/valkey/valkey:8.0-alpine"
            }
        """

        pattern = re.compile(r'image\s*=\s*(".*?"|\{[^}]*\})', re.DOTALL)
        matches = pattern.findall(spec)
        results = []

        for match in matches:
            if "local." in match:
                # skip HCL variable references (e.g. "image = local.foo")
                continue

            match = match.strip()
            if match.startswith("{") and match.endswith("}"):
                # content of the block
                content = match[1:-1].strip()
                for line in content.splitlines():
                    line = line.strip()
                    if line:
                        results.append(line)
            else:
                results.append(match)

        return "\n".join(results)

    def _execute(
        self,
        cmd: list[str],
        cwd: Optional[str] = None,
        check: bool = True,
        capture_output: bool = False,
    ) -> subprocess.CompletedProcess[str]:
        cmd_str = " ".join(cmd)
        logger.debug(f"Executing command: {cmd_str}" + (f" (cwd={cwd})" if cwd else ""))

        # For commands that modify state, honor dry_run
        if self.dry_run and not capture_output:
            logger.info("[DRY RUN] %s", " ".join(cmd))
            return subprocess.CompletedProcess(cmd, returncode=0, stdout="", stderr="")

        try:
            return subprocess.run(
                cmd, check=check, text=True, cwd=cwd, capture_output=capture_output
            )
        except subprocess.CalledProcessError as e:
            logger.error(f"Command failed: {cmd_str}\nError: {e.stderr}")
            raise

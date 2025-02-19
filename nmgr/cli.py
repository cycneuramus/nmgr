from __future__ import annotations

import argparse
import logging
import os
from importlib import metadata, resources
from pathlib import Path

from nmgr.actions import Action
from nmgr.config import Config
from nmgr.jobs import JobRegistrar
from nmgr.log import logger
from nmgr.nomad import NomadClient
from nmgr.targets import ContentTarget, Target


def create_parser(actions: list[str], targets: list[str]) -> argparse.ArgumentParser:
    config_dir = os.getenv("XDG_CONFIG_HOME") or str(Path.home() / ".config")
    default_config_path = Path(config_dir) / "nmgr" / "config.toml"

    parser = argparse.ArgumentParser(
        description="Nomad job manager",
        usage="%(prog)s [options] [action] [target]",
    )
    parser.add_argument(
        "action",
        nargs="?",
        help=f"{', '.join(actions)}",
    )
    parser.add_argument(
        "target",
        nargs="?",
        help=f'{", ".join(targets)}, a custom filter, a specific job name, or a string (for "find")',
    )
    parser.add_argument(
        "-c",
        "--config",
        default=default_config_path,
        type=Path,
        help=f"path to config file (default: {default_config_path})",
    )
    parser.add_argument("-n", "--dry-run", action="store_true", help="dry-run mode")
    parser.add_argument(
        "-d", "--detach", action="store_true", help="start jobs in detached mode"
    )
    parser.add_argument("-v", "--verbose", action="store_true", help="verbose output")
    parser.add_argument(
        "--completion",
        action="store_true",
        help="install autocompletion for Bash and exit",
    )
    parser.add_argument(
        "--version",
        action="version",
        version=f"%(prog)s {metadata.version('nmgr')}",
    )

    # Hidden flags for bash-completion logic
    parser.add_argument("--list-actions", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--list-targets", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--list-options", action="store_true", help=argparse.SUPPRESS)

    return parser


def generate_completion() -> None:
    data_dir = os.getenv("XDG_DATA_HOME") or str(Path.home() / ".local" / "share")
    script_path = Path(data_dir) / "bash-completion" / "completions" / "nmgr"

    script_path.parent.mkdir(parents=True, exist_ok=True)
    with resources.path("nmgr.data", "completion.bash") as template:
        script = Path(template).read_text(encoding="utf-8")

    if script_path.exists():
        existing_content = script_path.read_text(encoding="utf-8")
        if existing_content.strip() == script.strip():
            print(f"Completion script is already up-to-date at {script_path}")
            return
        else:
            print(f"Updating completion script at {script_path}")

    script_path.write_text(script, encoding="utf-8")
    script_path.chmod(0o755)
    logger.info(f"Bash completion script installed at {script_path}")


def load_config(args: argparse.Namespace) -> Config:
    try:
        config = Config.from_toml(args.config)
    except Exception as e:
        logger.error(f"Failed to load config: {e}")
        raise
    return config


def run() -> None:
    actions = list(Action._registry.keys())
    targets = list(Target._registry.keys())

    parser = create_parser(actions, targets)
    args = parser.parse_args()

    if args.list_actions:
        print("\n".join(actions))
        return

    if args.list_targets:
        config = load_config(args)
        custom_targets = list(config.filters.keys())
        all_targets = targets + custom_targets
        print("\n".join(all_targets))
        return

    if args.list_options:
        all_options: list = []
        for action in parser._actions:
            all_options.extend(action.option_strings)
        print("\n".join(sorted(set(all_options))))
        return

    if args.completion:
        generate_completion()

    if args.verbose:
        logger.setLevel(logging.DEBUG)

    config = load_config(args)

    nomad = NomadClient(config, args.dry_run, args.detach)
    registrar = JobRegistrar(config)
    all_jobs = registrar.find_jobs()
    if not all_jobs:
        logger.warning("No jobs found")
        return

    if args.action == "find":
        # 'find' action: interpret target as a substring to search in job specs only
        target = ContentTarget(
            keywords=[args.target],
            extended_search=False,
            exclude_infra=False,
        )
    else:
        target = Target.get(args.target, config)

    jobs = target.filter(all_jobs, config)
    if not jobs:
        logger.warning(f"No jobs found matching target: {args.target}")
        return

    try:
        action = Action.get(args.action, nomad, config)
    except ValueError as e:
        logger.error(e)
        return

    try:
        action.handle(jobs)
    except KeyboardInterrupt:
        logger.info("Interrupted")
        exit(0)
    except Exception as e:
        logger.error(f"Operation failed: {e}")
        exit(1)

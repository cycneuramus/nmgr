## Overview

This is a utility program for managing jobs in a Nomad cluster according to certain specific needs and preferences of mine.

It started as a set of Bash convenience functions which slowly but surely began to evolve into an [unmaintainable monstrosity](). This Python rewrite, consequently, represents a more or less desperate attempt to tame the beast—or perhaps more accurately, a way of trading one set of complexities for another that nevertheless feels a bit more structured. In any case, it's fun sometimes to seek out a dubious break from the purity of UNIX pipes to get tangled up in OOP for a bit instead. Misery needs variety if it is to be enjoyable.

If it's not clear by now, this program should not be used without understanding what it does and why it does it.

## Usage

```
usage: nmgr [-h] [--base-dir BASE_DIR] [--ignore-dirs [IGNORE_DIRS ...]] [--infra-services [INFRA_SERVICES ...]] [-n]
            [-d] [-v]
            {up,down,reconcile} target

Nomad cluster manager

positional arguments:
  {up,down,reconcile}   Action to perform
  target                Target to operate on. Can be: infra, services, all, db, nas, jfs, crypt, or a specific job/service name

options:
  -h, --help            Show this help message and exit
  --base-dir BASE_DIR   Base directory for Nomad jobs
  --ignore-dirs [IGNORE_DIRS ...]
                        Directories to ignore when discovering Nomad jobs
  --infra-services [INFRA_SERVICES ...]
                        Critical infrastructure services to treat more carefully
  -n, --dry-run         Dry-run mode
  -d, --detach          Start jobs in detached mode
  -v, --verbose         Verbose output
```

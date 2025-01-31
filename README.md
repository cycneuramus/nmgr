## Overview

`nmgr` is a utility program for managing jobs in a Nomad cluster according to certain specific needs and preferences of mine. The type of jobs it is designed to operate on can be gleaned from my [homelab repository](https://github.com/cycneuramus/homelab).

It started as a set of Bash convenience functions which, in time, slowly but surely [threatened](https://github.com/cycneuramus/nmgr/blob/bash-legacy/nmgr) to evolve into an unmaintainable monstrosity. This Python rewrite, consequently, represents a more or less desperate attempt to tame the beast before it would be too late—or perhaps more accurately, a way of trading one set of complexities for another that nevertheless feels a bit more structured and robustly extensible. In any case, it's fun sometimes to seek out a dubious break from the purity of UNIX pipes to get tangled up in some overengineered OOP for a bit instead. Misery needs variety if it is to be enjoyable.

If it's not clear by now, this program should probably not be used without understanding what it does and why it does it.

## Rationale

Consider the following use-cases:

+ You're about to perform a server upgrade that requires a restart. Instead of manually coddling every one of those 50+ running jobs first, it sure would be handy to be able to do this:

    ```
    nmgr all down
    sudo apt update && sudo apt upgrade
    sudo reboot now

    [...]

    nmgr all up
    ```

+ You're using something like [Renovate](https://renovatebot.com) to manage updates to container image versions. Now one fine day, a whole bunch of these comes in as a PR, so you merge, pull locally—and then what? Do you manually hunt down all the jobs needing to be updated and restart them one by one? Well, now you can do this instead:

    `nmgr reconcile all`

    Or, if you still would like to preserve some manual control:

    `nmgr reconcile my-specific-job`

+ You're about to upgrade or otherwise change, say, a database job on which, however, a host of other jobs depend. Do you now wade through each and every job specification to remind yourself which jobs you would need to stop before making your change? Instead, you could do this:

    `nmgr db down`

    And then, after you have made the change:

    `nmgr db up`

    You could do the same thing for jobs that depend on e.g. a NAS (`nmgr nas {up,down}`), a JuiceFS mount (`nmgr jfs {up,down}`), and so forth.

The crux here, of course, is that you would most likely have to dive into the source code to make sure the filtering criteria for these types of jobs match your environment. A good way to start hunting for clues would be to inspect the [`Target`](https://github.com/cycneuramus/nmgr/blob/316207a4b83711c140798f173981dbaf9a73e1f2/nmgr#L213-L234) class.

## Usage

```
usage: nmgr [-h] [--base-dir BASE_DIR] [--ignore-dirs [IGNORE_DIRS ...]] [--infra-jobs [INFRA_JOBS ...]] [-n] [-d] [-v] action target

Nomad job manager

positional arguments:
  action                Action to perform: up, down, reconcile
  target                Target to operate on: infra, services, all, db, nas, jfs, crypt, or a specific job name

options:
  -h, --help            show this help message and exit
  --base-dir BASE_DIR   Base directory for discovering Nomad jobs (default: /home/<user>/cld)
  --ignore-dirs [IGNORE_DIRS ...]
                        Directories to ignore when discovering Nomad jobs (default: ['_archive', '.github', '.git'])
  --infra-jobs [INFRA_JOBS ...]
                        Critical infrastructure jobs to handle with care (default: ['garage', 'keydb', 'haproxy', 'caddy', 'patroni'])
  -n, --dry-run         Dry-run mode (default: False)
  -d, --detach          Start jobs in detached mode (default: False)
  -v, --verbose         Verbose output (default: False)
```

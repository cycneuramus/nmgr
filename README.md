## Overview

`nmgr` is a utility program for managing jobs in a Nomad cluster according to certain specific needs and preferences of mine. The type of jobs it is designed to operate on can be gleaned from my [homelab repository](https://github.com/cycneuramus/homelab).

It started as a set of Bash convenience functions which slowly but surely began to evolve into an [unmaintainable monstrosity](https://github.com/cycneuramus/nmgr/blob/bash-legacy/nmgr). This Python rewrite, consequently, represents a more or less desperate attempt to tame the beast before it would be too late—or perhaps more accurately, a way of trading one set of complexities for another that nevertheless feels a bit more structured and robustly extensible. In any case, it's fun sometimes to seek out a dubious break from the purity of UNIX pipes to get tangled up in some overengineered OOP for a bit instead. Misery needs variety if it is to be enjoyable.

If it's not clear by now, this program should not be used without understanding what it does and why it does it.

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

+ You're about to upgrade or otherwise change, say, a database job on which, however, a host of other jobs depend. Do you now wade through each and every job specification to remind yourself of which jobs you would need to stop before performing the update? Instead, you could do this:

    `nmgr db down`

    And then, after you have made the change:

    `nmgr db up`

    You could do the same thing for jobs that depend on e.g. a NAS (`nmgr nas {up,down}`), a JuiceFS mount (`nmgr jfs {up,down}`), and so forth.

The crux here, of course, is that you would most likely have to dive into the source code to make sure the filtering criteria for these types of jobs match your environment. Make sure to inspect the [`target_config`](https://github.com/cycneuramus/nmgr/blob/95fb63295ddf088c0564c9e27e83d3c3a0effe84/nmgr#L53-L58) dict and the [`_filter_by_target_type`](https://github.com/cycneuramus/nmgr/blob/ca44a5029969dfa9a56eb84f1ffcc1fe826f02fb/nmgr#L137-L175) method for some clues.

## Usage

```
usage: nmgr [-h] [--base-dir BASE_DIR] [--ignore-dirs [IGNORE_DIRS ...]] [--infra-services [INFRA_SERVICES ...]] [-n] [-d] [-v] {up,down,reconcile} target

Nomad job manager

positional arguments:
  {up,down,reconcile}   Action to perform
  target                Target to operate on. Can be: infra, services, all, db, nas, jfs, crypt, or a specific job name

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

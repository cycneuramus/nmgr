## Overview

`nmgr` is a utility program for managing jobs in a Nomad cluster according to certain specific needs and preferences of mine. The type of jobs it is designed to operate on can be gleaned from my [homelab repository](https://github.com/cycneuramus/homelab).

It started as a set of Bash convenience functions which, in time, slowly but surely [threatened](https://github.com/cycneuramus/nmgr/blob/bash-legacy/nmgr) to evolve into an unmaintainable monstrosity. This Python rewrite, consequently, represents a more or less desperate attempt to tame the beast before it would be too late—or perhaps more accurately, a way of trading one set of complexities for another that nevertheless feels a bit more structured and robustly extensible. In any case, it's fun sometimes to seek out a dubious break from the purity of UNIX pipes to get tangled up in some overengineered OOP for a bit instead. Misery needs variety if it is to be enjoyable.

If it's not clear by now, this program should probably not be used without understanding what it does and why it does it.

## Rationale

Consider the following use-cases:

+ You're using something like [Renovate](https://renovatebot.com) to manage updates to container image versions. Now one fine day, a whole bunch of these comes in as a PR, so you merge, pull locally—and then what? Do you manually hunt down all the jobs needing to be updated and restart them one by one? Well, now you can do this instead:

    `nmgr reconcile all`

    Or, if you still would like to preserve some manual control:

    `nmgr reconcile my-specific-job`

    Also, just for fun, you might first want to compare a job's currently running images against those in its specification:

    ```
    $ nmgr image nextcloud
    Live images:
    nextcloud = "docker.io/nextcloud:30.0.4-apache"
    collabora = "docker.io/collabora/code:24.04.12.2.1"
    valkey    = "docker.io/valkey/valkey:7.2-alpine"

    Spec images:
    nextcloud = "docker.io/nextcloud:30.0.5-apache"
    collabora = "docker.io/collabora/code:24.04.12.1.1"
    valkey    = "docker.io/valkey/valkey:8.0-alpine"
    ```

---

+ You're about to perform a server upgrade that requires a restart. Instead of manually coddling every one of those 50+ running jobs first, it sure would be handy to be able to do this:

    ```
    nmgr down all
    sudo apt update && sudo apt upgrade
    sudo reboot now

    [...]

    nmgr up all
    ```

---

+ At random parts of the day, your heart will sink when you suddenly remember you probably still have some jobs running with a `latest` image tag. After some time, you have had enough of these crises of conscience, so you roll up your sleeves, `ssh` into the server, and–what's that? You were going to hunt down all those image specifications *manually*? Don't be silly:

    `nmgr find :latest`

---

+ You're about to upgrade or otherwise mess with, say, a NAS on which a host of currently running jobs depend. Do you now wade through each and every job specification to remind yourself which jobs you would need to stop before making your changes? Instead, you could do this:

    `nmgr down nas`

    And then, after you're done messing with the NAS:

    `nmgr up nas`

    You could do the same thing for jobs that depend on e.g. a database job (`nmgr {up,down} db`), a [JuiceFS](https://juicefs.com) mount (`nmgr {up,down} jfs`), and so forth.

---

+ Before blindly tearing down a bunch of jobs as in the example above, you would like to know exactly which jobs are going to be impacted. Hence, nervous Nellie that you are, you run:

    `nmgr list nas`

    Or, if you could muster up just a bit more courage, you might perform a dry-run:

    `nmgr -n down nas`

---

The crux with these examples, of course, is that you would most likely have to dive into the source code to make sure the filtering criteria for pre-defined job groups such as `nas`, `db`, etc. actually match your environment. A good way to start hunting for clues would be to inspect [`ContentFilter`](https://github.com/cycneuramus/nmgr/blob/c6533760539cacbed3edc9a6a22f810c14a355e7/nmgr#L276-L327) and its subclasses.

## Usage

```
usage: nmgr [-h] [--base-dir BASE_DIR] [--ignore-dirs [IGNORE_DIRS ...]] [--infra-jobs [INFRA_JOBS ...]] [-n] [-d] [-v] action target

Nomad job manager

positional arguments:
  action                up, down, find, list, image, reconcile
  target                infra, services, all, db, nas, jfs, crypt, a specific job name, or a string (for the "find" action)

options:
  -h, --help            show this help message and exit
  --base-dir BASE_DIR   base directory for discovering Nomad jobs (default: /home/<user>/cld)
  --ignore-dirs [IGNORE_DIRS ...]
                        directories to ignore when discovering Nomad jobs (default: ['_archive', '.github', '.git'])
  --infra-jobs [INFRA_JOBS ...]
                        critical infrastructure jobs to handle with care (default: ['garage', 'keydb', 'haproxy', 'caddy', 'patroni'])
  -n, --dry-run         dry-run mode (default: False)
  -d, --detach          start jobs in detached mode (default: False)
  -v, --verbose         verbose output (default: False)
```

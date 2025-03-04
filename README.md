## Overview

`nmgr` is a utility program for managing jobs in a Nomad cluster according to certain specific needs and preferences of mine. For a basic orientation in what it does and why it does it, see [Rationale](https://github.com/cycneuramus/nmgr#rationale). The type of jobs it is designed to operate on can be gleaned from my [homelab repository](https://github.com/cycneuramus/homelab).

It started as a set of Bash convenience functions which, in time, slowly but surely [threatened](https://github.com/cycneuramus/nmgr/blob/bash-legacy/nmgr) to evolve into an unmaintainable monstrosity. This Python rewrite, consequently, represents a more or less desperate attempt to tame the beast before it would be too late—or perhaps more accurately, a way of trading one set of complexities for another that nevertheless feels a bit more structured and robustly extensible. In any case, it's fun sometimes to seek out a dubious break from the purity of UNIX pipes to get tangled up in some overengineered OOP for a bit instead. Misery needs variety if it is to be enjoyable.

## Installation

`nmgr` is packaged on [PyPi](https://pypi.org/project/nmgr) and can be installed using, for example, [`pipx`](https://pipx.pypa.io/stable/):

+ `pipx install nmgr`

## Usage

```
usage: nmgr [options] [action] [target]

Nomad job manager

positional arguments:
  action               up, down, find, list, image, logs, exec, reconcile
  target               infra, services, all, a custom filter, a specific job name, or a string (for "find")

options:
  -h, --help           show this help message and exit
  -c, --config CONFIG  path to config file (default: /home/<user>/.config/nmgr/config.toml)
  -n, --dry-run        dry-run mode
  -d, --detach         start jobs in detached mode
  -p, --purge          purge jobs when stopping
  -v, --verbose        verbose output
  --completion         install autocompletion for Bash and exit
  --version            show program's version number and exit
```
## Rationale

Consider the following use-cases:

+ You're using something like [Renovate](https://renovatebot.com) to manage updates to container image versions. Now one fine day, a whole bunch of these comes in as a PR, so you merge, pull locally—and then what? Do you manually hunt down all the jobs needing to be updated and restart them one by one? Well, now you can do this instead:

    `nmgr reconcile all`

    Or, if you still would like to preserve some manual control:

    `nmgr reconcile my-specific-job`

    Also, just for fun, you might first want to compare a job's currently running images against those in its specification:

    ```
    $ nmgr image forgejo
    Live images:
    forgejo  = "codeberg.org/forgejo/forgejo:9.0.3-rootless"
    valkey   = "docker.io/valkey/valkey:7.2-alpine"

    Spec images:
    forgejo  = "codeberg.org/forgejo/forgejo:10.0.0-rootless"
    valkey   = "docker.io/valkey/valkey:8.0-alpine"
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

+ Nextcloud's PHP spaghetti has decided to crap the bed, and you have no choice but to start tailing the logs. "What's the syntax again? `nomad logs -f -job nextcloud`? Wait, no, that errors out. Oh, that's right: I have to specify a 'task' to get the logs from. But what did I name the Nextcloud job tasks? I better check the job specification..." *No!* Stop right there.

    ```
    $ nmgr logs nextcloud
    Tasks for job nextcloud:
    1. server
    2. cron
    3. redis
    4. push
    5. collabora

    Select a task (number):
    ```

    And off you go.

---

You find yourself wanting to break all the rules of application containers by looking to shell in and execute some command. Now what was it, `nomad alloc exec -job immich`? Apparently not: `Please specify the task`. Ah, right: `nomad alloc -job immich -task server`. What the hell? `Please specify the task` *again*? Perhaps `-task` has to precede `-job`? At this point you might feel like giving up. But fear not!

```
$ nmgr exec immich
Tasks for job immich:
1. server
2. machine-learning
3. redis
Select a task (number): 1
Command to execute in server: ls
bin   get-cpus.sh   package-lock.json  resources  upload
dist  node_modules  package.json       start.sh
```

---

+ At random parts of the day, your heart will sink when you suddenly remember you probably still have some jobs running with a `latest` image tag. After some time, you have had enough of these crises of conscience, so you roll up your sleeves, `ssh` into the server, and–what's that? You were going to go look for all those image specifications manually? Don't be silly:

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

**NOTE**: Some of these examples make use of custom target filters (`nas`, `jfs`, `db`). These can be defined in the [configuration file](https://github.com/cycneuramus/nmgr/blob/master/nmgr/data/config.toml) that will be generated on first run.

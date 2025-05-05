## Overview

`nmgr` is a wrapper tool for [Nomad](https://www.nomadproject.io/) that is meant to provide various quality-of-life improvements when managing jobs in a cluster. For a basic orientation in what it does and why it does it, see [Rationale](https://github.com/cycneuramus/nmgr#rationale). The type of jobs it is designed to operate on can be gleaned from my [homelab repository](https://github.com/cycneuramus/homelab).

### Background

This tool started as a set of Bash convenience functions which, in time, slowly but surely [threatened](https://github.com/cycneuramus/nmgr/blob/bash-legacy/nmgr) to evolve into an unmaintainable monstrosity. Fearing for my future sanity, I staged an intervention in the form of a [Python rewrite](https://github.com/cycneuramus/nmgr/tree/python-legacy) that was meant to tame the beast before it would be too late, and also for me to have some fun dabbling in overengineered OOP. Some time later, I was in the process of picking up some [Nim](https://nim-lang.org) and figured—since this has basically turned into my own little self-teaching project—I might as well go ahead and rewrite it a third time. So here we are.

## Installation

`nimble install nmgr`

## Usage

```sh
Usage:
  nmgr [options] action target

Arguments:
  action           Action to perform
  target           Target to operate on

Options:
  -h, --help
  -n, --dry-run              Simulate execution
  -d, --detach               Run jobs without waiting for completion
  -p, --purge                Completely remove jobs when stopping
  -v, --verbose              Show detailed output
  --version                  Show program version and exit
  --completion               Install Bash completion script
  -c, --config=CONFIG        Path to config file (default: ~/.config/nmgr/config)
```

## Rationale

Consider the following use-cases:

- You're using something like [Renovate](https://renovatebot.com) to manage updates to container image versions. Now one fine day, a whole bunch of these comes in as a PR, so you merge, pull locally—and then what? Do you manually hunt down all the jobs needing to be updated and restart them one by one? Well, now you can do this instead:

  `nmgr reconcile all`

  Or, if you still would like to preserve some manual control:

  `nmgr reconcile my-specific-job`

  Also, just for fun, you might first want to compare a job's currently running images against those in its specification:

  ```
  $ nmgr image forgejo
  Live images:
  codeberg.org/forgejo/forgejo:9.0.3-rootless
  docker.io/valkey/valkey:7.2-alpine

  Spec images:
  codeberg.org/forgejo/forgejo:10.0.0-rootless
  docker.io/valkey/valkey:8.0-alpine
  ```

______________________________________________________________________

- You're about to perform a server upgrade that requires a restart. Instead of manually coddling every one of those 50+ running jobs first, it sure would be handy to be able to do this:

  ```
  nmgr down all
  sudo apt update && sudo apt upgrade
  sudo reboot now

  [...]

  nmgr up all
  ```

______________________________________________________________________

- Nextcloud's PHP spaghetti has decided to crap the bed, and you have no choice but to start tailing the logs. "What's the syntax again? `nomad logs -f -job nextcloud`? Wait, no, that errors out. Oh, that's right: I have to specify a 'task' to get the logs from. But what did I name the Nextcloud job tasks? I better check the job specification..." *No!* Stop right there.

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

______________________________________________________________________

- You find yourself wanting to break all the rules of application containers by looking to shell in and execute some command. Now what was it, `nomad alloc exec -job immich`? Apparently not: `Please specify the task`. Ah, right: `nomad alloc -job immich -task server`. What the hell? `Please specify the task` *again*? Perhaps `-task` has to precede `-job`? At this point you might feel like giving up. But fear not!

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

______________________________________________________________________

- At random parts of the day, your heart will sink when you suddenly remember you probably still have some jobs running with a `latest` image tag. After some time, you have had enough of these crises of conscience, so you roll up your sleeves, `ssh` into the server, and–what's that? You were going to go look for all those image specifications manually? Don't be silly:

  `nmgr find :latest`

______________________________________________________________________

- You're about to upgrade or otherwise mess with, say, a NAS on which a host of currently running jobs depend. Do you now wade through each and every job specification to remind yourself which jobs you would need to stop before making your changes? Instead, you could do this:

  `nmgr down nas`

  And then, after you're done messing with the NAS:

  `nmgr up nas`

  You could do the same thing for jobs that depend on e.g. a database job (`nmgr {up,down} db`), a [JuiceFS](https://juicefs.com) mount (`nmgr {up,down} jfs`), and so forth.

______________________________________________________________________

- Before blindly tearing down a bunch of jobs as in the example above, you would like to know exactly which jobs are going to be impacted. Hence, nervous Nellie that you are, you run:

  `nmgr list nas`

  Or, if you could muster up just a bit more courage, you might perform a dry-run:

  `nmgr -n down nas`

______________________________________________________________________

> [!NOTE]
> Some of these examples make use of custom target filters (`nas`, `jfs`, `db`). These can be defined in the [configuration file](https://github.com/cycneuramus/nmgr/blob/master/data/config) that will be generated on first run.

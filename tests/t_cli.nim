import std/[options, unittest]
import nmgr/cli
import pkg/argparse

var parser = buildParser()

suite "argument parsing":
  test "flags, action and targets":
    let opts = parser.parse(@["-n", "--purge", "down", "web", "db"])
    check opts.dry_run
    check opts.purge
    check not opts.detach
    check opts.action == "down"
    check opts.targets == @["web", "db"]
    check opts.config_opt.isNone

  test "config option":
    let opts = parser.parse(@["-c", "/tmp/cfg", "list"])
    check opts.config_opt.get == "/tmp/cfg"
    check opts.targets.len == 0

suite "listOpts":
  test "extracts and sorts options from help text":
    const help =
      """
nmgr

Usage:
  nmgr [options] action [targets ...]

Options:
  -h, --help
  -n, --dry-run              Simulate execution
  -c, --config=CONFIG        Path to config file (default: ~/.config/nmgr/config)
"""
    check listOpts(help) == @["--config", "--dry-run", "--help", "-c", "-h", "-n"]

  test "--list-options works against the real parser's help":
    try:
      discard parser.parse(@["--list-options"])
      fail()
    except ShortCircuit as e:
      check e.flag == "list_options"
      let opts = listOpts(e.help)
      for o in [
        "-h", "--help", "-n", "--dry-run", "-c", "--config", "--version", "--completion"
      ]:
        check o in opts
      check "--config=CONFIG" notin opts
      check "--list-actions" notin opts # hidden flags stay hidden

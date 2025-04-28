# Package

version = "1.0.0" # x-release-please-version
author = "cycneuramus"
description = "Programmatically manage jobs in a Nomad cluster"
license = "GPL-3.0-only"
srcDir = "src"
bin = @["nmgr"]

# Dependencies

requires "nim >= 2.2.2"

requires "argparse >= 4.0.2"

#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# rufus-cli launcher: run the Linux command-line port of Rufus straight from
# a checkout of this repository.
#
#   sudo ./rufus-cli.sh            interactive interface
#   ./rufus-cli.sh --help          all options
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd) || exit 1
exec "$here/cli/rufus-cli" "$@"

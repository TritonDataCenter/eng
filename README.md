<!--
    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
-->

<!--
    Copyright (c) 2014, Joyent, Inc.
-->

# eng: Joyent Engineering Guide

This repo serves two purposes: (1) It defines the guidelines and best
practices for Joyent engineering work (this is the primary goal), and (2) it
also provides boilerplate for a SmartDataCenter (SDC) project repo, giving you
a starting point for many of the suggestion practices defined in the guidelines.
This is especially true for node.js-based REST API projects.

## Overview

**You probably want to be looking at the
[actual Joyent engineering guide at docs/index.md](docs/index.md).**
This README.md is a template for repos to use.

Environment: SmartOS


## Code Layout

~~~
build/          Built bits.
deps/           Git submodules and/or commited 3rd-party deps should go
                here. See "node_modules/" for node.js deps.
docs/           Project docs. Uses markdown and man.
lib/            JavaScript source files.
node_modules/   Node.js deps, either populated at build time or commited.
                See Managing Node Dependencies.
pkg/            Package lifecycle scripts
smf/manifests   SMF manifests
smf/methods     SMF method scripts
src/            C/C++ source files.
test/           Test suite (able to generate TAP output).
tools/          Miscellaneous dev/upgrade/deployment tools and data.
Makefile
package.json    npm module info, if applicable (holds the project version)
~~~


## Development

Previously this repo had a file "server.js". We haven't created new API
services in a while and "server.js" fell too far behind the
dependencies' APIs, so "server.js" has been removed for now.

The build of an SDC service starts with compiling Node.js, so symbol
information is correct. The makefiles include building node from source.

Before pushing run `make prepush` and, if possible, get a code review.

### Build

    git clone git@github.com:joyent/eng.git
    cd eng
    make all

### Run

    node <server.js>


## Test

If you project has setup steps necessary for testing, then describe those
here.

    make test


## Documentation

[Joyent Engineering Guide is at docs/index.md](docs/index.md).

To update the guidelines, edit "docs/index.md" and run `make docs`
to update "docs/index.html". Works on either SmartOS or Mac OS X.


## Starting a Repo Based on eng.git

Create a new repo called "some-cool-fish" in "~/work" based on
"eng.git":

    ./tools/mkrepo $HOME/work/some-cool-fish


## Your Other Sections Here

Add other sections to your README as necessary. E.g. Running a demo, adding
development data.


## License

"eng: Joyent Engineering Guide" is licensed under the
[Mozilla Public License version 2.0](http://mozilla.org/MPL/2.0/).
See the file LICENSE.

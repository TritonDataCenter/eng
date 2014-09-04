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
also provides boilerplate for an SDC project repo, giving you a starting
point for many of the suggestion practices defined in the guidelines. This is
especially true for node.js-based REST API projects.

**You probably want to be looking at the actual guide in docs/index.restdown.**
This README.md is just a template for repos to use.


# Development

To run the boilerplate API server:

    git clone git@github.com:joyent/eng.git
    cd eng
    git submodule update --init
    make all
    node server.js

To update the guidelines, edit "docs/index.restdown" and run `make docs`
to update "docs/index.html".

Before commiting/pushing run `make prepush` and, if possible, get a code
review.



# Testing

    make test

If you project has setup steps necessary for testing, then describe those
here.


# Starting a Repo Based on eng.git

Create a new repo called "some-cool-fish" in your "~/work" dir based on "eng.git":
Note: run this inside the eng dir.

    ./tools/mkrepo $HOME/work/some-cool-fish


# Your Other Sections Here

Add other sections to your README as necessary. E.g. Running a demo, adding
development data.




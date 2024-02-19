<!--
    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
-->

<!--
    Copyright 2019 Joyent, Inc.
    Copyright 2024 MNX Cloud, Inc.
-->

# eng: Triton Engineering Guide

This repo serves two purposes: (1) It defines the guidelines and best
practices for Triton engineering work (this is the primary goal), and (2) it
also provides boilerplate for a Triton (formerly known as SDC) project repo,
giving you a starting point for many of the suggestion practices defined in
the guidelines. This is especially true for node.js-based REST API projects.

**You probably want to be looking at the
[actual Triton engineering guide at docs/index.md](docs/index.md).**
This README.md is a template for repos to use.

**If you have cloned this repo to start a new project**

Remove all eng guide blurb above, and use one of the following boilerplates
as the first paragraph of the introduction of your repo:

- For Triton-related repos:
```
    This repository is part of the Triton DataCenter project. See the [contribution
    guidelines](https://github.com/TritonDataCenter/triton/blob/master/CONTRIBUTING.md)
    and general documentation at the main
    [Triton project](https://github.com/TritonDataCenter/triton) page.
```
- For Manta-related repos:
```
    This repository is part of the Manta project.  For contribution
    guidelines, issues, and general documentation, visit the main
    [Manta](http://github.com/TritonDataCenter/manta) project page.
```
After the boilerplate paragraph, write a brief description about your repo.


## Development

To ensure maximum compatibility, release builds are performed on a build zone
that is old enough to allow new and updated components to run on all supported
platform images.  If you are not using the Triton Jenkins instance for
performing builds, you should build using an appropriate build zone.  See
[Build Zone Setup for Manta and Triton](https://github.com/TritonDataCenter/triton/blob/master/docs/developer-guide/build-zone-setup.md).

Describe steps necessary for development here.

    make all


## Test

Describe steps necessary for testing here.

    make test


## Documentation

[Triton Engineering Guide is at docs/index.md](docs/index.md).

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

"eng: Triton Engineering Guide" is licensed under the
[Mozilla Public License version 2.0](http://mozilla.org/MPL/2.0/).
See the file LICENSE.

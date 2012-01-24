# Joyent Engineering Guide

Repository: <git@git.joyent.com:eng.git>
Browsing: <https://mo.joyent.com/eng>
Who: Trent Mick, Dave Pacheco
Docs: <https://head.no.de/docs/eng>
Tickets/bugs: <https://devhub.joyent.com/jira/browse/TOOLS>


# Overview

This repo serves two purposes: (1) It defines the guidelines and best
practices for Joyent engineering work (this is the primary goal), and (2) it
also provides boilerplate for an SDC project repo, giving you a starting
point for many of the suggestion practices defined in the guidelines. This is
especially true for node.js-based REST API projects.

Start with the guidelines: <https://head.no.de/docs/eng>


# Repository

    deps/           Git submodules and/or commited 3rd-party deps should go
                    here. See "node_modules/" for node.js deps.
    docs/           Project docs (restdown)
    lib/            Source files.
    node_modules/   Node.js deps, either populated at build time or commited.
                    See Managing Dependencies.
    pkg/            Package lifecycle scripts
    smf/manifests   SMF manifests
    smf/methods     SMF method scripts
    test/           Test suite (using node-tap)
    tools/          Miscellaneous dev/upgrade/deployment tools and data.
    Makefile
    package.json    npm module info (holds the project version)
    README.md


# Development

To run the boilerplate API server:

    git clone git@git.joyent.com:eng.git
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



# Other Sections Here

Add other sections to your README as necessary. E.g. Running a demo, adding
development data.



# TODO

Things for dap and I to discuss and add. Also see "TODO" and "XXX" in other
places in this file and repo.

- CHANGES.md: May be controversial. I maintain a changelog in most of my projects. E.g. 
  <https://github.com/trentm/json/blob/master/CHANGES.md>.

- "test/" vs. "tst/". I think we both want "make test" to work. Are you opposed
  to having a "test/" dir and using this in the Makefile?

        .PHONY: test
        test:
            ...

  I find "tst" a little weird. Less weird than MAPI's "spec" tho. :)
  Not-at-all-scientific analysis:

        $ ls -d -1 */tst
        amon/tst
        cloud-analytics/tst
        cloud-api/tst
        node-http-signature/tst
        node-sdc-clients/tst
        ufds/tst
        $ ls -d -1 */test
        billing_api/test
        booter/test
        dsapi/test
        dsurn/test
        node-dataset-template/test
        node-hostrouter/test

- versioning: In my personal projects, the current version at the HEAD of the
  "master" branch is a patch-level ahead of that last release. I automate
  releases via <https://github.com/trentm/cutarelease> (handles commit, push,
  tag, npm publish, incrementing the version for subsequent dev).  I'm not sure
  if "the current version at HEAD is a patch-level ahead" will work well for
  the SDC repos. 
  
  Perhaps an earlier discussion we should have is agreement (or not) on
  major.minor.patch-based versioning (a subset of semver). See "project
  conventions" section at <https://github.com/trentm/cutarelease> for my take.

- running jsl, having make check targets, etc.
  repo names, JIRA projects, doc layout (restdown), etc. etc.
  molybdenum setup, head.no.de/docs setup
  list of new APIs: MAPI (make a new repo for this, mapi.git?), NAPI
      (napi.git), CNAPI, FWAPI (existing fwapi.git), DAPI, ZAPI, Workflow API (call
      it WAPI?)

- [Trent] Put in suggested restdown usage. The various current users slice
  it a different way.
  
  I'm going to advocate using a git submodule for the restdown tool, which
  will gall some. We can doc an alternative for those allergic to
  git submodules.
  
- Add the node/npm local build support a la Amon and DSAPI? I.e. deps/node
  and deps/npm git submodules and build handling in the Makefile.

- Config handling. I'm a JSON fan for this, with a section in the restdown
  docs describing each piece. Maybe even so far as the factory-settings.json
  in Amon master for the defaults.


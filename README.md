# Boilerplate API (A start at your real API repo)

Repository: <git@git.joyent.com:boilerplateapi.git>
Browsing: <https://mo.joyent.com/boilerplateapi>
Who: Trent Mick, Dave Pacheco
Docs: <https://head.no.de/docs/boilerplateapi>
Tickets/bugs: <https://devhub.joyent.com/jira/browse/TOOLS>


# Overview

This repo provides project boilerplate for an SDC project repo, and especially
for the common case of a project implementing a node.js-based API.


# Repository

    deps/           Git submodules and/or commited 3rd-party deps should go
                    here. See "node_modules/" for node.js deps.
    docs/           Project docs. Uses <https://github.com/trentm/restdown>.
    lib/            Source files.
    node_modules/   Node.js deps, either populated at build time or
                    commited. See
                    <https://hub.joyent.com/wiki/display/dev/npm+dependencies>
    test/           Test suite. node-tap prefered.
    tools/          Miscellaneous dev/upgrade/deployment tools and data.
    Makefile
    package.json    npm module info (holds the project version)
    README.md


# Development

TODO: describe how to build and run the code (in the various environments,
Mac/COAL/BH1, if applicable). Describe checklist for commiting, e.g. from CA:

> Before checking code in:
> - run "gmake pbchk" to check for lint, style, and automated test errors

"pbchk"? WTF does that stand for? :) --Trent

> - make sure that each line in the commit comment contains a JIRA ticket
>   number, the ticket synopsis, and nothing else

The layout I tend to follow is:

    $ticketNumber(s): $shortSummary
                                            <--- blank line here
    $optionalDeeperDetailsOnTheChange
    
E.g. <https://mo.joyent.com/amon/commit/c5fa4411>

    MON-12: a start at Amon-master caching data from UFDS (*off* by default)
            
    Set "ufds.caching = true" in config to turn it on. It is incomplete and
    not working fully yet.

This "first line should be the full summary" comes from the git community, and
historically from git usage (for Linux kernel) being centered around email:
that first line would be the email subject.
<http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html>
Some of the git commands will show a one-line summary of commits.

> - if possible, get a code review



# Testing

Notes on how to setup for (if necessary), run and work with the test suite.
This may be as simple as this:

    make test



# Other Sections Here

Add other sections to your README as necessary. E.g. Running a demo, adding
development data.



# TODO

Things for dap and I to discuss and add. Also see "TODO" in other places in
this file and repo.

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


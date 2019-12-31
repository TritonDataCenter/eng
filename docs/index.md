---
title: Joyent Engineering Guide
markdown2extras: tables, code-friendly
apisections:
---
<!--
    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
-->

<!--
    Copyright 2019 Joyent, Inc.
-->

# Joyent Engineering Guide

This document describes standards and best practices for software development at
Joyent. These standards are intended to maintain product quality and to provide
consistency across codebases to make it easier for all engineers to learn new
parts of the system. This latter goal is important to encourage everyone to feel
comfortable diving into all parts of the system, as is often necessary when
debugging.

It's important to remember that all situations are unique, so rules should not
be followed blindly. However, these guidelines represent the best practices
agreed upon by the team. If you feel it necessary to diverge from them, that's
okay, but be prepared to explain why.

Note: In this document (and elsewhere at Joyent), a service implementing an API
is referred to by the API name itself. For example, "SAPI" denotes both the
"Services API" in the abstract as well as the software component that implements
that API.


# Repository Guidelines

These guidelines cover naming, structure, and processes around repositories.
A template repository is included in this repo so you can quickly get something
working that follows these guidelines.


## Rule #1: FCS Quality All the Time

In general, use the "master" branch for development. Development should not be
ongoing in the release branches. "master" must be
**FCS quality all the times**. The deliverables should always be of
high enough quality to ship to a first customer, FCS (first customer ship).


When working on large features, it's tempting to use development branches that
eventually get integrated into master. Indeed, this is sometimes necessary.
However, it should be avoided when possible, as it means people are running dev
branches rather than "master", which can lead to a [quality death spiral
(QDS)](http://wiki.illumos.org/display/illumos/On+the+Quality+Death+Spiral)
as fewer people actually run the mainline tree. Where possible, consider
whether larger projects can be split into reasonably-sized chunks that can
individually be integrated into "master" without breaking existing
functionality. This allows you to continue developing on "master" while still
being able to commit frequently.


## Repositories and documentation

Open-source projects and components live at github.com/joyent. These include
Node.js, SmartOS, Triton, Manta, and a large number of smaller Node modules and
other components. Some components still live under individuals' github
accounts, but new components should generally be created under the "joyent"
organization.

Note that just because a repo is on github doesn't mean its issues are tracked
there. That's decided on a per-project basis.

Some older components (and a few proprietary ones that are still used) are
managed by gitosis running on the internal Joyent git server. Files, commits,
and documentation for these projects can be browsed at mo.joyent.com by Joyent
employees.


## Repository Naming

For repositories representing an API, the repo name that matches how the API is
discussed (spoken, chatted and emailed) means you'll get the repo name right on
first guess. If you can get away with it, a repo named after the abbreviate API
name is best. For example:

    Network API -> NAPI -> napi.git          # Good.
                        -> network-api.git   # Less good.
                        -> network_api.git   # Even less good.
                        -> NAPI.git          # Whoa! Capital letters are crazy here.


## Language

New server-side projects should almost certainly use Node.js with C/C++
components as needed. Consolidating onto one language makes it easier for
everyone to dig into other teams' projects as needed (for development as well
as debugging) and allows us to share code and tools.


## Code Layout

Here is a suggested directory/file structure for your repository. All
repos **must** have a `README.md` and `Makefile`. The others are suggested
namings for particular usages, should your repo require them.

    build/          Built bits.
    deps/           Git submodules and/or committed 3rd-party deps should go
                    here. See "node_modules/" for node.js deps.
    docs/           Project docs. Uses markdown and man.
    lib/            JavaScript source files.
    node_modules/   Node.js deps, either populated at build time or committed.
    pkg/            Package lifecycle scripts
    smf/manifests   SMF manifests
    smf/methods     SMF method scripts
    src/            C/C++ source files.
    test/           Test suite (able to generate TAP output).
    tools/          Miscellaneous dev/upgrade/deployment tools and data.
    Makefile        See below.
    package.json    npm module info, if applicable (holds the project version)
    README.md       See below.


"docs" or "doc"? "test" or "tst"? We're not being religious about the
directory names, however the Makefile target names should use the names
specified below to allow automated build tools to rely on those names. The
reason to suggest "docs" and "test" as the directory names is to have the
same name as the Makefile targets.


### README.md

Every repository **must** have in its root a README.md (Markdown) file that
describes the repo and covers:

* the name of the API or other component(s) contained in the repo and a brief
  description of what they do
* the boilerplate text for referencing the contribution and issue tracking
  guidelines of the master project (Triton or Manta)
* the JIRA project for this repo (and any additional instructions, like how JIRA
  components are used for this project)
* owners of the project
* the style and lint configurations used, any additional pre-commit checks, and
  any non-standard useful Makefile targets
* some overview of the structure of the project, potentially including
  descriptions of the subcomponents, directory structure, and basic design
  principles
* basic development workflow: how to run the code and start playing with it

It's strongly recommended to start with the template in this repo.


### Makefile

All repos **must** have a Makefile that defines at least the following targets:

* `all`: builds all intermediate objects (e.g., binaries, executables, docs,
  etc.). This should be the default target.
* `check`: checks all files for adherence to lint, style, and other
  repo-specific rules not described here.
* `clean`: removes all built files
* `prepush`: runs all checks/tests required before pushing changes to the repo
* `docs`: builds documentation (restdown markdown, man pages)
* `test`: Runs the test suite. Specifically, this runs the subset of the
  tests that are runnable in a dev environment. See the "Testing" section
  below.
* `release`: build releasable artifacts, e.g. a tarball (for projects that
  generate release packages)

The `check` and `test` targets **must** fail if they find any 'check'
violations or failed tests. The `prepush` target is intended to cover all
pre-commit checks. It **must** run successfully before any push to the repo.
It **must** also be part of the automated build. Any commit which introduces a
prepush failure **must** be fixed immediately or backed out. A typical prepush
target will look like the following, but some non-code repositories might
differ (e.g. not have a test suite):

    prepush: check test
            @echo "Okay to push."

There are several modular Makefiles you can use to implement most of this. See
"Writing Makefiles" (below) for details.


### package.json and git submodules

Repositories containing node.js code should have a `package.json` file at the
root of the repository [1]. Normally most dependencies should be taken care of
through `npm` and this `package.json` file, by adding entries to the
`dependencies` or `devDependencies` arrays (see examples in this repository, or
documentation on the `npm` website).

Dependencies via `npm` can either take the form of an `npm` package name with a
version specifier (in which case it must be published to the public `npm`
package servers), or a `git` URL.

For externally developed packages not published by Joyent, version specifiers
should always be used (and the package published to `npm`):

    "dependencies": {
      "external-module": "^1.0.0"
    }

The use of version ranges (such as the `"^"` in the example above) is not
required and you should use your judgment about the quality of release
management and adherence to semantic versioning in the module you depend on.

For packages developed by us, we have a weak preference towards publishing `npm`
packages, stronger for shared library code that could be used outside Triton
proper. Most usage of `git` URLs is historic and due to the original closed-
source nature of the Triton stack.

If you are using a `git` URL in an `npm` dependency, you must use a
`git+https://` URL to specify it (not `git://` or `git+ssh://`). Plain `git://`
operations are not authenticated in any way and can be hijacked by malicious
WiFi or other network man-in-the-middle attacks (e.g. at airports and coffee
shops - yes, this actually happens). The use of `git+ssh://` URLs is discouraged
because it prevents users from being able to clone and build the package on a
machine that does not have their GitHub private key on it.

    "dependencies": {
      "joyent-module": "git+https://github.com/joyent/node-joyent-module.git#016977"
    }

For certain dependencies, it is standard practice across the Joyent repositories
to use `git` submodules and not `npm`. This applies in particular to
`javascriptlint`, `jsstyle`, `restdown`, `sdc-scripts` and some other modules
that are not node.js-based. Similar to `npm` `git` dependencies, these must use
`https://` URLs only. Your `.gitmodules` file should look like:

    [submodule "deps/javascriptlint"]
            path = deps/javascriptlint
            url = https://github.com/davepacheco/javascriptlint.git

Lastly, though you will find discussion about it in places, we don't currently
use the npm "shrinkwrap" feature in any repositories. This is for a variety of
reasons, the discussion about which is far too involved to relate here (but feel
free to ask a senior Joyeur about the sordid history of SDC release management).

*[1]* There are a handful of exceptions here in cases where multiple logical
node.js modules are combined in one repository (e.g. `ca-native` and `amon`
modules).


## Coding Style

Every repository **must** have a consistent coding style that is enforced by
some tool. It's not necessary that all projects use the same style, though it's
strongly suggested to keep differences to a minimum (e.g., only hard vs. soft
tabs and tabstops). All styles **must** limit line length to 80
columns<sup>[1](#footnote1)</sup>.  Existing style-checking tools
include:

* C: [cstyle](https://github.com/joyent/illumos-joyent/blob/master/usr/src/tools/scripts/cstyle.pl)
* JavaScript: [jsstyle](https://github.com/davepacheco/jsstyle),
  [gjslint](https://code.google.com/closure/utilities/docs/linter_howto.html),
  [eslint](http://eslint.org/)
* Bash: bashstyle (contained in eng.git:tools/bashstyle)
* Makefiles: use bashstyle for now

Both cstyle and jsstyle (which are 90% the same code) support overriding style
checks on a per-line and block basis. `jsstyle` also now supports
configuration options for indent style and few other things. E.g., you
might like this in your Makefile:

    JSSTYLE_FLAGS = -o indent=4,doxygen,unparenthesized-return=0

Options can also be put in a "tools/jsstyle.conf" and passed in with '-f
tools/jsstyle.conf'. See the [jsstyle
README](https://github.com/davepacheco/jsstyle)) for details on
JSSTYLED-comments and configuration options.

Note that gjslint can be used as a style checker, but it is **not** a
substitute for javascriptlint. And as with all style checkers, it **must** be
integrated into `make check`.

Bash scripts and Makefiles must also be checked for style. The only style
guideline for now is the 80-column limit.

Make target: "check"


## Lint

Every C repository **must** run "lint" and every JavaScript repository **must**
run [javascriptlint](http://github.com/davepacheco/javascriptlint) and/or
[eslint](http://eslint.org) and all **must** be lint-clean. Note that lint is
not the same as style: lint covers objectively dangerous patterns like
undeclared variables, while style covers subjective conventions like spacing.

All of `lint`, `javascriptlint`, and `eslint` are very configurable. See
[RFD 100](https://github.com/joyent/rfd/tree/master/rfd/0100) for eslint usage
in Joyent repositories. Projects may choose to enable and disable particular
sets of checks as they deem appropriate. Most checks can be disabled on a
per-line basis. As with style, it's recommended that we minimize divergence
between repositories.

Make target: "check"


## Copyright

All source files (including Makefiles) should have the MPL 2.0 header and a
copyright statement. These statements should match the entries in the
`prototypes` directory. For an easy way to ensure that new files have the right
MPL 2.0 header and copyright statement, you can copy the corresponding file out
of the `prototypes` directory in `eng.git`.

The contents of the MPL 2.0 header must be:

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.

When modifying existing code, the year should be updated to be the
current year that the file was modified. There should only be a single
year, not a list. For example:

    Copyright 2019 Joyent, Inc.


## Testing

tl;dr: `make test` for dev environment tests. 'test/runtests' driver script
for in-Triton systems tests (see boilerplate 'tools/runtests.in').

All repos **must** be tested by a comprehensive automated test suite and must
be able to generate TAP output. (No particular node.js test framework is
required, but all things being equal, use "nodeunit" or "node-tap".)
These tests may be repo-specific, or may be part of a broader system test
suite (ideally both). In either case, bug fixes and new features should not
be integrated without adding new tests, and the tests **must** be run
automatically (as via jenkins) either with every commit or daily. Currently
this is handled by the [nightly environment](https://github.com/joyent/globe-theatre/)
and the "stage-test-\*" Jenkins jobs. In other words, your project should
have some sort of "stage-test-\*" job. Understanding and fixing failures in
the automated test run **must** be considered the top development priority for
that repo's team.  Persistent failures are not acceptable. Currently, these
nightly and CI environments can only be accessed by Joyent employees.

All installed components **should** provide a "runtests" driver script
(preferably in the "test" subdirectory) and the necessary test files
for running system tests (and unit tests are fine too) against your
running service -- as opposed to starting up parallel dev versions of your
service. The goal here is to provide a common, simple, and "just works"
entry point for test components as they are deployed in the product,
for the benefit of QA, continuous-integration testing, and devs not
familiar with a given component. Dev environment != production environment.
All "runtests" scripts **must** exit non-zero if any tests failed.


Q&A:

- Why not just "make test"?

  Not all components install (or should install) their Makefile. For example
  `make` isn't available in the headnode GZ. So "runtests" is a lowest common
  denominator in this regard. Also dev env != production env -- separate
  "make test" and "runtests" entry points can facilitate different test
  setup and test case selection, if necessary.

- What about a customer running tests and blowing away production data?!

  Each runtests will be prefixed with a kill switch so that 'runtests' will
  not be accidentally run on production systems. The kill switch is the
  presence of the '/lib/sdc/.sdc-test-no-production-data' file. See
  handling in 'tools/runtests.in' boilerplate.

- What's a "system" test? "unit" test?

    - unit tests: Tesing local code, no parts of the "system" are required
      to run, and no mocking.
    - integration tests: Local code, no "system", parts of the system are
      mocked out as required.
    - system tests: Testing the service(s) in a deployed environment.


## cscope

cscope is a terminal-based tool for browsing source. For performance, it's best
to use it with an index. For repos using this repo's Makefile, you can build a
basic index in a source tree using:

    # make xref

which translates to a make recipe something like this:

    .PHONY: xref
    xref: cscope.files
        $(CSCOPE) -bqR

    .PHONY: cscope.files
    cscope.files:
        find . -name '*.c' -o -name '*.h' -o -name '*.cc' -o -name '*.js' \
            -o -name '*.s' -o -name '*.cpp' > $@


You may also want the "-k" flag to cscope, which tells it to ignore standard
header files.

Once the index is built, you can browse the source with:

    # cscope -dq

cscope is available for SmartOS in pkgsrc. It's also buildable on MacOS. For
instructions, see [the
wiki](https://hub.joyent.com/wiki/display/dev/Snow+Leopard+tips%2C+fixes+and+bugs).

Make target: "xref"


## Documentation

### API Documentation

You **must** use [restdown](https://github.com/trentm/restdown). Please discuss
with Trent if this isn't workable for your project.

Restdown is a tool for creating docs (and especially REST API docs) using a
single Markdown file with a few added conventions. You can set it up as
follows. Get the restdown tool:

    git submodule add https://github.com/trentm/restdown.git deps/restdown
    cd deps/restdown/
    git checkout 1.2.15    # let's use a restdown release tag

Get a starter restdown file:

    mkdir -p docs/media/img
    cp ../eng/docs/boilerplateapi.md docs/index.md
    cp ../eng/docs/media/img/favicon.ico docs/media/img/
    cp ../eng/docs/media/img/logo.png docs/media/img/

Tell the Makefile about it (`make docs`):

    DOC_FILES = index.md



### Code Documentation

Consider adding a block comment at the top of every file that describes at a
high level the component that's implemented in the file. For example:

    /*
     * ca-profile.js: profile support
     *
     * Profiles are sets of metrics. They can be used to limit visibility of
     * metrics based on module, stat, or field names, or to suggest a group of
     * metrics to a user for a particular use case.
     */

For non-trivial subsystems, consider adding a Big Theory statement that
describes what the component does, the external interface, and internal details.
For a great example, check out
[panic.c](https://github.com/joyent/illumos-joyent/blob/master/usr/src/uts/common/os/panic.c#L29)
in the kernel.

Consider keeping design documents in restdown inside the repo. It's okay to have
one-off documents for specific projects, even if they become out of date as the
code evolves, but make clear in the document that the content may be out of
date. Keep such docs separate from general design documents that are kept up to
date.


## Node Build

If your deployed service or tool uses node, then it **must** provide its own
node build. The exception is services whose upgrade is tied to the Triton
platform, and hence can be tested against a known node build (the platform's
node build). There are two ways you can get a node build for your repo:

1. Build your own from sources. Read and use "tools/mk/Makefile.node.defs" and
   "tools/mk/Makefile.node.targ". You'll also need a git submodule of the node
   sources:

        $ git submodule add https://github.com/joyent/node.git deps/node
        $ cd deps/node
        $ git checkout v0.6.18   # select whichever version you want

2. Use a prebuilt node. Read and use "tools/mk/Makefile.node_prebuilt.defs"
   and "tools/mk/Makefile.node_prebuilt.targ".


## Node add-ons (binary modules)

Because C++ does not define a useful compiler- or platform-dependent
[binary](http://stackoverflow.com/questions/7492180/c-abi-issues-list)
[interface](http://developers.sun.com/solaris/articles/CC_abi/CC_abi_content.html),
and we have seen breakage resulting from changing compiler versions, any repo
that uses add-ons (binary modules) **must** bundle its own copy of "node" and
use that copy at runtime. And almost every repo will fall into this bucket,
since we use the native node-dtrace-provider heavily for observability.

The recommended way to do this is to add the official node repo as a git
submodule and build it during the build process. There are existing modular
Makefiles in this repo (eng.git) to do all the work. All you need to do is
include them and then add the appropriate dependencies on `$(NODE)`.


## Commit Comments and JIRA Tickets

In collaborating on a body of software as large as Triton, it's critical that
the issues and thought processes behind non-trivial code changes be documented,
whether that's through code comments, git commit comments, or JIRA tickets.
There are many cases where people other than the original author need to
examine the git log:

* An engineer in another area tries to understand a bug they've run into (in
  your repo or not), possibly as a result of a recent change. The easier it is
  for people to move between repos and understand recent changes, the more
  quickly bugs in master can be root-caused. This is particularly important to
  avoid an issue bouncing around between teams where the problem is *not*.
* An engineer in another area tries to understand when a feature or bugfix
  was integrated into your repo so that they can pull it down to use it.
* An engineer working on the same code base, possibly years later, needs to
  modify (or even rewrite) the same code to fix another bug. They need to
  understand why a particular change was made the way it was to avoid
  reintroducing the original bug (or introducing a new bug).
* A release engineer tries to better understand the risk and test impact of a
  change to decide whether it's appropriate to backport.
* A support engineer tries to better understand the risk and test impact of a
  change to decide whether it's appropriate for binary relief or hot patching.
* Product management wants to determine when a feature or bugfix was integrated.
* Automated tools want to connect commits to JIRA tickets.

To this end, we require that with every commit there **must** be a comment that
includes the list of JIRA tickets addressed with this commit and a synopsis of
the changes (*either* for the whole commit *or* for each change, one by one).
**Between the JIRA ticket and the commit comment itself, there must be
sufficient information for an engineer that's moderately familiar with the code
base, possibly years later but with source in hand, to understand how and why
the change was made.**

The worst case is when the thought process and issue list are nowhere: not in
the comments and not in the JIRA tickets.

### Commit Comments

Across Joyent we require that **each commit be associated with one or more JIRA
tickets and that those tickets be listed in the commit comments**. This way,
given either the commit or the JIRA ticket, one can find the other.

Historically, some repos (notably illumos-joyent and cloud-analytics) have
additionally required that tickets must not be reused for multiple commits in
the same repo except for very minor changes like fixing lint or style warnings.
This makes it easier to correlate tickets and commits, since there's usually
exactly one commit for each resolved ticket. It also makes it easier to
back out the changes for a particular project. For these repos, the git
comments for the commit consist of a single line per JIRA ticket being resolved
in the commit. Each line consists of the ticket identifier and the synopsis
exactly as it appears in JIRA (optionally truncated to 80 characters with
"..."):

    OS-147 vfsstat command to show VFS activity by zone
    OS-148 Update ziostat to coexist peacefully with vfsstat
    OS-149 New kstats to support vfsstat

This approach encourages short, descriptive ticket synopses. For repos that keep
track of code reviews (e.g., illumos-joyent), that information is appended like
this:

    OS-850 Add support for Intel copper quad I350 to igb.
    Reviewed by: Jerry Jelinek <jerry.jelinek@joyent.com>

In the rare cases where the same ticket is used for multiple commits, a
parenthetical is used to explain why:

    INTRO-581 move mdb_v8 into illumos-joyent (missing file)

This structure works well for established repos like illumos, but it's not
always appropriate. For new work on greenfield projects, it may not even make
sense to use more than one ticket until the project reaches a first milestone.

### JIRA Tickets

For bugs, especially those that a customer could hit, consider including
additional information in the JIRA ticket:

* An explanation of what happened and the root cause, referencing the source
  where appropriate. This can be useful to engineers debugging similar issues
  or working on the same area of code who want to understand exactly why a
  change was made.
* An explanation of how to tell if you've hit this issue. This can be pretty
  technical (log entries, tools to run, etc.). This can be useful for engineers
  to tell if they've hit this bug in development as well as whether a customer
  has hit the bug.
* A workaround, if any.

Of course, much of this information won't make sense for many bugs, so use your
judgment, but don't assume that you're the only person who will ever look at the
ticket.

# Logging

There are at least three different consumers for a service's logs:

- engineers debugging issues related to the service (which may not actually be
  problems with the service)
- monitoring tools that alert operators based on error events or levels of
  service activity
- non real-time analysis tools examining API activity to understand performance
  and workload characteristics and how people use the service

For the debugging use case, **the goal should be to have enough information
available after a crash or an individual error to debug the problem from the
very first occurrence in the field**. It should also be possible for engineers
to manually dump the same information as needed to debug non-fatal failures.

Triton service logs **must** be formatted in JSON. Node.js services **must**
use [Bunyan](https://github.com/trentm/node-bunyan). Exceptions: (a) you are
using syslog (see use case for syslog below); (b) your service is legacy; or,
(c) you just haven't migrated to Bunyan yet (which is fine, JSON log output
is not a top-priority make work project). If you have an example of a log for
which JSON format gets in the way, please bring it up for discussion).

Multiple use cases do not require multiple log files. Most services should log
all activity (debugging, errors, and API activity) in JSON to either the SMF
log or into a separate log file in
"/var/smartdc/&lt;service&gt;/log/&lt;component&gt;.log". For services with
extraordinarily high volume for which it makes sense to separate out API
activity into a separate file, that should be directed to
"/var/smartdc/&lt;service&gt;/log/requests.log". However, don't use separate
log files unless you're sure you need it. All log files in
"/var/smartdc/&lt;service&gt;/log" should be configured for appropriate log
rotation.

For any log entries generated while handling a particular request, the log
entry **must** include the request id. See "Request Identifiers" under "REST
API Guidelines" below.

Log record fields **must** conform to the following (most of which comes
for free with Bunyan usage):

| JSON key | Description | Examples | Required |
| -------- | ----------- | -------- | -------- |
| **name** | Service name. | "ca" (for Cloud Analytics) | All entries |
| **hostname** | Server hostname. | `uname -n`, `os.hostname()` | All entries |
| **pid** | Process id. | 1234 | All entries |
| **time** | `YYYY-MM-DDThh:mm:ss.sssZ` | "2012-01-26T19:20:30.450Z" | All entries |
| **level** | Log level. | "fatal", "error", "warn", "info", or "debug" | All entries |
| **msg** | The log message | "illegal argument: parameter 'foo' must be an integer" | All entries |
| **component** | Service component. A sub-name on the Logger "name". | "aggregator-12" | Optional |
| **req_id** | Request UUID | See "Request Identifiers" section below. Restify simplifies this. | All entries relating to a particular request |
| **latency** | Time of request in milliseconds | 155 | Strongly suggested for entries describing the completion of a request or other backend operation |
| **req** | HTTP request | -- | At least once as per Restify's or [Bunyan's serializer](https://github.com/trentm/node-bunyan/blob/master/lib/bunyan.js#L856-870) for each request. |
| **res** | HTTP response | -- | At least once as per Restify's or [Bunyan's serializer](https://github.com/trentm/node-bunyan/blob/master/lib/bunyan.js#L872-878) for each response. |

We use these definitions for log levels:

- "fatal" (60): The service/app is going to stop or become unusable now.
  An operator should definitely look into this soon.
- "error" (50): Fatal for a particular request, but the service/app continues
  servicing other requests. An operator should look at this soon(ish).
- "warn" (40): A note on something that should probably be looked at by an
  operator eventually.
- "info" (30): Detail on regular operation.
- "debug" (20): Anything else, i.e. too verbose to be included in "info" level.
- "trace" (10): Logging from external libraries used by your app or *very*
  detailed application logging.

Suggestions: Use "debug" sparingly. Information that will be useful to debug
errors *post mortem* should usually be included in "info" messages if it's
generally relevant or else with the corresponding "error" event. Don't rely
on spewing mostly irrelevant debug messages all the time and sifting through
them when an error occurs.

Most of the time, different services should log to different files. But in some
cases it's desirable for multiple consumers to log to the same file, as for
vmadm and vmadmd. For such cases, syslog is an appropriate choice for logging
since it handles synchronization automatically. Care must be taken to support
entries longer than 1024 characters.


# SMF Integration

All services **must** be delivered as SMF services. This means:

- They deliver an SMF service manifest.
- The install mechanism imports the manifest.
- The uninstall mechanism deletes the service.
- The service is started, stopped, restarted, etc. via SMF.

While SMF itself is grimy and the documentation is far from perfect, the
documentation *is* extensive and useful. Many common misunderstandings about
how SMF works are addressed in the documentation. It's strongly recommended
that you take a pass through the docs before starting the SMF integration for
your service. In order of importance, check out:

- SMF concepts: smf(5), smf_restarter(5), smf_method(5), svc.startd(1M)
- Tools: svcs(1), svcadm(1M), svccfg(1M)

Common mistakes include:

- Setting the start method to run the program you care about (e.g., "node
  foo.js") rather than backgrounding it (e.g., "node foo.js &"). SMF expects
  the start method to start the service, not *be* the service. It times out
  start methods that don't complete, so if you do this you'll find that your
  service is killed after some default timeout interval. After this happens
  three times, SMF moves the service into maintenance.
- Using "child" or "wait model" services to avoid the above problem. Read the
  documentation carefully; this probably doesn't do what you want. In
  particular, if your "wait model" service fails repeatedly, SMF will never put
  it into maintenance. It will just loop forever, forking and exiting.
- Not using "-s" with svcadm enable/disable. Without "-s", these commands are
  asynchronous, which means the service may not be running when "svcadm enable"
  returns. If you really care about this, you should check the service itself
  for liveness, not rely on SMF, since the start method may have completed
  before the service has opened its TCP socket (for example).

## Managing processes under SMF

SMF manages processes using an OS mechanism called contracts. See contract(4)
for details. The upshot is that it can reliably tell when a process is no
longer running, and it can also track child processes.

Quoting svc.startd(1M):

     A contract model service fails if any of the following conditions
     occur:

         o    all processes in the service exit

         o    any processes in the service produce a core dump

         o    a process outside the service sends a service process a
              fatal signal (for example, an administrator terminates a
              service process with the pkill command)

Notice that if your service forks a process and *that* process exits,
successfully or otherwise, SMF will not consider that a service failure. One
common mistake here is forking a process that will be part of your service, but
not considering what happens when that process fails (exits). SMF will not
restart your service, so you'll have to manage that somehow.

## Service logs

SMF maintains a log for each service in /var/svc/log. The system logs restarter
events here and launches the start method with stderr redirected to the log,
which often means the service itself will have stderr going to this log as
well. It's recommended that services either use this log for free-form debug
output or use the standard logging facility described under "Logging" above.

# REST API Guidelines

It's strongly recommended to use
[restify](https://github.com/mcavage/node-restify) for all web services. Not
only will you leverage common code and test coverage, but restify gives you
features like DTrace observability, debuggability, throttling, and versioning
out of the box. If it doesn't support something you need, consider adding it
rather than rolling your own.

## Request Identifiers

A request identifier uniquely identifies an operation across multiple services
(e.g., portal, cloudapi, ca, ufds). It's essential for debugging issues after
they've happened. The goal is for issues to be debuggable from the information
available after their first occurrence, without having to reproduce it to
gather more information. To facilitate this:

- When an external service receives a request from the outside, it **must**
  generate a unique request identifier and include it in the "x-request-id"
  header of any requests made as part of handling the initial request.
- When any service receives a request with an "x-request-id" header, it
  **must** include it in the "x-request-id" header of any request made as part
  of handling that request.
- When each service logs activity (API requests), alerts, or debug messages
  related to a particular request, it **must** include the request id as
  the "req_id" field (as described in the [Bunyan
  docs](https://github.com/trentm/node-bunyan)).


## Naming Endpoints

Service API endpoints **should** be named. Endpoint names **must** be
CamelCase, **should** include the name of resource being operated on,
and **should** follow the lead of
[CloudAPI](https://apidocs.joyent.com/cloudapi/) for verb usage, e.g.:

    # CRUD examples:
    ListMachines
    GetMachine
    CreateMachine
    DeleteMachine

    # Other actions, if applicable:
    StopMachine
    StartMachine
    RebootMachine
    ResizeMachine

    # Example using "Put" verb from
    # <https://apidocs.joyent.com/manta/api.html#PutObject> when the action
    # is idempotent.
    PutObject


## Error Handling

APIs must provide meaningful and actionable error responses, especially for
requests that involve submitting data (i.e. non-GET requests). "Actionable"
here means that enough information is provided for programmatic handling of
errors.

### Motivation

[Node-restify error support](https://github.com/restify/errors)
provides a set of `RestError` classes with a typical response like:

    HTTP/1.1 409 Conflict
    ...

    {
      "code": "InvalidArgument",
      "message": "I just don't like you"
    }

However, API clients often need more information about the failure of a
request. This scheme does not provide a way to programmatically match a
failure to one of multiple input parameters. E.g., consider a client
attempting to present errors in a form for a "CreateFoo" endpoint.

E.g., API clients that implement user interfaces need to give users
feedback about the errors produced after submitting a form, where a message
such as "RAM must be greater than 1024" is more useful than "Arguments are
invalid" messages produced by generic *node restify* server implementations.

### Error Response Format

    HTTP/1.1 <statusCode> ...
    ...

    {
      "code": "<restCode>",
      "message": "<message>",
      "errors": [
        {
          "field": "<errorField>",
          "code": "<errorCode>",
          "message": "<errorMessage>"
        },
        ...
      ]
    }

JEG-based API error response guidelines:

- **must** use a meaningful HTTP `statusCode`. See
  <http://en.wikipedia.org/wiki/List_of_HTTP_status_codes>.
- **must** include a `code` CamelCase string code field
- **must** include a `message` string description of the error. The
  message must be a human readable string that allows users to understand
  the nature of the error *code*, as the same error *code* can be produced
  with two different *messages*. An example of this might be an
  "InternalError" *code* that could return "Database is offline" or "Cache
  not running" as its *message*.
- **may** include an `errors` array. Each element of that array **must**
  include a `field` name, **must** include a `code` CamelCase string code
  field and **may** include a `message` string field.

Suggested `errors.*.code` fields are:

| Code | Description |
| ---- | ----------- |
| Missing | The resource does not exist. |
| MissingParameter | A required parameter was not provided. |
| Invalid | The formatting of the field is invalid. |


### Example:

    HTTP/1.1 422 Unprocessable Entity
    ...

    {
      "code": "InvalidParameters",
      "message": "Invalid paramaters to create a VM",
      "errors": [
        {
          "field": "ram",
          "code": "Invalid",
          "message": "RAM is not a number"
        },
        {
          "field": "brand",
          "code": "MissingParameter"
        },
        {
          "field": "image_uuid",
          "code": "Missing",
          "message": "Image '6b288017-2c2d-354b-83d4-69748d50284d' does not exist"
        }
      ]
    }


### Best Practice

TODO: Trent is working on code to use with restify v2.0 to facilitate
subclassing restify.RestError to make the above simpler.


### Documenting Errors

An API **must** document all of the `restCodes` it can produce. An "Errors"
section near the top of the API's restdown docs is suggested. For example:

    ||**HTTP Status Code**||**JSON Code**||**Description**||
    ||400||OperationNotAllowedOnRootDirectory||Trying to call PUT on `/`||
    ||404||ResourceNotFound||If `:account` does not exist||
    ||409||EntityExists||If the specifed path already exists and is not a directory||
    ||409||ParentNotDirectory||Trying to create a directory under an object||

Additionally, each endpoint **must** document all custom `errors.*.code`
values it can produce. If just a stock set of error codes is used, then
it is sufficient to document those in the "Errors" section at the top
of the API docs.



# Bash programming guidelines

## xtrace

Bash has a very useful feature called "xtrace" that causes it to emit
information about each expression that it evaluates. You can enable it for a
script with:

    set -o xtrace

With newer versions, you can redirect this output somewhere other than stderr
by setting
[BASH_XTRACEFD](https://www.gnu.org/software/bash/manual/bashref.html#Bash-Variables).

This is incredibly useful for several situations:

- debugging non-interactive system scripts (e.g., SMF start methods) *post
  mortem*. Such scripts should leave xtrace on all the time, since they're not
  run frequently enough for the extra logging to become a problem and the
  xtrace output makes it significantly easier to understand what happened when
  these scripts go wrong.
- debugging interactive scripts in development. You can run bash with "-x" to
  enable xtrace for a single run. You usually don't want to leave xtrace on for
  interactive scripts, unless you redirect the xtrace output:
- debugging interactive scripts *post mortem* by enabling the xtrace output and
  redirecting it to a temporary file. Be sure to remove the file when the
  script exits successfully.

## Error handling

It's absolutely possible to write robust shell scripts, but the default shell
behavior to ignore errors means you have to consider how to handle errors in
order to avoid creating brittle scripts that are difficult to debug.

The biggest hammer is the "errexit" option, which you can enable with:

    set -o errexit

This will cause the program to exit when simple commands, pipelines, and
subshells return non-zero. Commands invoked in a conditional test, a loop test,
or as part of an `&&` or `||` list do not get this special treatment. While this
approach is nice because the default is that errors are fatal (so it's harder to
forget to handle them), it's not a silver bullet and doesn't let you forget
about error handling completely. For example, many commands *can* reasonably
fail with no ill effects and so must be explicitly modified with the unfortunate
` || true` to keep errexit happy.

A more fine-grained approach is to explicitly check for failure of invocations
that may reasonably fail. A concise pattern is to define a `fail` function
which emits its arguments to stderr and exits with failure:

    function fail()
    {
        echo "$*" >&2
        exit 1
    }

and then use it like this:

    echo "about to do something that might fail"
    zfs create zones/myfilesystem || fail "failed to create zones"

You can also use this with variable assignments

    echo "about to list contents of a directory that may not exist"
    foo=$(ls -1 $tmpdir) || fail "failed to list contents of '$tmpdir'"

It's also important to remember how error handling works with pipelines. From
the Bash manual:

    The exit status of a pipeline is the exit status of the last command in the
    pipeline, unless the pipefail option is enabled (see The Set Builtin). If
    pipefail is enabled, the pipeline's return status is the value of the last
    (rightmost) command to exit with a non-zero status, or zero if all commands
    exit successfully.

This means that if you run this to look for compressed datasets:

    # zfs list -oname,compression | grep on

If the "zfs" command bails out partway through, that pipeline will still
succeed (unless pipefail is set) because "grep" will succeed. To set pipefail,
use:

    set -o pipefail

## Running subcommands

Prefer `$(subcommand)` to `` `subcommand` ``, since it can be nested:

    type_of_grep=$(file $(which grep))

## Automatic Checks

See "Coding Style" above for style checks. Currently, the only enforced check
is an 80-column limit on line length.

It's also worth using "bash -n" to check the syntax of bash scripts as part of
your Makefile's "check" target. The Makefiles in eng.git automatically check
both syntax and style.

## Temporary Files

Put temporary files in /var/tmp/`$(dirname $0)`.`$$`. This will generally be
unique but also allows people to figure out what script left this output
around.

On successful invocations, remove any such temporary directories or files,
though consider supporting a `-k` flag (or similar) to keep the temporary files
from a successful run.

## Parsing command line options

By convention, illumos scripts tend to use `opt_X` variables to store the value
of the `-X` option (e.g., `opt_d` for `-d`). Options are best parsed with
getopts(1) (not to be confused with getopt(1)) using a block like this:

    function usage
    {
        [[ $# -gt 0 ]] && echo "$(dirname $0): $*" >&2

        cat <<-USAGE >&2
        Usage: $(dirname $0) [-fn] [-d argument] args ...

        Frobs args (optionally with argument <argument>).

        -f    force frobnification in the face of errors
        -n    dry-run (don't actually do anything)
        -d    specify temporary directory
        USAGE

        exit 2
    }

    opt_f=false
    opt_n=false
    opt_d=

    while getopts ":fnd:" c; do
            case "$c" in
            f|n)    eval opt_$c=true                                ;;
            d)      eval opt_$c=$OPTARG                             ;;
            :)      usage "option requires an argument -- $OPTARG"  ;;
            *)      usage "illegal option -- $OPTARG"               ;;
            esac
    done

    # Set $1, $2, ... to the rest of the arguments.
    shift $((OPTIND - 1))

Below are common command line options. If you're implementing the functionality
below, try to stick to the same option letters to maintain consistency. Of
course, many of these options won't apply to most tools.

    -?          Display usage message.
    -d dir      Use directory "dir" for temporary files
    -i          Interactive mode (force confirmation)
    -f          Barrel on in the face of errors
    -k          Keep temporary files (for debugging)
    -n          Dry-run: print out what would be done, but don't do it
    -o file     Specify output file
    -p pid      Specify process identifiers
    -r          Recursive mode
    -y          Non-interactive mode (override confirmations with "yes")
    -z          Generate (or extract) a compressed artifact

## Command-line scripts that perform multiple complex tasks

With xpg_echo, you can use "\c" with "echo" to avoid printing a newline.
Combined with the above error handling pattern, you can write clean scripts
that perform a bunch of tasks in series:

    shopt -s xpg_echo

    echo "Setting nodename to 'devel' ... \c"
    hostname devel || fail "failed to set hostname"
    echo "done."

    echo "Testing DNS ... \c"
    ping example.com || fail "failed"

    echo "Restarting ssh ... \c"
    svcadm disable -s ssh || fail "failed to disable service"
    svcadm enable -s ssh || fail "failed to enable service"
    echo "done."

The output is clean both when it succeeds:

    # ./setup.sh
    Setting nodename to 'devel' ... done.
    Testing DNS ... example.com is alive
    Restarting ssh ... done.

and when it fails:

    # ./setup.sh
    Setting nodename to 'devel' ... done.
    Testing DNS ... ping: unknown host example.com
    failed

This is primarily useful for complex scripts that people run interactively
rather than system scripts whose output goes to a log.

# Java

If you find yourself having to do anything related to Java or the Java Manta SDK
[QUICKSTART.md in java-manta](https://github.com/joyent/java-manta/blob/master/QUICKSTART.md)
has a condensed guide for getting started and covers many aspects of our usage
of Java and Maven that might not be familiar to an engineer that hasn't worked
with these tools yet.

# JIRA best practices for Customer Issues

We have all noticed that there are a lot more JIRA tickets originating from
customers than there were 6 months ago.

We need to refine the process of opening, updating, and resolving bugs so that
we maximize productivity, and reduce the time that bugs sit idle with not
enough information to act on.



## JIRA Updates

Providing regular updates to JIRA tickets is the best way to keep stakeholders
informed on the progress of the issue. A little more effort spent updating
JIRA issues will create a valuable knowledge base full of information for the
Ops and Support teams to use. The result will be:

1. Fewer issues coming through to the Dev team, as issues that have been worked
   through before will be able to be triaged before they are passed to
   engineering. We are are shooting for a 10:1 ratio of issues opened to
   issues passed to engineering. Currently we’re well over 10:5.

2. Issues that are passed to engineering have had more diagnostic information
   in them, as the Ops and Support teams learn from example on how to
   troubleshoot issues. This will reduce the time it takes for you to resolve
   issues, leaving you more time to work on more interesting projects.

3. Better customer relations, as the customer teams will be able to explain to
   the customers what steps are being taken to find them a solution to their
   problem.


### Assigning Tickets

![Assign To Me](media/img/assign_to_me.jpg)

It’s important to make sure that active tickets (tickets that someone is
working on) have an Assignee. The way that the triage teams decide if something
needs to be escalated to engineering triage is using this field. If there is no
one assigned to an issue, Ben and Deniz will continue to ask for a triage in
scrum. So if you’re working on an issue, even if you don’t intend to be the
final owner, click the “Assign to me” button in the top nav. This will indicate
that we’ve had eyes on this issue and it’s not sitting idle. You can always
reassign the issue if something changes.


### Needs More Info

![Needs More Info](media/img/needs_more_info.jpg)

Needs More Info is a custom status that we added last year to indicate that
there is not enough information to proceed on an issue. This could be used both
for development, when there is not enough info to troubleshoot, or by the
customer teams, if there is not enough info to resolve the issue with the
customer. Whenever you put a ticket into this state, make sure to assign the
ticket to whoever needs to provide the info. In your case, this will often be
the reporter. It is important to force a ticket into this status if you are
blocked on proceeding with diagnostics due to lack of information.


### Comments

![Comments](media/img/comments.jpg)

Commenting is important to keep our cross-functional teams aware of progress
made (or not made) on the resolution of a customer issue. Commenting best
practices:

- Comment often, even if you don’t have all of the details worked out yet. The
  more information provided the more informed we can make the customers.
- Comment instructionally, as if you were explaining to someone else how you
  diagnosed the issue. This will help the Ops and Support teams to be able to
  recognize, categorize and help diagnose issues on their own in the future,
  saving everyone time and energy.
- Comment consistently, at the end of the work day, for instance. Even if the
  comment is that you made little progress, it keeps the customer facing teams
  informed of what’s going on, so that they can make an informed decision on
  what to communicate back to the customer.


### Moving Tickets

Often a ticket will come in through the JPC project, but logically belongs in
another, as the problem needs to be resolved in Triton.

For issues like this, please use the Move feature to move the ticket into the
appropriate project. The JPC ticket will then automatically redirect users to
the new location.

![Move Ticket](media/img/move_ticket.jpg)


### Linking Tickets

When an issue is either related to, or a duplicate of , or depends on a ticket
that is already in the system, it’s valuable to link the 2 tickets in JIRA. You
can do this using the Link feature:

![Linking Tickets](media/img/linking_tickets.jpg)

The linked issue(s) will then show up in the ticket as a separate section:

![Issue Links](media/img/issue_links.jpg)


### Field: `Target Fix Version`

If you are working on an issue, it is important to know what release you are
targeting for the fix. Typically, you will either be targeting a Simpsons
version (meaning that the release to the customer would be the next major), or
a dot release. Your project lead can help clarify which release your fix should
go into if you are unsure.

Note: The JPC project only contains dot release versions. If something is more
suited for a Simpsons release version, you should move the ticket to another
project.

The customer teams will use this information to decide whether they can wait
for the fix in the next release, or if they’ll need to find a short term work
around.

![Target Fix Version](media/img/fix_version.jpg)


## Resolving JIRA Tickets

Issue resolutions should provide valuable information to the customer teams,
allowing them to communicate solutions back to our customers, as well as make
decisions on patches and workarounds.

Please spend some extra time when resolving bugs that originated from a
customer.


### Field: `Issue Resolution (Public)`

The Issue Resolution field is the field that the customer teams are going to
use to communicate information back to their customers about the bug fix.

This field must be filled out upon resolution if the ticket has originated from
a customer (either coming from the JPC project or having a customer label
attached to it).

When you are filling in this field, try to word it as though you are talking to
the customer. The customer doesn’t need to know every detail of how the issue
was resolved, but they do want to know how it will impact them.

![Resolution](media/img/resolution.jpg)

### Field: `Resolution`

Resolving a ticket once you’ve committed code indicates to the customer teams
that they can deliver a solution (or estimated release date) to the customer.
It is important to resolve your issues so that we continue to rotate bugs out
of the queue, and keep our customers happy.

| Resolution | Description |
| ---------- | ----------- |
| Fixed/Implemented | Indicates that a development solution has been implemented and can be communicated to the customer. Release date can be deduced from the fix version. |
| Duplicate | Indicates that this is already being worked on (or has been fixed) by another bug. Please Link the duplicate issue to the ticket. |
| Won't Fix | There are certain circumstances under which we will decline to resolve a customer issue. A couple examples of this are if the issue being raised occurs by design, if we are refactoring a part of the code base that will eliminate the bug once released, or if there is a sufficient workaround. Bryan and Laurel should be consulted if you think a bug is a "won't fix", and always include an explanation for the customer teams if you use this resolution on a ticket that originated from a customer. |


### Field: `Fix Version/s`

Fix version is the version in which you actually committed the code that fixed
the bug. It differs from Target Fix Version in that it should only be added to
the ticket after resolution. The fix version is what the customer teams will
use to decide whether or not a patch is required on the current operating
version.

![Fix Version](media/img/fix_version.jpg)



# Writing Makefiles

This repo (eng.git) provides a number of modular Makefiles which you can use
(perhaps even by direct reference using submodules) to provide the required
targets described above, as well as several other useful pieces (like building
Node in your repo). These are designed to be dropped in without modification:
they consume Make variables as input and either export other variables or define
rules. You should use these existing Makefiles wherever possible.

Importantly:

* If you find yourself adding anything other than a repo-specific variable
  definition or a repo-specific rule to your Makefile, consider creating a
  new Makefile with a crisp interface and adding it to the existing ones in
  eng.git. We want to avoid Makefile code duplication just as we would
  JavaScript code duplication.
* Do **not** modify a copy of any of the existing sub Makefiles from eng.git.
  Feel free to generalize or improve the original, but don't fork it.
* We do not use recursive Make. Avoid it within a project if at all possible.

Top level Makefiles should generally have the following structure:

1. Repo-specific definitions. These serve as inputs for included Makefiles. For
   example, you might define the list of JavaScript files that should be
   style-checked here.
2. Includes for Makefiles that define variables based on the repo-specific
   variables (e.g., repo specifies input files, and the included Makefile
   defines a list of output files, or modifies the list of files that will be
   removed with "make clean").
3. Repo-specific rules. These must be the first rules that appear in the
   Makefile so that the repo can control the default target and the order of
   dependencies for common targets.
4. Includes for Makefiles that define other rules.

The goal is that most top-level Makefiles only specify their parameters, the
repo-specific rules, and which other Makefiles get included to do the heavy
lift. Here's an example from eng.git:

    DOC_FILES        = index.md boilerplateapi.md
    JS_FILES        := $(shell ls *.js) $(shell find lib test -name '*.js')
    JSL_CONF_NODE    = tools/jsl.node.conf
    JSL_FILES_NODE   = $(JS_FILES)
    JSSTYLE_FILES    = $(JS_FILES)
    JSSTYLE_FLAGS    = -o indent=4,doxygen,unparenthesized-return=0
    SMF_MANIFESTS_IN = smf/manifests/bapi.xml.in

    include ./Makefile.defs
    include ./Makefile.node.defs
    include ./Makefile.smf.defs

    .PHONY: all
    all: $(SMF_MANIFESTS) | $(NPM_EXEC)
        $(NPM) install

    include ./Makefile.deps
    include ./Makefile.node.targ
    include ./Makefile.smf.targ
    include ./Makefile.targ

All of the included Makefiles are modular and know nothing about this repo, but
this Makefile provides all of the required targets: "docs" to build HTML from
restdown, "check" to check SMF manifests as well as JavaScript style and lint,
"all" to build node and npm and then use that npm to rebuild local dependencies,
"clean" to remove built files, and so on.

See the top-level Makefile in eng.git for the complete details.


# Software development process

Team synchronization begins daily with our morning scrum. We use continuous
integration with GitHub and Jenkins. Bugs and feature requests are tracked in
Jira. For more details on Joyent's morning scrum please read the: [Onboarding
Guide](https://mo.joyent.com/docs/engdoc/master/engguide/onboard.html#scrum).

In general, process is shrink-to-fit: we adopt process that help us work better,
but process for process's sake is avoided. Any resemblance to formalized
methodologies, living or dead, is purely coincidental.

# Security Statement and Best Practices

Joyent Engineering makes security a top priority for all of our projects. All engineering work is expected to follow industry best practices. New changes affecting security are reviewed by a developer other than the person who wrote the new code. Both developers test that these changes are not vulnerable to the OWASP top 10 security, pass PCI DSS, and are safe.

Common vulnerabilities to watch out for:

- Prevent code injection
- Buffer overflow. Truncate strings at their maximum length.
- Encrypt all sensitive data over HTTPS.
- Do not leak sensitive data into error logs.
- Block cross-site-scripting(XSS) by specifically validating input and auto-escaping HTML template output.
- Wrap all routes in security checks to verify user passes ACLs.
- Prevent cross-site-request-forgery(CSRF)

## Production code deployment process

For the Joyent Public Cloud, Jira change tickets should include the following before the code is promoted to production:

- Description of the change's impact
- Record of approval by authorized stake holders
- Confirmation of the code's functionality and proof that vulnerablity testing was performed. A log or screenshot from a security scanner is sufficient
- Steps to undo this change if necessary.

For reference, read the [owasp top 10](https://www.owasp.org/index.php/Category:OWASP_Top_Ten_Project) vulnerabilities.

# Community Interaction

Due to the open source nature of Joyent software, community interaction is very
important.

There are mailing lists and IRC channels for top-level Joyent projects (Triton,
Manta, SmartOS). In addition to using these channels for assisting community
members with developing and using Joyent products, they are useful for notifying
the community of major changes.

## Flag Day and Heads Up Notifications

A flag day change is a change that makes a service or tool incompatible with
another service or tool. Flag day changes can result in complicated operational
procedures to ensure dependent services and tools are updated in lock step.
An example would be changing Manta's Muskie to communicate over the Gopher
protocol instead of HTTP. All of the existing client software would have to be
redeployed to a version supporting the Gopher protocol at the exact same time
Muskie is updated.

Flag days should be avoided, but sometimes they are necessary. It is important
to notify the community as soon as flag day changes are integrated. For changes
that require attention, but are not flag days, a heads up email should be sent.
In either case, the message must be sent to the relevant public distribution
lists (e.g. sdc-discuss).

For heads up notifications, the subject line should include '[HEADS-UP]' and a
brief summary of what has changed.

For flag day notifications, the subject line should include '[FLAG-DAY]' and a
list of components effected by the flag day.

The body of each message should start with a statement describing who
may safely ignore the message. This should be followed by a brief description
of the change that was integrated and a ticket for the change.

Heads up notifications may optionally include information describing what will
happen if no action is taken.

Flag day notifications should also include or link to instructions for how to
successfully complete the flag day upgrade.

Here is an example of a flag day email:

```
Subject: [FLAG-DAY] OS-4498 (illumos-joyent and smartos-live)
Body:
Hi folks,

If you are not building your own SmartOS (or SDC) platform images,
you can ignore this mail.

I just put back OS-4498. This slightly changes the behaviour of
"custr_cstr()" from "libcmdutils.so.1" in the OS, so if you are
updating your copy of "smartos-live" you should first update your
"illumos-joyent".
```

Here is an example of a heads up email:

```
Subject: [HEADS-UP] storage zone CPU shares
Body:
I've pushed the change for:
MANTA-1573 mako should have larger shares than marlin compute zones

This increases the cpu_shares allotted for storage zones, which can improve
download/upload performance when the system is saturated with compute jobs
(at the potential expense of the compute jobs).  This change only affects new
deployments.  If you want to apply it to an existing Manta deployment, you'll
want to do something like this for each "storage" zone in your fleet:

    vmadm update $zone_uuid cpu_shares=2048

You should probably also update the Manta SAPI application so that subsequent
storage zone deployments get the updated value.  That will be something like
this:

    echo '{ "params": { "cpu_shares": 2048 } }' | \
        sapiadm update $uuid

where $uuid is the uuid of the "storage" SAPI service.
```

# Miscellaneous Best Practices

- Use JSON for config data. Not ini files: iniparser module has bugs, there
  are always questions about encoding non-string values.
- For services and distributed systems, consider building rich tools to
  understand the state of the service, like lists of the service's objects and
  information about each one. Think of the SmartOS proc(1) tools (see man pages
  for pgrep, pstack, pfiles, pargs).
- Consider doing development inside a SmartOS zone rather than on your Macbook
  or a CoaL global zone. That forces us to use our product the way customers
  might, and it eliminates classes of problems where the dev environment doesn't
  match production (e.g., because you've inadvertently picked up a
  globally-installed library instead of checking it in, or resource limits
  differ between MacOS and a SmartOS zone.
- Whether you develop in CoaL or on your Macbook, document what's necessary to
  get from scratch to a working development environment so that other people can
  try it out. Ideally, automate it. Having a script is especially useful if you
  do develop on CoaL, which also forces you to keep it up to date.
- Similarly, build tools to automate deploying bits to a test system (usually a
  SmartOS headnode zone). The easier it is to test the actual deployment, the
  more likely people will actually test that, and you'll catch environment
  issues in development instead of after pushing.


# Examples

- The [boilerplate API](./boilerplateapi.html) example in this repo gives you a
  starter file and some suggestions on how to document a web service.

---

<a name="footnote1">[1]</a> : Why? I don't know, but this was enough to convince me to stop
worrying about it [80-characters line length limit in 2017 (and
later)](http://katafrakt.me/2017/09/16/80-characters-line-length-limit/)

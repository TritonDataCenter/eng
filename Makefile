#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#
# Copyright (c) 2017, Joyent, Inc.
#

#
# Makefile: annotated sample Makefile using eng.git Makefile system
#
# The eng.git repository contains a system of Makefile components that provide
# pluggable Makefile functionality (the way is typically done for other
# programming environments, but isn't commonly done for Makefiles).  Makefiles
# defined in this repository generate targets for:
#
#     * building the current repository as an npm package
#     * checking syntax and style for JavaScript, JSON, bash files,
#       and SMF manifests
#     * generating API documentation from restdown sources
#     * generating manual pages from Markdown sources
#     * building a copy of Node with this repository
#     * loading a prebuilt copy of Node in this repository
#     * fetching git submodules as they are needed
#
# This top-level Makefile is both a sample Makefile for new repositories and
# a demo for how to use each of the Makefile components here.  If you find this
# comment in a Makefile outside of eng.git, that's a bug and should be fixed.
# Repos are expected to completely rewrite this file (possibly using it as a
# template).
#
# Writing new Makefile components is not hard, but requires thinking through how
# they may need to be customized.  Here are some guidelines:
#
#     * "Callers" (top-level Makefiles) should be able to use Makefile
#       components by setting specific Make variables ("input variables" for the
#       component) and then including the Makefile.  The component works by
#       defining output variables and (optionally) targets. See existing
#       components for examples.  Document clearly the input and output
#       variables for each new Makefile component.
#
#     * Most components actually consist of two files: a "defs" file that
#       consumes input variables and produces output variables, and a separate
#       "targ" file that defines targets.  Consumers include the "defs" Makefile
#       towards the top of their Makefile, before they've defined their own
#       repo-specific targets.  If components define targets at this point,
#       they'd become default targets, and can also lead to dependency problems.
#       Consumers include the "targ" Makefile after all definitions have been
#       made.
#
#     * Usually, a component should not define phony top-level targets (like
#       "check" or "manpages").  Instead, just define variables (like
#       MY_COMPONENTS_CHECK_TARGETS or MAN_OUTPUTS) that the caller can use to
#       trivially define such a target themselves.
#
#     * If you want to be able to use this Makefile more than once (e.g., with
#       different parameters), that's possible, but tricky.  See
#       Makefile.manpages.{defs,targ} for an example.
#

#
# IMPORTANT: This sample Makefile should consist solely of repo-specific
# configuration, plus "include" directives for the common Makefile components,
# plus trivial, repo-specific targets.  Repo-specific targets and recipes are
# okay, but generic targets and recipes do NOT belong here.  If you find
# yourself wanting to add support for new targets here, you should add them to a
# new or existing pluggable Makefile component, document it clearly, and include
# that Makefile here.
#

#
# Tools
#
TAPE :=			./node_modules/.bin/tape

#
# Makefile.defs defines variables used as part of the build process.
#
include ./tools/mk/Makefile.defs

#
# Configuration used by Makefile.defs and Makefile.targ to generate
# "check" and "docs" targets.
#
DOC_FILES =		index.md boilerplateapi.md
JSON_FILES =		package.json
JS_FILES :=		$(shell find lib test -name '*.js') tools/bashstyle
JSL_FILES_NODE =	$(JS_FILES)
JSSTYLE_FILES =		$(JS_FILES)

JSL_CONF_NODE =		tools/jsl.node.conf
JSSTYLE_FLAGS =		-f tools/jsstyle.conf

#
# Configuration used by Makefile.smf.defs to generate "check" and "all" targets
# for SMF manifest files.
#
SMF_MANIFESTS_IN =	smf/manifests/bapi.xml.in
include ./tools/mk/Makefile.smf.defs

#
# Historically, Node packages that make use of binary add-ons must ship their
# own Node built with the same compiler, compiler options, and Node version that
# the add-on was built with.  On SmartOS systems, we use prebuilt Node images
# via Makefile.node_prebuilt.defs.  On other systems, we build our own Node
# binary as part of the build process.  Other options are possible -- it depends
# on the need of your repository.
#
NODE_PREBUILT_VERSION =	v4.8.4
ifeq ($(shell uname -s),SunOS)
	NODE_PREBUILT_TAG = zone
	include ./tools/mk/Makefile.node_prebuilt.defs
else
	include ./tools/mk/Makefile.node.defs
endif

#
# Makefile.node_modules.defs provides a common target for installing modules
# with NPM from a dependency specification in a "package.json" file.  By
# including this Makefile, we can depend on $(STAMP_NODE_MODULES) to drive "npm
# install" correctly.
#
include ./tools/mk/Makefile.node_modules.defs

#
# Configuration used by Makefile.manpages.defs to generate manual pages.
# See that Makefile for details.  MAN_SECTION must be eagerly defined (with
# ":="), but the Makefile can be used multiple times to build manual pages for
# different sections.
#
MAN_INROOT =		docs/man
MAN_OUTROOT =		man
CLEAN_FILES +=		$(MAN_OUTROOT)

MAN_SECTION :=		1
include tools/mk/Makefile.manpages.defs
MAN_SECTION :=		3bapi
include tools/mk/Makefile.manpages.defs


#
# Repo-specific targets
#
.PHONY: all
all: $(SMF_MANIFESTS) $(STAMP_NODE_MODULES) | $(REPO_DEPS)

#
# This example Makefile defines a special target for building manual pages.  You
# may want to make these dependencies part of "all" instead.
#
.PHONY: manpages
manpages: $(MAN_OUTPUTS)

.PHONY: test
test: $(STAMP_NODE_MODULES)
	$(NODE) $(TAPE) test/*.test.js


#
# Target definitions.  This is where we include the target Makefiles for
# the "defs" Makefiles we included above.
#

include ./tools/mk/Makefile.deps

ifeq ($(shell uname -s),SunOS)
	include ./tools/mk/Makefile.node_prebuilt.targ
else
	include ./tools/mk/Makefile.node.targ
endif

MAN_SECTION :=		1
include tools/mk/Makefile.manpages.targ
MAN_SECTION :=		3bapi
include tools/mk/Makefile.manpages.targ

include ./tools/mk/Makefile.smf.targ
include ./tools/mk/Makefile.node_modules.targ
include ./tools/mk/Makefile.targ

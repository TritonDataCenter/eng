#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#
# Copyright (c) 2019, Joyent, Inc.
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
# If a project produces a SmartOS image for use in Triton or Manta, the name of
# the image should be specified here. Additional metadata for the image can be
# set using BUILDIMAGE_* macros.
#
NAME = myproject

#
# Tools
#
TAPE :=			./node_modules/.bin/tape

#
# If we need to use buildimage, make sure we declare that before including
# Makefile.defs since that conditionally sets macros based on
# ENGBLD_USE_BUILDIMAGE.
#
ENGBLD_USE_BUILDIMAGE   = true

#
# Makefile.defs defines variables used as part of the build process.
# Ensure we have the eng submodule before attempting to include it.
#
ENGBLD_REQUIRE          := $(shell git submodule update --init deps/eng)
include ./deps/eng/tools/mk/Makefile.defs
TOP ?= $(error Unable to access eng.git submodule Makefiles.)

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
include ./deps/eng/tools/mk/Makefile.smf.defs

#
# Historically, Node packages that make use of binary add-ons must ship their
# own Node built with the same compiler, compiler options, and Node version that
# the add-on was built with.  On SmartOS systems, we use prebuilt Node images
# via Makefile.node_prebuilt.defs.  On other systems, we build our own Node
# binary as part of the build process.  Other options are possible -- it depends
# on the need of your repository.
#
NODE_PREBUILT_VERSION =	v4.9.0
ifeq ($(shell uname -s),SunOS)
	NODE_PREBUILT_TAG = zone
	include ./deps/eng/tools/mk/Makefile.node_prebuilt.defs
else
	include ./deps/eng/tools/mk/Makefile.node.defs
endif

#
# If a project needs to include Triton/Manta agents as part of its image,
# include Makefile.agent_prebuilt.defs and define an AGENTS macro to specify
# which agents are required.
#
include ./deps/eng/tools/mk/Makefile.agent_prebuilt.defs


#
# If a project includes some components written in the Go language, the Go
# toolchain will need to be available on the build machine.  At present, the
# Makefile library only handles obtaining a toolchain for SmartOS systems.
#
ifeq ($(shell uname -s),SunOS)
	GO_PREBUILT_VERSION =	1.9.2
	GO_TARGETS =		$(STAMP_GO_TOOLCHAIN)
	GO_TEST_TARGETS =	test_go
	include ./deps/eng/tools/mk/Makefile.go_prebuilt.defs
endif

ifeq ($(shell uname -s),SunOS)
	CTF_TARGETS =		helloctf
	CTF_TEST_TARGETS =	test_ctf
	include ./tools/mk/Makefile.ctf.defs
endif

#
# Makefile.node_modules.defs provides a common target for installing modules
# with NPM from a dependency specification in a "package.json" file.  By
# including this Makefile, we can depend on $(STAMP_NODE_MODULES) to drive "npm
# install" correctly.
#
include ./deps/eng/tools/mk/Makefile.node_modules.defs

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
include ./deps/eng/tools/mk/Makefile.manpages.defs
MAN_SECTION :=		3bapi
include ./deps/eng/tools/mk/Makefile.manpages.defs

#
# If a project produces a SmartOS image for use in Manta/Triton, the build
# should produce a tarball containing the components built from this workspace,
# including any node_modules imported along with the build of node itself
# (either built locally or prebuilt)
#
RELEASE_TARBALL = $(NAME)-pkg-$(STAMP).tar.gz

#
# To support the 'buildimage' target in Makefile.targ, metadata required for the
# image should be set here.
#

# This image is triton-origin-multiarch-15.4.1
BASE_IMAGE_UUID = 04a48d7d-6bb5-4e83-8c3b-e60a99e0f48f
BUILDIMAGE_NAME = manta-myproject
BUILDIMAGE_DESC	= My Project Has A Description
AGENTS          = amon config registrar
BUILDIMAGE_PKGSRC = foobar-42 ook-1.0.1b cheese-0.4cheddar
#
# The default image contents are set to $(TOP)/$(RELEASE_TARBALL)
# in Makefile.targ. To override those, set $(BUILDIMAGE_PKG) to the
# full path of the required tarball.
#
# BUILDIMAGE_PKG=$(TOP)/bar/mytarball.tar.gz
#

#
# Set for buildimage to have pkgin update and full-upgrade before installing
# BUILDIMAGE_PKGSRC packages.
#
# BUILDIMAGE_DO_PKGSRC_UPGRADE=true

#
# Repo-specific targets
#
.PHONY: all
all: $(SMF_MANIFESTS) $(STAMP_NODE_MODULES) $(GO_TARGETS) | $(REPO_DEPS)

#
# If a project produces a SmartOS image for use in Manta/Triton, a release
# target should construct the RELEASE_TARBALL file
#
.PHONY: release
release:
	echo "Do work here"
#
# This example Makefile defines a special target for building manual pages.  You
# may want to make these dependencies part of "all" instead.
#
.PHONY: manpages
manpages: $(MAN_OUTPUTS)

.PHONY: test
test: $(STAMP_NODE_MODULES) $(GO_TEST_TARGETS) $(TEST_CTF_TARGETS)
	$(NODE) $(TAPE) test/*.test.js

#
# This test demonstrates a basic use of the project-local Go toolchain.
#
.PHONY: test_go
test_go: $(STAMP_GO_TOOLCHAIN)
	@$(GO) version
	$(GO) run src/tellmewhereto.go

HELLOCTF_OBJS =		helloctf.o
HELLOCTF_CFLAGS =	-gdwarf-2 -m64 -std=c99 -D__EXTENSIONS__ \
			-Wall -Wextra -Werror \
			-Wno-unused-parameter \
			-Isrc/
HELLOCTF_OBJDIR =	$(CACHE_DIR)/helloctf.obj

helloctf: $(HELLOCTF_OBJS:%=$(HELLOCTF_OBJDIR)/%) $(STAMP_CTF_TOOLS)
	gcc -o $@ $(HELLOCTF_OBJS:%=$(HELLOCTF_OBJDIR)/%) $(HELLOCTF_CFLAGS)
	$(CTFCONVERT) -l $@ $@

$(HELLOCTF_OBJDIR)/%.o: src/%.c
	@mkdir -p $(@D)
	gcc -o $@ -c $(HELLOCTF_CFLAGS) $<

CLEAN_FILES += $(HELLOCTF_OBJDIR) helloctf

.PHONY: test_ctf
test_ctf: helloctf $(STAMP_CTF_TOOLS)
	src/testctf.sh $(CTFDUMP) ./helloctf

#
# Target definitions.  This is where we include the target Makefiles for
# the "defs" Makefiles we included above.
#

include ./deps/eng/tools/mk/Makefile.deps

ifeq ($(shell uname -s),SunOS)
	include ./deps/eng/tools/mk/Makefile.node_prebuilt.targ
	include ./deps/eng/tools/mk/Makefile.go_prebuilt.targ
	include ./deps/eng/tools/mk/Makefile.agent_prebuilt.targ
else
	include ./deps/eng/tools/mk/Makefile.node.targ
endif

MAN_SECTION :=		1
include ./deps/eng/tools/mk/Makefile.manpages.targ
MAN_SECTION :=		3bapi
include ./deps/eng/tools/mk/Makefile.manpages.targ

include ./deps/eng/tools/mk/Makefile.smf.targ
include ./deps/eng/tools/mk/Makefile.node_modules.targ
include ./deps/eng/tools/mk/Makefile.ctf.targ
include ./deps/eng/tools/mk/Makefile.targ

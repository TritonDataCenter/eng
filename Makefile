#
# Makefile: basic Makefile for template API service
#

#
# Directories
#
TOP		:= $(shell pwd)

#
# Tools
#
NPM		:= npm
TAP		:= $(TOP)/node_modules/.bin/tap

#
# Files: most of these are used as input for targets in Makefile.targ, which
# provides check, docs, and other targets for these files. See Makefile.targ
# for details, as well as other targets for checking bash scripts, SMF
# manifests, etc.
#
DOC_FILES	 = docs/index.restdown
JS_FILES	:= $(shell find lib -name '*.js')
JSL_CONF_NODE	 = tools/jsl.node.conf
JSL_FILES_NODE   = server.js $(JS_FILES)
JSSTYLE_FILES	 = $(JS_FILES)
# XXX SMF manifests and methods

#
# Targets
#
.PHONY: all
all:
	$(NPM) install

.PHONY: test
test: $(TAP)
	TAP=1 $(TAP) test/*.test.js

include ./Makefile.deps
include ./Makefile.targ

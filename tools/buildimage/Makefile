#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#
# Copyright (c) 2019, Joyent, Inc.
#

#
# This Makefile contains targets to npm install the dependencies for
# buildimage and the private copy of imgadm it requires. We expect
# that the main eng.git/tools/mk/Makefile.targ 'stamp-buildimage-prep'
# will invoke these targets.
#

#
# This is the expected location of the modern pkgsrc bootstrap,
# currently bootstrap-2018Q3-tools.tar.gz
#
BUILD_TOOLS = /opt/tools


IMGADM_CC = CC=$(BUILD_TOOLS)/bin/gcc
IMGADM_CXX = CXX=$(BUILD_TOOLS)/bin/g++
IMGADM_CTF = CTFCONVERT=/bin/true CTFMERGE=/bin/true

# This is a little ugly. We're piggy-backing on OPT_FLAGS
# so that we can pass in a specific include dir since otherwise
# v8plus (an imgadm dependency) expects to see it in
# $(BUILD_TOOLS)/include/node.
IMGADM_INC = OPT_FLAGS=-O2 OPT_FLAGS+=-I$(BUILD_TOOLS)/include

# Similarly, we have no way to pass LDFLAGS to v8plus, so use
# NODE_LIBDIR instead.
IMGADM_LIB = NODE_LIBDIR+=-L$(BUILD_TOOLS)/node/lib \
             NODE_LIBDIR+=-L$(BUILD_TOOLS)/lib NODE_LIBDIR+=-luv

IMGADM_FLAGS = MAKE_OVERRIDES='$(IMGADM_CC) $(IMGADM_CXX) $(IMGADM_CTF) $(IMGADM_INC) $(IMGADM_LIB)'


buildimage-prep: imgadm-prep
	rm -rf node_modules; \
	PATH=$(BUILD_TOOLS)/bin:$$PATH $(BUILD_TOOLS)/bin/npm \
	    --unsafe-perm \
	    --scripts-prepend-node-path=true install

imgadm-prep:
	rm -rf lib/imgadm/node_modules
	cd lib/imgadm; \
	$(IMGADM_FLAGS) $(BUILD_TOOLS)/bin/npm \
	    --unsafe-perm --scripts-prepend-node-path=true install


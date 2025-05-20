#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#
# Copyright (c) 2019, Joyent, Inc.
# Copyright (c) 2025 MNX Cloud, Inc.
#

#
# This Makefile contains targets to npm install the dependencies for
# buildimage and the private copy of imgadm it requires. We expect
# that the main eng.git/tools/mk/Makefile.targ 'stamp-buildimage-prep'
# will invoke these targets.
#

BUILD_TOOLS = /opt/local

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

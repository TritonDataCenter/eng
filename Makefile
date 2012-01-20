
#
# Config
#

# Directories
TOP := $(shell pwd)

# Tools
TAP := $(TOP)/node_modules/.bin/tap
RESTDOWN := python2.6 $(TOP)/deps/restdown/bin/restdown
NPM := npm



#
# Targets
#

.PHONY: all
all:
	$(NPM) install


.PHONY: docs
docs:
	$(RESTDOWN) -m docs docs/index.restdown

.PHONY: test
test: $(TAP)
	TAP=1 $(TAP) test/*.test.js

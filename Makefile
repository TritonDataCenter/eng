
#
# Config
#

# Directories
TOP := $(shell pwd)

# Tools
TAP := $(TOP)/node_modules/.bin/tap
NPM := npm



#
# Targets
#

.PHONY: all
all:
	$(NPM) install


.PHONY: test
test: $(TAP)
	TAP=1 $(TAP) test/*.test.js

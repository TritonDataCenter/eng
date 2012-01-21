
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
# Files
#
DOC_SRCS = index guide
DOC_HTML = $(DOC_SRCS:%=docs/%.html)
DOC_JSON = $(DOC_SRCS:%=docs/%.json)

#
# Targets
#

.PHONY: all
all:
	$(NPM) install


.PHONY: docs
docs: $(DOC_HTML)

docs/%.html: docs/%.restdown
	$(RESTDOWN) -m docs $^


.PHONY: test
test: $(TAP)
	TAP=1 $(TAP) test/*.test.js

clean:
	-rm -f $(DOC_HTML) $(DOC_JSON)

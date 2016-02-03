# BAPIADM 1 "2016" SDC "SDC Operator Commands"

## NAME

bapiadm - manage the fake Boilerplate API

## SYNOPSIS

`bapiadm show [-H] [-o] FILTER`

`bapiadm frobnicate FILTER`

## DESCRIPTION

The `bapiadm` tool is used to administer the Boilerplate API.  This is a fake
tool for a fake API to demo manpages targets.

## OPTIONS

`-H, --omit-header`
  Describe option here.

## EXAMPLES

**Show BAPI objects**:

    $ bapiadm show
    BAPI OBJECTS!

**Frobnicate a BAPI object:**

    $ bapiadm frobnicate all
    FROBNICATED!


## EXIT STATUS

`0`
  Success

`1`
  Generic failure.

`2`
  The command-line options were not valid.


## ENVIRONMENT

`LOG_LEVEL`
  If present, this must be a valid node-bunyan log level name (e.g., "warn").
  The internal logger will use this log level and emit output to `stderr`.  This
  option is subject to change at any time.


## COPYRIGHT

Copyright (c) 2016 Joyent Inc.


## SEE ALSO

json(1), node-bapi(3bapi)

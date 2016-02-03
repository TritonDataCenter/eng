# BAPI 3BAPI "2016" SDC "SDC Libraries"

## NAME

node-bapi - manage BAPI objects programmatically
bapiadm - manage the fake Boilerplate API

## SYNOPSIS

`var mod_bapi = require('bapi');`
`var bapi = mod_bapi.createBapi();`
`bapi.frobnicate();`

## DESCRIPTION

The `bapi` Node module provides functions for administering BAPI objects from
Node programs.  This is a fake module for a fake API to demo manpages targets.

## RETURN VALUES

`mod_bapi.createBapi()` returns a `BapiClient`, which is an EventEmitter.

## ERRORS

Creating a BAPI client always succeeds.  The client may emit `error` in the
event of an operational error that prevents forward progress.  No additional
events will be emitted after `error`, and any open resources will be closed.
Operational errors include:

* failure to resolve the DNS name of the BAPI server
* failure to connect to the BAPI server


## EXAMPLES

Some examples would be nice.


## COPYRIGHT

Copyright (c) 2016 Joyent Inc.


## SEE ALSO

json(1), bapiadm(1)

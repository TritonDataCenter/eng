#!/bin/bash
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#
# Copyright (c) 2018, Joyent, Inc.
#
CTFDUMP=$1
BINARY=$2

function fatal {
	local LNOW=`date`
	echo "$LNOW: $(basename $0): fatal error: $*" >&2
	exit 1
}

if [[ ! -f $BINARY ]]; then
	fatal "Unable to find binary: $BINARY."
fi

if [[ ! -f $CTFDUMP ]]; then
	fatal "Unable to find ctfdump at: $CTFDUMP."
fi

#
# Ensure that the target binary contains CTF data.
#
if ! out=$("$CTFDUMP" "$BINARY"); then
	fatal "Unable to dump CTF information from $BINARY"
fi

#
# In particular, ensure that it contains information on `struct ctf_proto'.
#
if ! grep '> struct ctf_proto (' <<< "$out"; then
	fatal "$BINARY CTF did not contain expected type"
fi

#!/bin/bash
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#
# Copyright (c) 2019, Joyent, Inc.
#

#
# This script simply extracts the .tar.gz or .tar.bz package given as $1 to the
# current directory.
#

ARCHIVE=$1

# Uncomment this for debugging.
# VERBOSE=v

case $ARCHIVE in
    *tar.bz2|*.tar.bz)
        TAR_ARGS="jx${VERBOSE}f"
        ;;
    *.tar.gz|*.tgz)
        TAR_ARGS="zx${VERBOSE}f"
        ;;
    *)
        echo "Error: buildimage-extract-pkg: Unknown archive file $ARCHIVE"
        exit 1
esac

gtar ${TAR_ARGS} $ARCHIVE
exit $?

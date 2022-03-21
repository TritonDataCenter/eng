# imgadm

The initial imgadm import was imgadm from
`smartos-live@c6f5e9955adbc45688074ab1b8cac5d340262c56`, and later updated
to `smartos-live@6e745f02cbe70f29741ecf823cb63376c7434ba7`.

The following modifications were made:

* we should allow running from a non-global zone
* we should not use platform node.js modules like zfs.js
* we should allow the caller to set the default zpool name
* we should allow the use of 'pigz' if it exists to
  create .gz files, falling back to 'gzip' otherwise
* we should attempt to locate a delegated dataset within
   this instance.
* we should use /opt/tools/bin/node instead of platform node

The files from smartos-live.git duplicated in this directory are:

* smartos-live.git:src/img -> this directory
* smartos-live.git:src/node_modules/zfs.js > lib/zfs.js

package.json for this copy of imgadm differs from the smartos-live.git
instance in order to list qlocker as a direct dependency (instead of using it
from the platform) and to pull in modern node-sdc-clients, needed so that
imgadm (via buildimage) can compile using modern versions of node. It's
currently at version 11.3.1, the last version to support dsapi. This can't be
updated until platform imgadm removes support for dsapi.

We also need a more modern bunyan and restify to avoid build errors
in dtrace-provider when compiling with node v6.

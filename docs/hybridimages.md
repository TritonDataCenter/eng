---
title: Triton Hybrid Images
markdown2extras: code-friendly
apisections:
---
<!--
    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
-->

<!--
    Copyright 2020 Joyent, Inc.
    Copyright 2022 MNX Cloud, Inc.
-->

# Joyent Hybrid Images

This document describes the best practices for HVM image creation such that they
are compatible with the QEMU/KVM and bhyve hypervisors on SmartOS.

The key characteristics of a hybrid image are:

- Must be capable of booting from BIOS.  The version of QEMU supported by
  SmartOS does not have UEFI boot support.
- Must be tolerant of disks and other virtual hardware appearing at different
  locations in the device tree, perhaps with different model identifiers, serial
  numbers. etc.
- Must configure networking using the [mdata
  protocol](https://eng.joyent.com/mdata/protocol.html) on the second serial
  port (`ttyS1`, `ttyb`, `COM2`, etc.).
- Should take other actions as described in the [data
  dictionary](https://eng.joyent.com/mdata/datadict.html).
- Should have an administrative port on the first serial port (`ttyS0`, `ttya`,
  `COM1`, etc.).
- Should use virtio block and network devices.


# Creation

The typical hybrid image creation process involves the following steps.

1. Obtain guest OS installation media.
2. Generate an ISO with configuration data.  Depending on the guest OS, this may
   involve remastering the installation media or generating a configuration-only
   image.
3. Create an empty ZFS volume (virtual disk) that is the same size as the
   desired root disk.  If the image requires a disk with its block size other
   than 8 KiB, `volblocksize` must be set when this is being created.  No other
   ZFS properties will be preserved in the generated image.
4. Start a QEMU process that uses the ISO image(s) and virtual disk mentioned
   above.  Ideally, the output of the installer will be directed to a location
   that makes post-mortem debugging easy.  One way to do this is to start QEMU
   in a way that attaches the first serial port to stdio and configure the guest
   installer to verbosely log to that serial port.
5. Wait for the instance to shut itself down, then sanity check the
   installation.  This sanity check likely involves looking for well-known
   markers in the log output described above.
6. Generate an image, which is comprised of a zfs stream and a
   [manifest](https://github.com/joyent/sdc-imgapi/blob/master/docs/index.md#image-manifests).
7. Optionally upload to Manta and/or https://updates.tritondatacenter.com.

The steps described above are generally handled with automation.  Steps 1, 2,
and 5 are specific to the image being created.  Image-specific tools then invoke
[create-hybrid-image](../tools/create-hybrid-image) for the remaining steps.


## Build environment

The image build automation discussed in the sections that flow is designed to
run in a joyent branded zone on a SmartOS compute node.  The CN can be a
standalone instance or part of a Triton cloud.  The CN does require some
configuration that is not supported by Triton or even vmadm.

The key requirements for the build zone are:

- 2.5 GiB or more RAM.  This allows the guest running under QEMU to have 2 GiB.
- A delegated dataset with 30 GiB of available space.
- `/smartdc` needs to be a read-only lofs mount from the global zone
- `/dev/kvm` device needs to be delegated for QEMU hardware acceleration
- `git`, `gpg`, and `mkisofs` need to be installed and in `$PATH`.  If `pigz` is
  available, the image creation will be quicker.

Some images may have additional requirements.

The following script may be used to customize an instance that was created with
`triton instance create`.

```bash
#! /bin/bash

uuid=$1
if [[ -z $uuid ]]; then
	echo "Usage: $0 <uuid>" 1>&2
	exit 1
}
set -euo pipefail

topds=zones/$uuid/data
zfs create -o zoned=on -o mountpoint=/data $topds

zonecfg -z $uuid <<EOF
add dataset
set name=$topds
end
add fs
set dir=/smartdc
set special=/smartds
set type=lofs
set options=ro
end
add device
set match=kvm
end
EOF

zlogin $uuid /opt/local/bin/pkgin update
zlogin $uuid /opt/local/bin/pkgin -y install git gpg cdrtools pigz
vmadm stop $uuid
vmadm start $uuid
```


## Image builds

The following repositories follow the patterns described above.

* [mi-centos-hvm](https://github.com/joyent/mi-centos-hvm) for CentOS 6 - 8
* [mi-debian-hvm](https://github.com/joyent/mi-debian-hvm) for Debian 8 - 10

Each repo is intended to handle a family of distributions.  The mi-centos-hvm
repo probably implements the hard parts required for RHEL, Fedora, and other
RHEL-derived distributions.  Likewise, it should be straight-forward to add
support for Ubuntu to  mi-debian-hvm.

Each of those repositories has this ([eng](https://github.com/joyent/eng)) and
[sdc-vmtools](https://github.com/joyent/sdc-vmtools) as subrepos.  The eng repo
is home to common tools used for building the images and the sdc-vmtools repo
is used for things that are added to the image.

Some images may require software that is specific to the OS version and is
stored elsewhere.  For example, some older versions ship with a version of
cloud-init that is too old to properly support the metadata protocol.  On these
systems, a custom build of cloud-init is stored in Manta and installed via
post-install scripting that is invoked by the guest operating system installer
during image creation.

Each repository is designed to produce images using Jenkins, with the build
steps for each image specified in the `Jenkinsfile` in each repository.


## `create-hybrid-image` script

The [`create-hybrid-image`](../tools/create-hybrid-image) script is typically
invoked by an image-specific `create-image` script that resides in a
`mi-<mumble>-hvm` repository.  See the usage message for details on options that
are supported.


### Who can run `create-hybrid-image`

This script is designed to be able to be run as any user that has the `Primary
Administrator` profile.  Usually it will be invoked as root, who has sufficient
permissions in all but the oddest of circumstances.  To make the script usable
by alice:

```
# usermod -P 'Primary Administrator' alice
```

See `usermod(1M)` and `profiles(1M)` for details.


### `create-hybrid-image` logs serial port to stdout

QEMU is started such that when the guest writes to the first serial port, it
appears on `stdout` of the QEMU process.  Interaction with the guest over the
first serial port is possible.  This is generally fine, as the installer running
in the guest is generally logging its progress to the first serial port.  When
`create-hybrid-image` runs as part of Jenkins job, verbose logging to the serial
port means that the Jenkins console log is likely to be helpful in diagnosing
failures.

If the guest installer performs its own checks and logs the status of those
checks to the first serial port, `stdout` from QEMU then be used by other tools
to confirm that the installation completed properly.  For example, in CentOS
images, the `ks.cfg` `%pre` and `%post` sections are designed to provide the
status of those phases.  The corresponding `create-image` scripts verify that
the expected results are found before calling the image creation successful.

OS installers generally do not log their actions to the console very verbosely.
To get verbose logs, some form a pre-install script (e.g. `%pre` in `ks.cfg` for
CentOS) is used to tail log files in the background.  When GNU tail is used in a
Linux guest, this may be done with:

```
tail -F foo.log bar.log ... >/dev/ttyS0 2>&1 </dev/null &
```

The `-F` option is used to ask `tail` to watch for logs to come into existence,
and reopen them when they are rotated.  This allows you to start tailing a log
before it exists.  The redirection of `stderr` and `stdin` are primarily to make
it so that `tail` closes all the file descriptors passed to it by its parent
process.  Without this, some installers will think that the script is intended
to complete before the pre-installation script finishes and will cause the
installation to hang forever.


### `create-hybrid-image` provides console via VNC

QEMU is started so that the graphical console is available over VNC.  The ip and
port are shown on the terminal.  Generally, there is no need to connect to the
graphical console.  However, in the event of a failure it is often helpful to
connect to the console to poke around inside a VM using a shell.  Most Linux
distributions have virtual consoles available with `ctrl-alt-F{1,2,3}`.

**WARNING**: The VNC port is accessible via all interfaces.  If the instance has
an interface on an untrusted network, use of Cloud Firewall to restrict access
to TCP port 5901 is is highly recommended.


### `create-hybrid-image` Private guest network

QEMU networking is configured such that a network that a private network exists
within the QEMU process.  QEMU intercepts DHCP requests and provides basic
networking configuration to the guest.  This network has access to other
networks that are accessible by the zone via a NAT implementation that exists
within QEMU.


### `create-hybrid-image` arbitrary QEMU arguments

When an image-specific `create-image` script needs to add additional devices,
have specialized control over the boot loader, etc., additional arguments can be
specified on the command line.

A key example of how this is used is in the [CentOS
images](https://github.com/joyent/mi-centos-hvm/blob/master/create-image).Rather
than remastering the image to add the appropriate boot options, the installation
media is mounted in the host and QEMU is started with options that specify the
kernel, initrd, kernel command line, and a secondary CD which contains the
kickstart configuration.  This allows the CentOS `create-image` to avoid
gigabytes of I/O that would otherwise be required to remaster the installer ISO.

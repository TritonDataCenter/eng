# buildimage (nee Buildy McBuildface)

## What in the world is this?

This directory contains build tools to speed up Triton service image builds.
To understand this speed up, one needs to understand how builds work
without/prior to this.

When building an image the process is (only including steps relevant to speed-up
here):

 * Select a jenkins agent (running a jenkins-agent image) with the appropriate
   image (must use the same architecture and pkgsrc as the underlying image that
   the Triton service will use).
 * Checkout the appropriate version of the service's code.
 * Do an `npm install` to non-reproducibly populate the `node_modules` directory
   with the appropriate modules and binaries (add-ons like dtrace-provider).
 * Build a proto directory which includes the source code from the repo, the
   `node_modules` directory and some other bits.
 * Have MG install the sdcnode build, and some other content (config-agent,
   registrar, etc.) into the build.
 * Tar up the proto directory.
 * Determine a package to use to provision a temporary VM in JPC.
 * Create a temporary VM in JPC using the target image
   (e.g. sdc-multiarch-15.4.1) and the package determined above.
 * Wait (up to 30 minutes) for the VM to be created then;
 * Unpack the proto tarball into the root directory of the VM.
 * Install the pkgsrc packages that the service defines.
 * Cleanup junk left behind from booting the VM.
 * Use sdc-createimagefrommachine to use cloudapi to create an image out of the
   temporary JPC VM.
 * Wait (up to 10 minutes) for the image creation to complete.
 * Delete the temporary JPC VM.
 * Download the created image and manifest from Manta.
 * Modify the manifest of the created manifest.
 * Push the updated manifest to manta.
 * Delete the temporary VM image from JPC.
 * Use the image and manifest (e.g. upload to updates.tritondatacenter.com)

With the tools here, the process is intended to change to:

 * Select a jenkins agent (running a jenkins-agent image) with the appropriate
   image (must use the same architecture and pkgsrc as the underlying image that
   the Triton service will use). This agent must have a delegated dataset.
 * Checkout the appropriate version of the service's code.
 * Do an `npm install` to non-reproducibly populate the `node_modules` directory
   with the appropriate modules and binaries (add-ons like dtrace-provider).
 * Build a proto directory which includes the source code from the repo, the
   `node_modules` directory, the sdcnode build, and all the required bloatware.
 * Run the bin/buildimage tool to:
     * Import the target image into the delegated dataset under
       `zones/<vm_uuid>/data/<image_uuid>`.
     * Create a "zone analog" dataset by cloning the image.
     * Use rsync to copy from the proto directory to the zone analog dataset.
     * Chroot into the zone analog dataset and run pkg_add to install the
       packages.
     * Cleanup any cruft left behind by pkgsrc.
     * Use the imgadm image creation logic to create an image from the zone
       analog using manifest parameters passed in.
     * Delete the zone analog dataset.
 * Use the image and manifest (e.g. upload to manta and update
   updates.tritondatacenter.com with the image)

The reasons this is much faster and more reliable include:

 * We can skip tarring up the proto directory and sending over the network.
 * All build operations take place within the jenkins agent zone. No VMs need
   to be provisioned.
 * We don't need to wait on VM creation.
 * We don't need to cleanup junk left behind by booting the VM since the VM is
   never booted.
 * We don't need to wait on image creation.
 * We don't need to download the image and manifest, or push the modified
   manifest. (Since they were built locally).
 * MG is no longer needed so the total amount of code involved is reduced.

With experiments done so far, this offers drastic improvements in image creation
times. It also should be more reliable since there are far fewer moving parts
and fewer external dependencies.

## Where did the name come from?

The previous name, 'buildymcbuildface' was a homage to the great [Boaty
Mcboatface](https://en.wikipedia.org/wiki/Boaty_McBoatface). At the time the
name was chosen, "buildymcbuildface" also had no Google results. Being unable
to explain 'buildymcbuildface' with a straight face, we renamed it "buildimage",
because that's what it does.

## How do I try to use it?

You will probably never need to - we integrated it into its own 'buildimage'
target in eng.git/tools/mk/Makefile.targ so it ought to "Just Work", with the
appropriate Makefile definitions.

See the 'buildimage' target in eng.git/tools/mk/Makefile.targ

## Does it come with a warranty?

No.

## What's going on with lib/imgadm?

This tool uses imgadm but unfortunately it needs to run on ancient platforms. As
such, it needs to include imgadm. Even more unfortunately, it's tricky to
get this to work properly with npm because imgadm ships its node modules in
smartos-live.git.

In turn, imgadm.js requires files in /usr/img/lib and from the platform install
of node, e.g. /usr/node/node_modules/zfs.js.

Our solution for now, is to pull those from the platform and modify our
bundled imgadm code to use its private copies. We also need to jump through
a few hoops during the build to allow use of the /opt/tools toolchain,
including node v6 and more modern compilers. This results in some ugly
compiler flags in buildimage's Makefile. Apologies for those.

At some point in the future, it might be nice to pull imgadm out from
smartos-live and have it be a proper npm module. At that point we could just add
it to our package.json here and point to a version with these changes,
freeing us up from this runtime restriction.

See lib/imgadm/README.md for details on the version of imgadm we use.

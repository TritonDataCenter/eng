#!/bin/bash
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#
# Copyright 2020 Joyent, Inc.
#

#
# Check if the current build machine is supported for building this component
# and that the build environment seems sane.
#
# Most Joyent software is built using a common build environment described in
# https://github.com/joyent/triton/blob/master/docs/developer-guide/build-zone-setup.md.
# The quickest path to having a sane build environment likely involves following
# that document.
#
# Ideally, rather than checking the sanity of any random shell environment,
# we'd have a way to fully specify the build environment, sanitizing it so that
# only specific user-set environment variables are allowed. That is not done
# here.
#
# This is specifically a bash script because we're using its associative array
# support.
#
# Meant to be run from the top level of a git repository before commencing a
# build. It checks the following:
#
# - the pkgsrc version is compatible with one derived from $NODE_PREBUILT_IMAGE
#   or $BASE_IMAGE_UUID
# - our devzone has a delegated dataset
# - the list of pkgsrc packages match the ones installed on jenkins-agent images
# - the RBAC profiles(1) of the user, looking for 'Primary Administrator' or
#   uid=0
# - the build environment has a $PATH with /opt/local/bin before /usr/bin et al
# - our build platform for this component matches uname -vish
# - several non-pkgsrc programs needed by the build are availabe on the $PATH
# - git submodules for this repository, if present, are up to date
#

#
# For the NODE_PREBUILT_IMAGE checks, we use this list from
# From https://download.joyent.com/pub/build/sdcnode/README.html
# the following images versions are supported:
#
#    sdc-smartos@1.6.3: fd2cc906-8938-11e3-beab-4359c665ac99
#    sdc-minimal-multiarch-lts@15.4.1: 18b094b0-eb01-11e5-80c1-175dac7ddf02
#    triton-origin-multiarch-15.4.1@1.0.1: 04a48d7d-6bb5-4e83-8c3b-e60a99e0f48f
#    minimal-multiarch@18.1.0: 1ad363ec-3b83-11e8-8521-2f68a4a34d5d
#    triton-origin-multiarch-18.1.0: b6ea7cb4-6b90-48c0-99e7-1d34c2895248
#    triton-origin-x86_64-19.4.0:
#
# In the future, we would prefer if the pkgsrc versions were declared
# directly in Makefiles without needing this lookup. (see TOOLS-2038)
#

#
# NOTE If you modify this file, be sure to check that
# jenkins-agent.git:/toolbox/auto-user-script.sh is in sync with the set
# of pkgsrc packages installed per-pkgsrc version. It's not wonderful that
# these lists are duplicated here :-/
#

if [[ -n "$ENGBLD_SKIP_VALIDATE_BUILDENV" ]]; then
    echo "\$ENGBLD_SKIP_VALIDATE_BUILDENV set - not running build environment checks!"
    exit 0
fi

if [[ $(uname -s) != "SunOS" ]]; then
    echo "Only illumos build machines are supported."
    echo "Set \$ENGBLD_SKIP_VALIDATE_BUILDENV in the environment"
    echo "to override this."
    echo "Exiting now."
    exit 1
fi

# Used to cross-check declared NODE_PREBUILT_IMAGE to pkgsrc version.
declare -A PKGSRC_MAP=(
    [fd2cc906-8938-11e3-beab-4359c665ac99]=2011Q4
    [18b094b0-eb01-11e5-80c1-175dac7ddf02]=2015Q4
    [04a48d7d-6bb5-4e83-8c3b-e60a99e0f48f]=2015Q4
    [1ad363ec-3b83-11e8-8521-2f68a4a34d5d]=2018Q1
    [b6ea7cb4-6b90-48c0-99e7-1d34c2895248]=2018Q1
    [c2c31b00-1d60-11e9-9a77-ff9f06554b0f]=2018Q4
    [a9368831-958e-432d-a031-f8ce6768d190]=2018Q4
    [fbda7200-57e7-11e9-bb3a-8b0b548fcc37]=2019Q1
    [cbf116a0-43a5-447c-ad8c-8fa57787351c]=2019Q1
    [7f4d80b4-9d70-11e9-9388-6b41834cbeeb]=2019Q2
    [a0d5f456-ba0f-4b13-bfdc-5e9323837ca7]=2019Q2
    [5417ab20-3156-11ea-8b19-2b66f5e7a439]=2019Q4
    [59ba2e5e-976f-4e09-8aac-a4a7ef0395f5]=2019Q4
)

# Used to provide useful error messages to the user, mapping the
# NODE_PREBUILT_IMAGE uuid to the human-friendly image name.
declare -A SDC_MAP=(
    [fd2cc906-8938-11e3-beab-4359c665ac99]=sdc-smartos@1.6.3
    [18b094b0-eb01-11e5-80c1-175dac7ddf02]=sdc-minimal-multiarch-lts@15.4.1
    [04a48d7d-6bb5-4e83-8c3b-e60a99e0f48f]=triton-origin-multiarch-15.4.1@1.0.1
    [1ad363ec-3b83-11e8-8521-2f68a4a34d5d]=minimal-multiarch@18.1.0
    [b6ea7cb4-6b90-48c0-99e7-1d34c2895248]=triton-origin-multiarch-18.1.0@1.0.1
    [c2c31b00-1d60-11e9-9a77-ff9f06554b0f]=minimal-64-lts@18.4.0
    [a9368831-958e-432d-a031-f8ce6768d190]=triton-origin-x86_64-18.4.0@master-20190410T193647Z-g982b0ce
    [fbda7200-57e7-11e9-bb3a-8b0b548fcc37]=minimal-64@19.1.0
    [cbf116a0-43a5-447c-ad8c-8fa57787351c]=triton-origin-x86_64-19.1.0@master-20190417T143547Z-g119675b
    [7f4d80b4-9d70-11e9-9388-6b41834cbeeb]=minimal-64@19.2.0
    [a0d5f456-ba0f-4b13-bfdc-5e9323837ca7]=triton-origin-x86_64-19.2.0@master-20190919T182250Z-g363e57e
    [5417ab20-3156-11ea-8b19-2b66f5e7a439]=minimal-64-lts@19.4.0
    [59ba2e5e-976f-4e09-8aac-a4a7ef0395f5]=triton-origin-x86_64-19.4.0@master-20200130T200825Z-gbb45b8d
)

# Used to provide useful error messages to the user, mapping the NODE_PREBUILT
# image uuid to a corresponding jenkins-agent image uuid.
# Jenkins agent images are built by https://github.com/joyent/jenkins-agent
declare -A JENKINS_AGENT_MAP=(
    [fd2cc906-8938-11e3-beab-4359c665ac99]=956f365d-2444-4163-ad48-af2f377726e0
    [b4bdc598-8939-11e3-bea4-8341f6861379]=7b1ac281-3fe4-4cf7-858c-2ff73ec64f4e
    [18b094b0-eb01-11e5-80c1-175dac7ddf02]=1356e735-456e-4886-aebd-d6677921694c
    [04a48d7d-6bb5-4e83-8c3b-e60a99e0f48f]=1356e735-456e-4886-aebd-d6677921694c
    [1ad363ec-3b83-11e8-8521-2f68a4a34d5d]=8b297456-1619-4583-8a5a-727082323f77
    [b6ea7cb4-6b90-48c0-99e7-1d34c2895248]=8b297456-1619-4583-8a5a-727082323f77
    [c2c31b00-1d60-11e9-9a77-ff9f06554b0f]=29b70133-1e97-47d9-a4c1-e4b2ee1a1451
    [a9368831-958e-432d-a031-f8ce6768d190]=29b70133-1e97-47d9-a4c1-e4b2ee1a1451
    [fbda7200-57e7-11e9-bb3a-8b0b548fcc37]=fb751f94-3202-461d-b98d-4465560945ec
    [cbf116a0-43a5-447c-ad8c-8fa57787351c]=fb751f94-3202-461d-b98d-4465560945ec
    [7f4d80b4-9d70-11e9-9388-6b41834cbeeb]=c177a02f-5eb7-4dc7-b087-89f86d1f9eec
    [a0d5f456-ba0f-4b13-bfdc-5e9323837ca7]=c177a02f-5eb7-4dc7-b087-89f86d1f9eec
    [5417ab20-3156-11ea-8b19-2b66f5e7a439]=23a48c86-8b59-4629-a2f1-5dac3cba09b1
    [59ba2e5e-976f-4e09-8aac-a4a7ef0395f5]=23a48c86-8b59-4629-a2f1-5dac3cba09b1
)

# For each pkgsrc version, set a list of packages that must be present
PKGSRC_PKGS_2011Q4="
    gcc-compiler
    gcc-runtime
    gcc-tools
    cscope
    gmake
    scmgit-base
    python26
    png
    GeoIP
    GeoLiteCity
    ghostscript
    zookeeper-client
    binutils
    postgresql91-client-9.1.2
    gsharutils
    cdrtools
    coreutils
    pigz"

PKGSRC_PKGS_2015Q4="
    grep
    build-essential
    python27
    py27-expat
    coreutils
    gsed
    gsharutils
    flex
    pcre-8.41
    pigz"

PKGSRC_PKGS_2018Q1="
    grep
    build-essential
    python27
    py27-expat
    coreutils
    gsed
    gsharutils
    flex
    pcre-8.42
    pigz"

PKGSRC_PKGS_2018Q4="
    grep
    build-essential
    python27
    py27-expat
    coreutils
    gsed
    gsharutils
    flex
    pcre-8.42
    pigz"

PKGSRC_PKGS_2019Q1="
    grep
    build-essential
    python27
    py27-expat
    coreutils
    gsed
    gsharutils
    flex
    pcre
    pigz
    rust"

PKGSRC_PKGS_2019Q2="
    grep
    build-essential
    python27
    py27-expat
    coreutils
    gsed
    gsharutils
    flex
    pcre
    pigz
    rust"

PKGSRC_PKGS_2019Q4="
    grep
    build-essential
    python27
    py27-expat
    coreutils
    gsed
    gsharutils
    flex
    pcre
    pigz
    rust"

UPDATES_URL="https://updates.joyent.com?channel=experimental"
UPDATES_IMG_URL="https://updates.joyent.com/images/"

#
# Determine the pkgsrc release of this build machine and the sdcnode prebuilt
# image, as declared by this component's Makefile. These variables get used by
# other functions in this script, globals for now.
#
function get_pkgsrc_sdcnode_versions {

    REQUIRED_IMAGE=$(
        make -s --no-print-directory print-BASE_IMAGE_UUID 2> /dev/null |
            cut -d= -f2)
    PKGSRC_RELEASE=$(
        grep ^release: /etc/pkgsrc_version | cut -d: -f2 | sed -e 's/ //g')

    # If there's no BASE_IMAGE_UUID, use NODE_PREBUILT_IMAGE instead.
    # In either case, what we really want to know is whether this build machine
    # is running software compatible with the runtime that gets used for
    # this component in Triton/Manta. This relies on the special 'print-VAR'
    # target from Makefile.targ
    if [[ -z "$REQUIRED_IMAGE" ]]; then
        REQUIRED_IMAGE=$(
            make -s --no-print-directory \
                print-NODE_PREBUILT_IMAGE 2> /dev/null | cut -d= -f2)
    fi

}

#
# Check that this environment has a $PATH that finds /opt/local/bin before
# /usr/bin, /bin and /opt/tools/bin. This is important for two reasons:
#
# 1. several of the Manta/Triton Makefiles have assumptions on the behaviour
#    of some UNIX utilities that differ between GNU and Illumos variants
#    (e.g. the way cp(1) treats symlinks)
# 2. we compile with gcc 4.9.3 and not yet 7.3.x (which is in /opt/tools)
#
# Eventually, we may want to validate other aspects of the build environment,
# or provide a way for the build to obtain a santized build environment, but
# let's start here, since we know that failing this test definitely breaks
# builds.
#
# Return 0 if it looks like $PATH is correctly set.
#
function validate_build_path {
    echo $PATH | awk '{
        pathlen = split($0, path_arr, ":");
        found_optlocalbin = "false";
        ret = 0;
        for (i = 1; i <= pathlen; i++) {
            if (path_arr[i] == "/opt/local/bin") {
                found_optlocalbin = "true";
                continue;
            }
            if ((path_arr[i] == "/usr/sbin" ||
                    path_arr[i] == "/usr/bin" ||
                    path_arr[i] == "/bin" ||
                    path_arr[i] == "/sbin" ||
                    path_arr[i] == "/opt/tools/bin") &&
                        found_optlocalbin == "false") {
                ret = 1;
                break;
            }
        }
        if (found_optlocalbin == "false")
            ret = 1;

        exit ret;
    }'
    result=$?
    if [[ "$result" -ne 0 ]]; then
        echo "Error: unexpected \$PATH"
        echo ""
        echo "The \$PATH in this shell environment has /bin, /usr/bin, /sbin"
        echo "/usr/sbin or /opt/tools/bin appearing before /opt/local/bin."
        echo ""
        echo "Several of the Manta/Triton component Makefiles contain"
        echo "assumptions on the GNU implementations of UNIX utilities."
        echo ""
        echo "/opt/tools/bin contains compilers that are not currently"
        echo "supported by the build."
        echo "The \$PATH should be changed so that /opt/local/bin appears"
        echo "before /usr/bin, /usr/sbin, /opt/tools/bin and /bin."
        echo ""
        echo "The current path is:"
        echo $PATH
    fi
    return $result
}

#
# Check that this build machine is running a pkgsrc version appropriate for
# building this component. Dispense advice on how to obtain jenkins-agent
# images if this machine is not appropriate.
#
function validate_pkgsrc_version {

    # Add an escape hatch.
    if [[ -n "$ENGBLD_SKIP_VALIDATE_BUILD_PKGSRC" ]]; then
        echo "Skipping pkgsrc build machine validity tests."
        return 0
    fi

    #
    # We use $REQUIRED_IMAGE as a key to determine the correct build machine
    # for a given workspace. This works fine for most current consumers of
    # eng.git, as they either set it, or set $NODE_PREBUILT_IMAGE. If having
    # neither of these becomes common for future consumers of eng.git, we may
    # want to change this code, perhaps to hardcode a default minimum
    # PKGSRC_RELEASE for the build machine, omitting the warning below.
    #
    if [[ -z "$REQUIRED_IMAGE" ]]; then
        echo "Info: No apparent NODE_PREBUILT_IMAGE or BASE_IMAGE_UUID value."
        echo "Perhaps this build machine will work?"
        echo ""
        return 0
    fi

    if [[ -z "${PKGSRC_MAP[$REQUIRED_IMAGE]}" ]]; then
        echo "Error: unable to map $REQUIRED_IMAGE to a pkgsrc version"
        echo "changes needed to 'validate-build-platform.sh'?"
        echo ""
        return 1
    fi

    if [[ "$PKGSRC_RELEASE" != "${PKGSRC_MAP[$REQUIRED_IMAGE]}" ]]; then

        local SDC_IMAGE_NAME="${SDC_MAP[${REQUIRED_IMAGE}]}"
        local JENKINS_IMAGE="${JENKINS_AGENT_MAP[${REQUIRED_IMAGE}]}"

        local JENK_IMG_URL=${UPDATES_IMG_URL}${JENKINS_IMAGE}
        echo "This build machine should not be used to build this component."
        echo ""
        echo "expected pkgsrc version ${PKGSRC_MAP[$REQUIRED_IMAGE]}"
        echo " running pkgsrc version ${PKGSRC_RELEASE} "
        echo ""
        echo "This component should build on an image based on $SDC_IMAGE_NAME"
        echo "The following jenkins-agent image will work: ${JENKINS_IMAGE}"
        echo ""
        echo "To retrieve this image on Triton, use:"
        echo "    sdc-imgadm import -S '${UPDATES_URL}' ${JENKINS_IMAGE}"
        echo ""
        echo "on SmartOS, use:"
        echo "    imgadm import -S '${UPDATES_URL}' ${JENKINS_IMAGE}"
        echo ""
        echo "or import by hand, with:"
        echo "    curl -k -o img.manifest '${JENK_IMG_URL}?channel=experimental'"
        echo "    curl -k -o img.gz '${JENK_IMG_URL}/file?channel=experimental'"
        echo "and then"
        echo "    imgadm install -m img.manifest -f img.gz"
        echo ""
        return 1
    else
        # The build machine pkgsrc version is valid for building this component.
        return 0
    fi
}

#
# Return 0 if uid==0 or the current user has the 'Primary Administrator'
# profile, returning 1 otherwise. Checking for uid==0 shouldn't really imply
# privilege, but that's the current reality in illumos (sorry casper!)
#
function validate_rbac_profile {
    /usr/bin/id | grep -q uid=0
    if [[ $? -eq 0 ]]; then
        return 0
    fi

    /usr/bin/profiles | grep -q 'Primary Administrator'
    if [[ $? -eq 0 ]]; then
        return 0
    fi

    echo "The current user should have the 'Primary Administrator' profile"
    echo "which is needed to perform some parts of the build, e.g."
    echo "'buildimage'."
    echo "To configure this, as root, run:"
    echo "    usermod -P 'Primary Administrator' $USER"
    echo ""
    return 1
}

#
# Return 0 if it looks like we have a delegated dataset for this VM
#
function validate_delegated_dataset {
    zonename=$(/usr/bin/zonename)
    # it seems unlikely that someone's building in a gz, but it should be fine.
    if [[ "$zonename" == "global" ]]; then
        return 0
    fi

    has_delegated_ds=$(zfs list -H -o name zones/$zonename/data 2>/dev/null)
    if [[ -z "$has_delegated_ds" ]]; then
        local djc_base="https://docs.joyent.com/private-cloud/instances/"
        echo "The current devzone does not have a delegated zfs dataset,"
        echo "which is required for 'buildimage' to function."
        echo "Please recreate this devzone, ensuring it has a delegated ds."
        echo ""
        echo "To do this, when using vmadm in SmartOS or sdc-vmapi in"
        echo "Triton, add:"
        echo "    'delegate_dataset': true,"
        echo "to the json configuration. If using the Triton admin interface,"
        echo "select 'Delegate Dataset' when provisioning the instance."
        echo "For more information, see:"
        echo "$djc_base/delegated-data-sets"
        echo ""
        return 1
    fi
    return 0
}

#
# Return 0 if $BUILD_PLATFORM in the component's Makefile matches the timestamp
# encoded in uname -s output. We allow this check to be overridden
# independently, since in development, not building on the official platform
# image is common.
#
function validate_build_platform {

    if [[ -n "$ENGBLD_SKIP_VALIDATE_BUILD_PLATFORM" ]]; then
        return 0
    fi

    current_platform=$(/usr/bin/uname -v | sed -e 's/.*_//')
    component_platform=$(
        make -s --no-print-directory print-BUILD_PLATFORM 2> /dev/null |
            cut -d= -f2)

    # some components do not set a required build platform.
    if [[ -z "$component_platform" ]]; then
        return 0
    fi

    # this seems unlikely.
    if [[ -z "$current_platform" ]]; then
        echo "WARNING: unable to determine current build platform!"
        return 1
    fi

    if [[ "$component_platform" != "$current_platform" ]]; then
        echo "The current platform image, $current_platform, is not valid."
        echo "This component should instead be built on $component_platform"
        echo ""
        echo "To disable this check, set "
        echo "\$ENGBLD_SKIP_VALIDATE_BUILD_PLATFORM in the environment."
        echo ""
        return 1
    fi
    return 0
}

#
# Emit a line of the form "<pkgsrc release> <one word description>"
#
function print_required_pkgsrc_version {
    if [[ -n "$REQUIRED_IMAGE" ]]; then
        echo "${PKGSRC_MAP[$REQUIRED_IMAGE]} ${SDC_MAP[$REQUIRED_IMAGE]} ${JENKINS_AGENT_MAP[$REQUIRED_IMAGE]}"
        exit 0
    else
        exit 1
    fi
}

#
# Check that a list of pkgsrc packages appropriate to this release are
# installed. For now, we don't care about version numbers.
#
function validate_pkgsrc_pkgs {

    # Add an escape hatch.
    if [[ -n "$ENGBLD_SKIP_VALIDATE_BUILD_PKGSRC" ]]; then
        echo "Skipping pkgsrc package version validity tests."
        return 0
    fi

    if [[ -z "$PKGSRC_RELEASE" ]]; then
        echo "Unable to determine pkgsrc release"
        return 1
    fi

    PKGSRC_VAR_NAME=PKGSRC_PKGS_${PKGSRC_RELEASE}
    EXPECTED_PKGS=${!PKGSRC_VAR_NAME}
    PKG_LIST_FILE=$(mktemp /tmp/validate_build_pkgsrc.XXXXXX)
    /opt/local/bin/pkgin list | cut -f 1 > $PKG_LIST_FILE

    MISSING_PKGS=""
    for pkg in ${EXPECTED_PKGS}; do
        FOUND=""
        grep -q "$pkg-[0-9].*" $PKG_LIST_FILE
        if [[ $? -eq 0 ]]; then
            FOUND=true
        fi
        grep -q "$pkg " $PKG_LIST_FILE
        if [[ $? -eq 0 ]]; then
            FOUND=true
        fi
        if [[ -z "$FOUND" ]]; then
            MISSING_PKGS="$MISSING_PKGS $pkg"
        fi
    done
    rm $PKG_LIST_FILE

    if [[ -n "$MISSING_PKGS" ]]; then
        echo "The following packages should be installed for $PKGSRC_RELEASE:"
        echo "$MISSING_PKGS"

        # add a special-case for scmgit on smartos 1.6.3, where the version
        # from pkgsrc isn't modern enough. In particular, our tarball supports
        # TLSv1.2. Newer jenkins-agent images have fixed this by symlinking
        # to the version of git from /opt/tools instead, but warn just in case.
        if [[ "$PKGSRC_RELEASE" == "2011Q4" ]]; then
            JDEV="https://us-east.manta.joyent.com/Joyent_Dev/public/bits/"
            MODERN_GIT_TARBALL="modern-git-20170223a.tar.gz"
            echo "Note: the version of scmgit from pkgsrc may be too old."
            echo "Please verify that /opt/local/bin/git (which may be a "
            echo "symlink) is at least at version 2.12.0, or download the"
            echo "newer version from $JDEV/$MODERN_GIT_TARBALL"
        fi

        return 1
    fi
    return 0
}

#
# Check that this system has /opt/tools/bin. Note that /opt/tools delivers
# its own pkgsrc contents and is a wholly separate pkgsrc installation than
# /opt/local/bin.
#
function validate_opt_tools {
    if [[ ! -f /opt/tools/bin/pkgin ]]; then

        local JENKINS_IMAGE="${JENKINS_AGENT_MAP[${REQUIRED_IMAGE}]}"
        echo "This build zone is missing /opt/tools/bin, which is"
        echo "needed in order to run certain parts of the build, notably"
        echo "the 'buildimage' target."
        echo ""
        echo "All modern jenkins-agent images contain these, so using"
        echo "this image will work as a build zone: $JENKINS_IMAGE"
        echo ""
        echo "Alternatively, you can install the current pkgsrc bootstrap bits"
        echo "which deliver /opt/tools. Run the following:"
        echo ""
        BOOTSTRAP_URL="https://pkgsrc.joyent.com/packages/SmartOS/bootstrap/"
        BOOTSTRAP_TAR="bootstrap-2018Q3-tools.tar.gz"
        BOOTSTRAP_SHA="2244695a8ec0960e26c6f83cbe159a5269033d6a"
        echo "    curl -k -o /var/tmp/${BOOTSTRAP_TAR} \\"
        echo "        ${BOOTSTRAP_URL}/${BOOTSTRAP_TAR}"
        echo ""
        echo " ( verify that the SHA-1 sum of the tar file is $BOOTSTRAP_SHA )"
        echo ""
        echo "    tar -zxpf /var/tmp/${BOOTSTRAP_TAR} -C /"
        echo "    rm /var/tmp/${BOOTSTRAP_TAR}"
        echo ""
        return 1
    else
        # Validate we have an expected set of packages
        PKG_LIST_FILE=$(mktemp /tmp/validate_build_pkgsrc.XXXXXX)
        /opt/tools/bin/pkgin list | cut -f 1 > $PKG_LIST_FILE

        EXPECTED_PKGS="curl
            git-base
            git-docs
            git-contrib
            openjdk8
            nodejs-6.14.4
            npm"

        MISSING_PKGS=""
        for pkg in ${EXPECTED_PKGS}; do
            FOUND=""
            grep -q "$pkg-[0-9].*" $PKG_LIST_FILE
            if [[ $? -eq 0 ]]; then
                FOUND=true
            fi
            grep -q "$pkg " $PKG_LIST_FILE
            if [[ $? -eq 0 ]]; then
                FOUND=true
            fi
            if [[ -z "$FOUND" ]]; then
                MISSING_PKGS="$MISSING_PKGS $pkg"
            fi
        done
        rm $PKG_LIST_FILE

        if [[ -n "$MISSING_PKGS" ]]; then
            echo "The following packages must be installed in /opt/tools:"
            echo ""
            echo "$MISSING_PKGS"
            echo ""
            echo "Use /opt/tools/bin/pkgin in <package name> ..."
            echo ""
            return 1
        fi
    fi
    return 0
}

#
# Check that several programs needed by the build which aren't available from
# pkgsrc are available somewhere on the path. Trust that the versions present
# are sufficient.
#
function validate_non_pkgsrc_bins {
    REQUIRED_PROGS="mmd5
        mmkdir
        mput
        msign
        updates-imgadm"

    MISSING_PROGS=""

    for prog in ${REQUIRED_PROGS}; do
        command -v $prog > /dev/null
        if [[ $? -ne 0 ]]; then
            MISSING_PROGS="$prog $MISSING_PROGS"
        fi
    done

    if [[ -n "$MISSING_PROGS" ]]; then
        echo "The following programs were not found in \$PATH:"
        echo ""
        echo "$MISSING_PROGS"
        echo ""
        echo "These should be installed by hand. If we're running on a "
        echo "'jenkins-agent' image, they may be found in /root/bin and "
        echo "this should be added to \$PATH."
        echo ""
        echo "Otherwise, the following command will install the required"
        echo "programs:"
        echo ""
        echo "    npm install manta imgapi-cli"
        echo ""
        return 1
    fi
    return 0
}

#
# Validate that git submodules, if present, match the versions recorded in
# the top-level git repository. Submodules that are not initialized are not
# checked. We assume that the component's use of the 'deps/%/.git' make target
# will initialize missing submodules as needed.
# This check does not catch submodules containing uncommitted local changes.
# For that case, we just end up issuing a warning via the verify_clean_repo(..)
# check.
#
function validate_submodules {
    if [[ -n "$ENGBLD_SKIP_VALIDATE_SUBMODULES" ]]; then
        return 0
    fi
    # current git seems not to properly show submodules with merge conflicts,
    # (^U, below) but we'll keep this in case it gets fixed in the future.
    MODIFIED_SUBMODULES=$(git submodule | grep -e ^+ -e ^U | cut -d' ' -f 2)
    if [[ -n "$MODIFIED_SUBMODULES" ]]; then
        echo "The following submodules are not checked out to the versions"
        echo "recorded in this repository:"
        echo ""
        for module in $MODIFIED_SUBMODULES; do
            echo $module
        done
        echo ""
        echo "To fix this, please run the following command:"
        echo ""
        echo "git submodule update"
        echo ""
        echo "If this was intentional (e.g. you're making changes to the"
        echo "submodule, but have not yet staged those changes) and to disable"
        echo "this check, set \$ENGBLD_SKIP_VALIDATE_SUBMODULES"
        echo "in the environment."
        echo ""
        return 1
    fi
    return 0
}

#
# Issue a warning to the developer if their workspace contains uncommitted
# changes, which would result in bits-upload.sh not posting any built bits
# to Manta or updates.joyent.com
#
function verify_clean_repo {
    HAS_DIRTY=$(git describe --all --long --dirty | grep '\-dirty$')
    if [[ -n "$HAS_DIRTY" ]]; then
        echo "WARNING: this workspace contains uncommitted changes,"
        echo "which means that any build artifacts will not be uploaded by"
        echo "bits-upload.sh to either Manta or updates.joyent.com"
    fi
}

function usage {
    echo "Usage: validate-build-platform [-h] [-r]"
    echo "  -h       print usage"
    echo "  -r       only print required pkgsrc release and description"
    exit 2
}

#
# Main
#
while getopts "rh" opt; do
    case "${opt}" in
        r)
            do_required_version=true
            ;;
        h)
            do_usage=true
            ;;
    esac
done

if [[ -n "${do_usage}" ]]; then
    usage
fi

get_pkgsrc_sdcnode_versions

if [[ -n "${do_required_version}" ]]; then
    print_required_pkgsrc_version
    exit $?
else
    RESULT=0
    validate_pkgsrc_version
    RESULT=$(( $RESULT + $? ))
    validate_pkgsrc_pkgs
    RESULT=$(( $RESULT + $? ))
    validate_rbac_profile
    RESULT=$(( $RESULT + $? ))
    validate_delegated_dataset
    RESULT=$(( $RESULT + $? ))
    validate_build_path
    RESULT=$(( $RESULT + $? ))
    validate_build_platform
    RESULT=$(( $RESULT + $? ))
    validate_opt_tools
    RESULT=$(( $RESULT + $? ))
    validate_non_pkgsrc_bins
    RESULT=$(( $RESULT + $? ))
    validate_submodules
    RESULT=$(( $RESULT + $? ))
    # this doesn't contribute to success/failure, but warns
    # developers that '-dirty' repositories will result in
    # bits-upload not posting to Manta/updates.joyent.com.
    verify_clean_repo
    if [[ "$RESULT" -gt 0 ]]; then
        echo ""
        echo "Build zone setup typically requires almost no work if you are"
        echo "using the right image.  See:"
        echo ""
        echo "https://github.com/joyent/triton/blob/master/docs/developer-guide/build-zone-setup.md"
        echo ""

        exit 1
    else
        exit 0
    fi
fi

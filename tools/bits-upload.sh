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
# Upload the $ENGBLD_BITS_DIR directory to Manta or a "local" directory (likely
# an NFS-mounted share if we're contributing to bits already stored there
# by other builds on remote systems)
# This creates a specific directory structure, consumed by the headnode builds:
#
# <remote>/<component>/latest-release -> <latest>
# <remote>/component>/<component-branch-stamp>/<component>/... (files)
#
# which is documented at:
# https://github.com/joyent/mountain-gorilla/blob/master/docs/index.md
# (see "Bits directory structure")
#

#
# It is unlikely that users will ever need to run this script by hand.
# Users are more likely to run this as part of the 'bits-upload' or
# 'bits-upload-latest' targets.
#

if [[ -n "$TRACE" ]]; then
    export PS4='${BASH_SOURCE}:${LINENO}: '
    set -o xtrace
fi
set -o errexit

#
# Uncomment the below to have manta-tools emit bunyan logs to stdout
#
# MANTA_VERBOSE=-v

#
# Whether we should overwrite previous uploads if the content is the same
#
BITS_UPLOAD_OVERWRITE=false

#
# Whether we should allow upload of bits marked with a '-dirty' $STAMP
#
BITS_UPLOAD_ALLOW_DIRTY=$ENGBLD_BITS_UPLOAD_ALLOW_DIRTY

#
# A path to our updates-imgadm command
#
UPDATES_IMGADM=/root/opt/imgapi-cli/bin/updates-imgadm

if [[ -z "$ENGBLD_BITS_DIR" ]]; then
	ENGBLD_BITS_DIR=bits
fi

PATH=$PATH:/root/opt/node_modules/manta/bin:/opt/tools/bin

function fatal {
    echo "$(basename $0): error: $1"
    exit 1
}

function errexit {
    [[ $1 -ne 0 ]] || exit 0
    fatal "error exit status $1 at line $2"
}

trap 'errexit $? $LINENO' EXIT

function usage {
    echo "Usage: bits-upload.sh [options] [subdirs...]"
    echo "OPTIONS"
    echo "  -b <branch>         the branch use"
    echo "  -B <try_branch>     the try_branch use"
    echo "  -d <upload_base_dir> destination path name in manta or a local path"
    echo "  -L                  indicate the -d arg is a local path"
    echo "  -n <name>           the name of component to upload"
    echo "  -p                  also publish images to updates.joyent.com"
    echo "  -t <timestamp>      the timestamp (optional, derived otherwise)"
    echo ""
    echo "Upload bits to Manta or a local destination from \$ENGBLD_BITS_DIR"
    echo "which (defaults to <component>/bits)"
    echo ""
    echo "The upload_base_dir is presumed to be either a subdir of"
    echo "\${MANTA_USER}/stor or if it starts with '/', a path under"
    echo "\${MANTA_USER}. If Using -L, the -d argument should be an"
    echo "absolute path."
    exit 2
}

#
# Maintain a global associative array mapping uploaded file basenames
# to their corresponding Manta paths. This assumes basenames are unique.
#
declare -A STORED_MANTA_PATHS

#
# A simple wrapper to emit manta command-lines before running them.
#
function manta_run {
    echo $@
    "$@"
    return $?
}

#
# Upload build artifacts to Manta. There's some duplication in the logic
# here and local_upload.
#
function manta_upload {

    if [[ -z "$MANTA_KEY_ID" ]]; then
        export MANTA_KEY_ID=$(
            ssh-keygen -E md5 -l -f ~/.ssh/id_rsa.pub | \
            awk '{sub("^MD5:", "", $2); print $2}')
    fi
    if [[ -z "$MANTA_URL" ]]; then
        export MANTA_URL=https://us-east.manta.joyent.com
    fi
    if [[ -z "$MANTA_USER" ]]; then
        export MANTA_USER="Joyent_Dev";
    fi

    if [[ ${UPLOAD_BASE_DIR:0:1} != '/' ]]; then
        # if it starts with a / we assume it's /stor/<something> or
        # /public/<something> if not, we prepend /stor
        UPLOAD_BASE_DIR="/stor/${UPLOAD_BASE_DIR}"
    fi

    MANTA_DESTDIR=/${MANTA_USER}${UPLOAD_BASE_DIR}/${UPLOAD_SUBDIR}
    echo "Uploading bits to ${MANTA_DESTDIR} "
    if [[ -z "$SUBS" ]]; then
        manta_run mmkdir ${MANTA_VERBOSE} -p ${MANTA_DESTDIR}
    fi

    for sub in $SUBS; do
        manta_run mmkdir ${MANTA_VERBOSE} -p ${MANTA_DESTDIR}/${sub#${ENGBLD_BITS_DIR}}
    done

    md5sums=""
    # now we can upload the files
    for file in $FILES; do
        manta_object=${MANTA_DESTDIR}/${file#$ENGBLD_BITS_DIR}
        # md5sum comes from the coreutils package
        local_md5_line=$(md5sum ${file})
        local_md5=$(echo "${local_md5_line}" | cut -d ' ' -f1)
        manta_md5=$(mmd5 ${manta_object} | cut -d ' ' -f1)

        if [[ -n ${manta_md5} && ${manta_md5} != ${local_md5} ]]; then
            fatal "${manta_object} exists but MD5 does not match ${file}"
        fi

        if [[ -z ${manta_md5} ]]; then
            # file doesn't exist, upload it
            manta_run mput ${MANTA_VERBOSE} -f ${file} ${manta_object}
            [[ $? == 0 ]] || fatal "Failed to upload ${file} to ${manta_object}"
        elif [[ "$BITS_UPLOAD_OVERWRITE" == "false" ]]; then
            echo "${manta_object} already exists and matches local file,"
            echo "Skipping upload."
        fi
        md5sums="${md5sums}${local_md5_line}\n"

        # save the file to our global assoc-array of {filename: manta path}
        # used later when mapping manifests to image file URLs.
        STORED_MANTA_PATHS[$(basename $file)]=${manta_object}

        # Store a full URL if it appears to be a public resource, otherwise
        # just save the manta path.
        set +o errexit
        echo $manta_object | grep -q /public/
        if [[ $? -eq 0 ]]; then
            echo ${MANTA_URL}${manta_object} >> ${ENGBLD_BITS_DIR}/artifacts.txt
        else
            echo $manta_object >> ${ENGBLD_BITS_DIR}/artifacts.txt
        fi
        set -o errexit
    done

    # upload the md5sums
    echo -e $md5sums | \
        manta_run mput ${MANTA_VERBOSE} -H "content-type: text/plain" \
            ${MANTA_DESTDIR}/md5sums.txt
        echo ${MANTA_DESTDIR}/md5sums.txt >> ${ENGBLD_BITS_DIR}/artifacts.txt

    # now update the branch latest link
    echo "${MANTA_DESTDIR}" | \
        manta_run mput ${MANTA_VERBOSE} -H "content-type: text/plain" \
            /${MANTA_USER}${UPLOAD_BASE_DIR}/${UPLOAD_BRANCH}-latest
    echo /${MANTA_USER}${UPLOAD_BASE_DIR}/${UPLOAD_BRANCH}-latest >> \
        ${ENGBLD_BITS_DIR}/artifacts.txt

    # If this is a bi-weekly release branch, also update latest-release link
    if [[ $UPLOAD_BRANCH =~ ^release- ]]; then
        echo "${MANTA_DESTDIR}" | \
            manta_run mput ${MANTA_VERBOSE} -H "content-type: text/plain" \
                /${MANTA_USER}${UPLOAD_BASE_DIR}/latest-release
        echo /${MANTA_USER}${UPLOAD_BASE_DIR}/latest-release >> \
            ${ENGBLD_BITS_DIR}/artifacts.txt
    fi

    echo "Uploaded to ${MANTA_DESTDIR}"
}

#
# Copy build artifacts to a local or NFS-mounted filesystem.
# There's some duplication in the logic here and manta_upload. Note that
# the <branch>-latest object created is now a symlink rather than an
# object containing the latest path.
#
function local_upload {

    LOCAL_DESTDIR=${UPLOAD_BASE_DIR}/${UPLOAD_SUBDIR}
    for sub in $SUBS; do
        mkdir -p ${LOCAL_DESTDIR}/${sub#${ENGBLD_BITS_DIR}}
    done

    md5sums=""
    for file in $FILES; do
        remote_object=${LOCAL_DESTDIR}/${file#$ENGBLD_BITS_DIR}

        local_md5_line=$(md5sum ${file})
        local_md5=$(echo "${local_md5_line}" | cut -d ' ' -f1)
        if [[ -f ${remote_object} ]]; then
            remote_md5=$(md5sum ${remote_object} | cut -d ' ' -f1)
        else
            remote_md5=""
        fi

        if [[ -n ${remote_md5} && ${remote_md5} != ${local_md5} ]]; then
            fatal "${remote_object} exists but MD5 does not match ${file}"
        fi

        if [[ -z ${remote_md5} ]]; then
            # file doesn't exist, upload it
            cp ${file} ${remote_object}
            [[ $? == 0 ]] || \
                fatal "Failed to upload ${file} to ${remote_object}"
        else
            echo "${remote_object} already exists and matches local file,"
            echo "skipping upload."
        fi
        md5sums="${md5sums}${local_md5_line}\n"
        echo $remote_object >> ${ENGBLD_BITS_DIR}/artifacts.txt
    done

    # upload the md5sums
    echo -e $md5sums > ${LOCAL_DESTDIR}/md5sums.txt

    # now update the branch latest link
    if [[ -L ${UPLOAD_BASE_DIR}/${UPLOAD_BRANCH}-latest ]]; then
        unlink ${UPLOAD_BASE_DIR}/${UPLOAD_BRANCH}-latest
    fi
    (cd $UPLOAD_BASE_DIR ; ln -s ${UPLOAD_SUBDIR} ${UPLOAD_BRANCH}-latest)

    # If this is a bi-weekly release branch, also update latest-release link
    if [[ $UPLOAD_BRANCH =~ ^release- ]]; then
        if [[ -L ${UPLOAD_BASE_DIR}/latest-release ]]; then
            unlink ${UPLOAD_BASE_DIR}/latest-release
        fi
        (cd ${UPLOAD_BASE_DIR} ; ln -s ${UPLOAD_SUBDIR} latest-release)
    fi
}

#
# Look for build artifacts to operate on.
#
function find_upload_bits {
    if [[ -z "$SUBDIRS" ]]; then
        SUBS=$(find $ENGBLD_BITS_DIR -type d)
        FILES=$(find $ENGBLD_BITS_DIR -type f)
    else
        for subdir in ${SUBDIRS}; do
            if [[ -d $ENGBLD_BITS_DIR/$subdir ]]; then
                SUBS="$SUBS $(find $ENGBLD_BITS_DIR/$subdir -type d)"
                FILES="$FILES $(find $ENGBLD_BITS_DIR/$subdir -type f)"
            fi
        done
    fi
}

#
# Publish build artifacts to updates.joyent.com.
#
function publish_to_updates {
    local manta_path
    local msigned_url

    echo "Publishing updates to updates.joyent.com"
    for file in ${FILES}; do
        set +o errexit
        echo ${file} | grep -q '.*manifest$'
        if [[ $? -ne 0 ]]; then
            set -o errexit
            continue
        fi
        set -o errexit

        MF=${file}
        IMAGEFILE=$(echo ${MF} | sed -e 's/\..*manifest$/.zfs.gz/g')

        # Some payloads are not zfs-based, look for likely alternatives.
        # This assumes that a single directory with <file>.manifest
        # contains only one of [<file>.zfs.gz, <file>.sh, <file>.tgz,
	# <file>.tar.gz]
        if [[ ! -f "${IMAGEFILE}" ]]; then
            IMAGEFILE=$(echo ${MF} | sed -e 's/\..*manifest$/.sh/g')
        fi
        if [[ ! -f "${IMAGEFILE}" ]]; then
            IMAGEFILE=$(echo ${MF} | sed -e 's/\..*manifest$/.tgz/g')
        fi
        if [[ ! -f "${IMAGEFILE}" ]]; then
            IMAGEFILE=$(echo ${MF} | sed -e 's/\..*manifest$/.tar.gz/g')
        fi

        if [[ ! -f ${IMAGEFILE} ]]; then
            echo "Unable to determine image file for ${MF}."
            echo "Skipping publishing ${MF} to updates.joyent.com"
            continue
        fi

        UUID=$(json -f ${MF} uuid)
        if [[ -z "${UUID}" ]]; then
            echo "Unable to determine UUID of ${MF}."
            echo "Skipping publishing ${MF} to updates.joyent.com"
            continue
        fi

        # The default 1hr expiry for msign is sufficient, since we're going
        # to be accessing this URL almost immediately.
        manta_path=${STORED_MANTA_PATHS[$(basename $IMAGEFILE)]}
        msigned_url=$(msign $manta_path)

        # Compute values for channel, user and identity
        if [[ -z "$UPDATES_IMGADM_CHANNEL" ]]; then

            if [[ ! -z "$TRY_BRANCH" ]]; then
                BRANCH_NAME=${TRY_BRANCH}
            else
                BRANCH_NAME=${BRANCH}
            fi
            if [[ -z "$TRY_BRANCH" && "$(echo ${BRANCH} \
                    | grep '^release-[0-9]\{8\}$' || true)" ]]; then
                export UPDATES_IMGADM_CHANNEL=staging
            else
                if [[ "${BRANCH_NAME}" == "master" ]]; then
                    export UPDATES_IMGADM_CHANNEL=dev
                else
                    export UPDATES_IMGADM_CHANNEL=experimental
                fi
            fi
        fi

        if [[ -z "$UPDATES_IMGADM_USER" ]]; then
            export UPDATES_IMGADM_USER=mg
        fi

        if [[ -z "$UPDATES_IMGADM_IDENTITY" ]]; then
            export UPDATES_IMGADM_IDENTITY=~/.ssh/automation.id_rsa
        fi
        echo "Using the following environment variables for updates-imgadm:"
        echo "UPDATES_IMGADM_CHANNEL=$UPDATES_IMGADM_CHANNEL"
        echo "UPDATES_IMGADM_USER=$UPDATES_IMGADM_USER"
        echo "UPDATES_IMGADM_IDENTITY=$UPDATES_IMGADM_IDENTITY"
        echo Running: ${UPDATES_IMGADM} import -m ${MF} -f "${msigned_url}"
        ${UPDATES_IMGADM} import -m ${MF} -f "${msigned_url}"
    done
}


#
# Main
#
while getopts "B:b:d:Ln:pt:" opt; do
    case "${opt}" in
        b)
            BRANCH=$OPTARG
            ;;
        B)
            TRY_BRANCH=$OPTARG
            ;;
        d)
            UPLOAD_BASE_DIR=$OPTARG
            ;;
        L)
            USE_LOCAL=true
            ;;
        n)
            NAME=$OPTARG
            ;;
        p)
            PUBLISH_UPDATES=true
            ;;
        t)
            TIMESTAMP=$OPTARG
            ;;
        *)
            echo "Error: Unknown argument ${opt}"
            usage
    esac
done
shift $((OPTIND - 1))

if [[ -z "${BRANCH}" ]]; then
    echo "Missing -b argument for branch"
    usage
fi

if [[ -z "$UPLOAD_BASE_DIR" ]]; then
    echo "Missing -d argument for upload_base_dir"
    usage
fi

if [[ ! -d "$ENGBLD_BITS_DIR" ]]; then
    fatal "bits dir $ENGBLD_BITS_DIR does not exist!"
fi

if [[ -z "$NAME" ]]; then
    fatal "Missing -d argument for name"
fi

SUBDIRS=$*

UPLOAD_BRANCH=$TRY_BRANCH
if [[ -z "$UPLOAD_BRANCH" ]]; then
    UPLOAD_BRANCH=$BRANCH
fi

start_time=$(date +%s)

# we keep a file containing a list of uploads for this
# session, useful to include as part of build artifacts.
if [[ -f $ENGBLD_BITS_DIR/artifacts.txt ]]; then
    rm -f $ENGBLD_BITS_DIR/artifacts.txt
fi

find_upload_bits

if [[ -z "$TIMESTAMP" ]]; then
    LATEST_BUILD_STAMP=$ENGBLD_BITS_DIR/$NAME/latest-build-stamp
    # Pull the latest timestamp from the bits dir instead.
    if [[ -f $LATEST_BUILD_STAMP ]]; then
        TIMESTAMP=$(cat $LATEST_BUILD_STAMP)
    else
        echo "Missing timestamp, and no contents in $LATEST_BUILD_STAMP"
        echo "Did the 'prepublish' Makefile target run?"
        fatal "Unable to derive latest timestamp from files in $ENGBLD_BITS_DIR"
    fi
fi

#
# Attempting to upload bits from a workspace marked dirty isn't
# allowed, because then we have no sure way to get from the development
# bits to the corresponding source commit. Arguably, this _might_ be
# feasible for pure-javascript-only components. Developers who absolutely
# must upload bits marked '-dirty' can always upload them manually, or
# use the BITS_UPLOAD_ALLOW_DIRTY escape hatch in case of emergency.
#
set +o errexit
echo $TIMESTAMP | grep -q '\-dirty$'
if [[ $? -eq 0 && -z "$BITS_UPLOAD_ALLOW_DIRTY" ]]; then
    fatal "Bits timestamp $TIMESTAMP marked 'dirty': not uploading"
fi
set -o errexit

UPLOAD_SUBDIR=$TIMESTAMP

if [[ -n "$USE_LOCAL" ]]; then
    if [[ -n "$PUBLISH_TO_UPDATES" ]]; then
        fatal "-p requires uploading to Manta, and is incompatible with -L"
    fi
    local_upload
else
    manta_upload
fi

if [[ -n "$PUBLISH_UPDATES" ]]; then
    publish_to_updates
fi

end_time=$(date +%s)
elapsed=$((${end_time} - ${start_time}))
if [[ -n "$USE_LOCAL" ]]; then
    desc="(path=${UPLOAD_BASE_DIR}/${UPLOAD_SUBDIR})"
else
    desc="(Manta path=/${MANTA_USER}${UPLOAD_BASE_DIR}/${UPLOAD_SUBDIR})."
fi
echo "Upload took ${elapsed} seconds $desc"

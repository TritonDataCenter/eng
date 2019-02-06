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
# Used by Makefile.agent_prebuilt.*, this script deals with managing the
# cache of prebuilt Triton/Manta agent builds which are consumed by other
# components. We don't expect developers to ever invoke this shell script
# by hand. Instead, this script exists because it's easier to write/test
# operations here than to try to embed lots of shell logic in a Makefile
# target.
#

set -o errexit
trap cleanup EXIT

#
# The options that this script takes correspond to the following
# Makefile.agent_prebuilt.defs macros:
#
# -B AGENT_PREBUILT_AGENT_BRANCH    the branch of the agent sources to build
# -b AGENT_PREBUILT_BRANCH          an alternate branch of the agent sources
#                                   to build. The build will first try to
#                                   checkout the repository at the -B branch,
#                                   then the -b branch, then fall back to
#                                   'master'
# -c AGENT_PREBUILT_DIR             the top level cache where we clone/build
#                                   agents
# -d <name>_PREBUILT_ROOTDIR        where in the image the package resides
# -p <name>_PREBUILT_TARBALL_PATTERN  a glob pattern to match the built or
#                                     downloaded agent
# -r <name>_PREBUILT_REPO           the local repository name
# -t <name>_PREBUILT_AGENT_TARGETS  the make targets in that repository to build
# -u <name>_PREBUILT_GIT_URL        the git repository containing the agent
#                                   source
# -U AGENT_PREBUILT_URL             the url to download prebuilt agent tarballs
#                                   from
#
function usage {
    echo "Usage: agent-prebuilt <options> <command>"
    echo "COMMANDS:"
    echo "  clone               clone the git repository to the given branch"
    echo "  build               build the supplied -t targets"
    echo "  clean               clean the git repository"
    echo "  download            download from a http:// or file:/// "
    echo "  extract             extract the tarball within an image proto dir"
    echo "  show_tarball        prints the path of the latest tarball"
    echo ""
    echo "OPTIONS:"
    echo "  -b <branch>         the branch to checkout and build"
    echo "  -B <agent_branch>   the agent_branch to checkout and build"
    echo "  -c <dir>            the location of the agent_cache"
    echo "  -d <dir>            where in the image the package resides"
    echo "  -p <pattern>        a glob pattern to match the built agent tarball"
    echo "  -r <repo name>      the local repository directory name"
    echo "  -t <target>         the make targets to build"
    echo "  -u <url>            the git repository to clone"
    echo "  -U <url>            a http:// URL or file:/// dir containing"
    echo "                      prebuilt tarballs"
    exit 2
}

function do_clone {
    set +o errexit
    git_exit=0
    if [[ -d $agent_cache_dir/$repo_name ]]; then
        cd $agent_cache_dir/$repo_name
        if [[ $? -ne 0 ]]; then
            echo "ERROR: unable to cd to $agent_cache_dir/$repo_name"
            return 1
        fi
        # ensure there are no uncommitted changes before attempting to
        # rebase
        uncommitted=$(git status --porcelain)
        if [[ -n "$uncommitted" ]]; then
            echo "ERROR: uncommitted changes in $agent_cache_dir/$repo_name"
            echo "Please commit these before attempting to rebase."
            return 1
        fi
        git pull --rebase
        if [[ $? -ne 0 ]]; then
            echo "WARNING: Pulling from $git_url failed, which might be ok if"
            echo "the branch the existing repository is checked out to doesn't"
            echo "exist upstream."
        fi
        git checkout $agent_branch --
        if [[ $? -ne 0 ]]; then
            echo "Checking out $agent_branch failed, falling back to $branch"
            git checkout $branch --
        fi
        if [[ $? -ne 0 ]]; then
            # at this point, failures are really fatal.
            set -o errexit
            echo "Checking out $branch also failed, falling back to master"
            git checkout master --
            git_exit=$?
        fi
    else
        cd $agent_cache_dir
        if [[ $? -ne 0 ]]; then
            echo "ERROR: unable to cd to $agent_cache_dir"
            return 1
        fi
        git clone -b $agent_branch $git_url $repo_name
        if [[ $? -ne 0 ]]; then
            echo "Cloning branch $agent_branch failed, falling back to $branch"
            git clone -b $branch $git_url $repo_name
        fi
        if [[ $? -ne 0 ]]; then
            set -o errexit
            echo "Cloning branch $branch also failed, falling back to master"
            git clone -b master $git_url $repo_name
            git_exit=$?
        fi
    fi
    set -o errexit
    return $git_exit
}

function do_build {
    if [[ ! -d $agent_cache_dir/$repo_name ]]; then
        echo "Cannot do a build when $repo_name dir is missing!"
        return 1
    fi
    # this sets $LATEST_TARBALL as a side effect
    get_tarball allow_empty
    cd $agent_cache_dir/$repo_name
    if [[ -n "$LATEST_TARBALL" ]]; then
        # check it matches our hash
        git_hash=$(git describe --all --long --dirty | awk -F'-g' '{print $NF}')
        hash_present=$(echo $LATEST_TARBALL | grep "g${git_hash}" || true)
        if [[ -n "$hash_present" ]]; then
            echo "Latest tarball $LATEST_TARBALL seems fresh. Not rebuilding."
            return 0
        else
            echo "Latest tarball is stale"
            echo "  latest tarball: $LATEST_TARBALL"
            echo "current git hash: $git_hash ($branch)"
        fi
    fi

    #
    # Our agents should be able to build and run anywhere,
    # so relax the build checks for them. If any agents ever
    # create dependencies against /opt/local, that would be
    # bad.
    #
    ENGBLD_SKIP_VALIDATE_BUILDENV=true gmake $agent_targets
    return $?
}

function do_clean {
    rm -rf $agent_cache_dir/$repo_name
    return 0
}


#
# Determine the full path of the latest tarball, or the location we downloaded
# it to if $agent_url is set, set as $LATEST_TARBALL.
#
function get_tarball {

    if [[ -n "$1" ]]; then
        allow_empty=true
    fi

    # 'basename', but using a bash builtin
    file_pattern=${tarball_pattern##*/}
    dir_pattern=$(dirname $tarball_pattern)
    if [[ -z "$agent_url" ]]; then
        latest_tarball_dir=$agent_cache_dir/$repo_name/$dir_pattern/
    else
        # downloaded tarballs are dumped at the top level of the agent_cache_dir
        latest_tarball_dir=$agent_cache_dir
    fi

    # look for the agent_branch file
    if [[ -n "$agent_branch" ]]; then
        latest_tarball_file=$(
            /usr/bin/ls -1 $latest_tarball_dir | grep $file_pattern \
            2>/dev/null | grep $agent_branch | sort | tail -1)
    fi
    if [[ -z "$latest_tarball_file" ]]; then
        # fall back to the branch file
        latest_tarball_file=$(
            /usr/bin/ls -1 $latest_tarball_dir | grep $file_pattern \
            2>/dev/null | grep $branch | sort | tail -1)
    fi
    if [[ -z "$latest_tarball_file" ]]; then
        # fall back to the master branch
	latest_tarball_file=$(
            /usr/bin/ls -1 $latest_tarball_dir | grep $file_pattern \
            2>/dev/null | grep master | sort | tail -1)
    fi
    if [[ -z "$latest_tarball_file" ]]; then
        if [[ -n "$allow_empty" ]]; then
            LATEST_TARBALL=""
            return
        fi
        echo "No (agent_branch) $agent_branch or (branch) $branch or master \
            tarball for $tarball_pattern at $latest_tarball_dir"
        exit 1
    fi

    LATEST_TARBALL=$latest_tarball_dir/$latest_tarball_file
}

#
# Extract the agent into the image rooted at the current directory.
#
function do_extract {

    # This sets $LATEST_TARBALL as a side effect
    get_tarball

    this_dir=$PWD
    # if we specified a directory relative to the top of the image, make that
    # and cd into it so the agent appears in the correct location.
    if [[ -n "$root_dir" ]]; then
        mkdir -p $root_dir
        cd $root_dir
    fi
    echo "Extracting agent $LATEST_TARBALL to $PWD"
    case $LATEST_TARBALL in \
        *bz2) bunzip2 -c $LATEST_TARBALL | gtar xf - ;
            ;;
        *gz) gunzip -c $LATEST_TARBALL | gtar xf - ;
            ;;
        *)
            echo "ERROR: unknown extension trying to extract $LATEST_TARBALL"
            exit 1
    esac
    cd $this_dir
}

#
# Download this agent from the agent_url directory, according to the
# tarball_pattern supplied
#
function do_download {
    file_pattern=$(basename $tarball_pattern)
    set +o errexit
    http=$(echo $agent_url | grep ^http)
    set -o errexit

    if [[ -n "$http" ]]; then
        # look for an agent_branch url
        agent_file=$(curl -sS --fail --connect-timeout 30 $agent_url |
            grep 'href=' | cut -d'"' -f2 | grep "^${file_pattern}$" |
            grep $agent_branch | tail -1)
        if [[ -z "$agent_file" ]]; then
            # fall back to the branch url
            agent_file=$(curl -sS --fail --connect-timeout 30 $agent_url |
                grep 'href=' | cut -d'"' -f2 | grep "^${file_pattern}$" |
                grep $branch | tail -1)
        fi
        if [[ -z "$agent_file" ]]; then
            echo "Unable to determine url for (agent_branch) $agent_branch \
                or (branch) $branch $file_pattern at $agent_url"
            exit 1
        fi
        echo "Downloading $agent_url/$agent_file"
        curl -sS --connect-timeout 30 -o \
            $agent_cache_dir/$agent_file $agent_url/$agent_file
    else
        # copy it, assuming $agent_url and $agent_cache_dir aren't identical.
        # We don't have 'realpath' on all build systems, so make do with Python.
        realpath_agent_url=$(python -c
            "import os; print os.path.realpath('$agent_url')")
        realpath_agent_cache_dir=$(python -c
            "import os; print os.path.realpath('$agent_cache_dir')")
        if [[ "$realpath_agent_url" == "$realpath_agent_cache_dir" ]]; then
            echo "Identical paths for $agent_url and $agent_cache_dir. Skipping"
            return
        fi
        file_pattern=$(basename $tarball_pattern)
        # look for a agent_branch file
        latest_tarball_file=$(
            /usr/bin/ls -1 $agent_url | grep $file_pattern \
            2>/dev/null | grep $agent_branch | sort | tail -1)
        if [[ -z "$latest_tarball_file" ]]; then
            # fall back to the branch file
            latest_tarball_file=$(
                /usr/bin/ls -1 $agent_url | grep $file_pattern \
                2>/dev/null | grep $branch | sort | tail -1)
        fi
        if [[ -z "$latest_tarball_file" ]]; then
            echo "Unable to find local file for (agent_branch) $agent_branch \
                or (branch) $branch $agent_pattern at $agent_url"
            exit 1
        fi
        latest_tarball_file=$agent_url/$latest_tarball_file
        echo "Copying local $latest_tarball_file to $agent_cache_dir"
        cp $latest_tarball_file $agent_cache_dir
    fi
}

function cleanup {
    if [[ -d $agent_cache_dir/$repo_name.lock ]]; then
        rmdir $agent_cache_dir/$repo_name.lock
    fi
}

#
# Main
#
while getopts "B:b:c:d:hp:r:t:u:U:" opt; do
    case "${opt}" in
        b)
            branch=$OPTARG
            ;;
        B)
            agent_branch=$OPTARG
            ;;
        c)
            agent_cache_dir=$OPTARG
            mkdir -p $agent_cache_dir
            ;;
        d)
            # it's ok for this to be empty, indicating the agent tarball
            # delivers directories right up to the root of the image. Sanity
            # check the variable, just to be on the safe side.
            root_dir=$OPTARG
            if [[ -n "$root_dir" ]]; then
                case "$root_dir" in
                    .* | /*)
                        echo "Error: -d option should not start with . or /"
                        exit 1
                        ;;
                esac
            fi
            ;;
        h)
            do_usage=true
            ;;
        p)
            tarball_pattern="$OPTARG"
            ;;
        r)
            repo_name=$OPTARG
            ;;
        t)
            agent_targets="$OPTARG"
            ;;
        U)
            # optional
            agent_url=$OPTARG
            ;;
        u)
            git_url=$OPTARG
            ;;
        *)
            echo "Error: unknown option ${opt}"
            usage
    esac
done
shift $((OPTIND - 1))

command=$1

if [[ -z "$branch" ]]; then
    branch=master
fi

if [[ -z "$agent_branch" ]]; then
    agent_branch=$branch
fi

if [[ -z "$agent_cache_dir" ]]; then
    echo "-c agent_cache_dir option must be supplied"
    usage
fi

if [[ -z "$tarball_pattern" ]]; then
    echo "-p tarball_pattern option must be supplied"
    usage
fi

if [[ -z "$repo_name" ]]; then
    echo "-r repo_name option must be supplied"
    usage
fi

if [[ -z "$agent_targets" && "$command" == "build" ]]; then
    echo "-t agent_targets option must be supplied"
    usage
fi

if [[ -z "$git_url" && "$command" == "clone" ]]; then
    echo "-u git_url option must be supplied"
    usage
fi

if [[ -n "${do_usage}" ]]; then
    usage
fi

if [[ -z "$1" ]]; then
    echo "No command supplied"
    usage
fi

# attempt to prevent two agent-prebuilt.sh scripts from operating on the
# same repo at the same time. $agent_cache_dir exists at this point.
unlocked="true"
count=0
set +o errexit
while [[ -n "$unlocked" && $count -lt 600 ]]; do
    if ! mkdir $agent_cache_dir/$repo_name.lock 2> /dev/null; then
        echo "$agent_cache_dir/$repo_name.lock already held, sleeping $count..."
        unlocked="locked"
        count=$(( $count + 1 ))
        sleep 1
    else
        unlocked=""
    fi
done
set -o errexit

if [[ -n "$unlocked" ]]; then
    echo "Failed to unlock agent cache for $repo_name. Exiting now."
    exit 1
fi

case "$command" in
    clone)
        do_clone
        ;;
    build)
        do_build
        ;;
    clean)
        do_clean
        ;;
    extract)
        do_extract
        ;;
    show_tarball)
        get_tarball
        echo $LATEST_TARBALL
        ;;
    download)
        do_download
        ;;
    *)
        echo "Unrecognised command $1"
        usage
        ;;
esac
ret=$?
cleanup
exit $ret

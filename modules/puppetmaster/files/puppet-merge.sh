#!/bin/sh

set -eu
MASTERS=""
WORKERS=""
RED=$(tput bold; tput setaf 1)
GREEN=$(tput bold; tput setaf 2)
CYAN=$(tput bold; tput setaf 6)
RESET=$(tput sgr0)
CA_SERVER=''
git_user=gitpuppet

. /etc/puppet-merge.conf

if [ "$(hostname -f)" -ne "${CA_SERVER}" ];then
  printf "To ensure consistent locking please run puppet-merge from: %s\n" ${CA_SERVER}
  exit 1
fi

if [ "$(whoami)" = "gitpuppet" ]
then
  printf "This script should only be run as a real users.  gitpuppet should use /usr/local/bin/puppet-merge.py\n"
  exit 1
fi

lock() {
  LABS_PRIVATE=$1
  if [ ${LABS_PRIVATE} -eq 1 ]
  then
    LOCKFILE=/var/lock/puppet-merge-labs-lock
  else
    LOCKFILE=/var/lock/puppet-merge-prod-lock
  fi
  LOCKFD=9
  eval "exec ${LOCKFD}>\"$LOCKFILE\""
  trap "rm -f $LOCKFILE" EXIT
  if ! flock -xn $LOCKFD
  then
      trap EXIT
      # Close our own fd to the lockfile before checking ownership below.
      eval "exec ${LOCKFD}>&-"
      # Any subprocess of the script that holds the lock will also have an open
      # filehandle to $LOCKFILE.  Grab just one such PID for pstree (doesn't
      # matter which).
      PSTREE=$(pstree -su $(fuser $LOCKFILE 2>/dev/null | awk '{print $1}'))
      # If given an empty command line, or a nonexistent PID, pstree -su will
      # output all processes on the system, which isn't helpful.  Normal usage
      # of this script should only ever yield a single line of pstree output.
      if [ $(echo "$PSTREE" | wc -l) -eq 1 ]
      then
        PSTREE="locking process tree: $PSTREE"
      else
        PSTREE="could not determine lock holder"
      fi
      printf "E: failed to lock, another puppet-merge running on this host?\n%s\n" "${PSTREE}" >&2
      exit 1
  fi
}
check_remote_error() {
  exit_code=$1
  worker=$2
  repo=$3
  if [ ${exit_code} -eq 0 ]; then
    echo "${GREEN}OK${RESET}: puppet-merge on ${worker} (${repo}) succeeded"
  elif [ ${exit_code} -eq 99 ]; then
    echo "${CYAN}NO CHANGE${RESET}: puppet-merge on ${worker} (${repo}) no change"
  else
    echo "${RED}ERROR${RESET}: puppet-merge on ${worker} (${repo}) failed"
  fi
}

merge() {
  servers=$1
  repo=$2
  sha=$3
  user=$4
  for server in ${servers}; do
    echo "${CYAN}===> Starting run${RESET} on ${server}..."
    su - $git_user -c "ssh -t -t ${server} true --${repo} ${sha} 2>&1"
    check_remote_error $? ${server} ${repo}
    echo
  done
}
FORCE=0
USAGE=0
QUIET=0
LABS_PRIVATE=0
DIFF_ONLY=0

usage="$(basename ${0}) [-y|--yes] [-p|--labsprivate] [-q|--quiet] [-d|--diffs] [SHA1]

Fetches changes from origin and from all submodules.
Shows diffs between HEAD and SHA1 (default FETCH_HEAD)
and prompts for confirmation.

If the changes are acceptable, HEAD will be fast-forwarded
to SHA1.

It also runs conftool-merge if necessary.

SHA1 equals FETCH_HEAD if not specified.

If no SHA1 is specified, and --labsprivate is not specified,
runs on both the ops and labsprivate repos.

-y / --yes: skip prompting for confirmation
-p / --labsprivate: merge only the labsprivate repo
-d / --diffs: only show diffs, don't perform any merges
-q / --quiet: don't output diffs
"
# preserve arguments before we shift them all
# Our original arguments get passed on, unchanged, to puppet-merge.py.
ORIG_ARGS="$@"
TEMP=$(getopt -o yhqd --long yes,help,quiet,labsprivate,diffs -n "$0" -- "$@")
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

eval set -- "$TEMP"
while true; do
    case "$1" in
        -y|--yes) FORCE=1; shift ;;
        -h|--help) USAGE=1; shift ;;
        -q|--quiet) QUIET=1; shift ;;
        -d|--diffs) DIFF_ONLY=1; shift ;;
        -p|--labsprivate) LABS_PRIVATE=1; shift ;;
        --) shift ; break ;;
        *) echo "Internal error!"; exit 1 ;;
    esac
done

if [ $USAGE -eq 1 ]; then
    echo "$usage" && exit 0;
fi

lock $LABS_PRIVATE

# This will either be empty (if a sha1/treeish was passed to us, and thus,
# is included already in $ORIG_ARGS), or it will contain 'FETCH_HEAD'.
# This way, puppet-merge.py always receives some treeish.
FETCH_HEAD_OR_EMPTY=$([ -n "${1:-}" ] || echo FETCH_HEAD)

# From this point continue despite errors on remote masters. After a change
# has been merged on the local master a remote merge failure should not
# cause all remaining masters to be aborted and left out of sync.
set +e

if [ $LABS_PRIVATE -eq 1 ]; then
    # if --labsprivate is used just sync the labsprivate repo
    /usr/local/bin/puppet-merge.py $ORIG_ARGS $FETCH_HEAD_OR_EMPTY
    LABS_EXIT=$?
else
    # We want to do a labs merge every time we do an ops merge -- except if
    # the user gave us an explicit sha1, which only makes sense for one repo.
    if [ -n "${FETCH_HEAD_OR_EMPTY}" ]; then
      /usr/local/bin/puppet-merge.py --labsprivate $ORIG_ARGS $FETCH_HEAD_OR_EMPTY
      LABS_EXIT=$?
    fi
    /usr/local/bin/puppet-merge.py --ops $ORIG_ARGS $FETCH_HEAD_OR_EMPTY
    PROD_EXIT=$?
fi
# puppet-merge.py exits with 99 if no merge was performed
if [ ${PROD_EXIT} -eq 99 -a ${LABS_EXIT} -eq 99 ]; then
  printf '%sNo changes to merge%s\n' "${GREEN}" "${RESET}"
  exit 0
elif [ ${PROD_EXIT} -eq 99 ]; then
  printf '%sNo Production changes to merge%s\n' "${GREEN}" "${RESET}"
elif [ ${LABS_EXIT} -eq 99 ]; then
  printf '%sNo LABS changes to merge%s\n' "${GREEN}" "${RESET}"
elif [ ${PROD_EXIT} -ne 0 ]; then
  printf '%sProblems merging production%s\n' "${RED}" "${RESET}"
elif [ ${LABS_EXIT} -ne 0 ]; then
  printf '%sProblems merging LABS%s\n' "${RED}" "${RESET}"
fi

# Grab the SHAs that were exported by the Python script, so that
# on the remote hosts, we merge exactly the set of changes we prompted
# the local user to confirm merging.
LABSPRIVATE_SHA=$(cat /srv/config-master/labsprivate-sha1.txt)
OPS_SHA=$(cat /srv/config-master/puppet-sha1.txt)

# Note: The "true" command is passed on purpose to show that the command passed
# to the SSH sessions is irrelevant. It's the SSH forced command trick on the
# worker end that does the actual work. Note that args (the SHA1 and
# --labsprivate/--ops switch) are used.

if [ $LABS_PRIVATE -eq 1 -a ${LABS_EXIT} -eq 0 ]; then
  merge "${MASTERS}" 'labsprivate' "${LABSPRIVATE_SHA}" "${git_user}"
elif [ $LABS_PRIVATE -eq 0 ]; then
  if [ ${LABS_EXIT} -eq 0 ]; then
    merge "${MASTERS}" 'labsprivate' "${LABSPRIVATE_SHA}" "${git_user}"
  fi
  if [ ${PROD_EXIT} -eq 0 ]; then
    merge "${WORKERS}" 'ops' "${OPS_SHA}" "${git_user}"
  fi
fi

# Only run this once, and only if we're merging the prod repo
if [ $LABS_PRIVATE -eq 0 ]; then
    echo "Now running conftool-merge to sync any changes to conftool data"
    /usr/local/bin/conftool-merge
fi
# vim: set syntax=sh:

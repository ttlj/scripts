#! /bin/bash
# Deletes remote git branches which are older than N weeks and have been merged
#

CURR_BRANCH=$(git rev-parse --abbrev-ref HEAD)

function process_args {
  while getopts ":hlw:" opt; do
    case $opt in
      w)
        WEEKS=$OPTARG
        ;;
      l)
        LIVE=1
        ;;
      h)
        usage
        exit 1
        ;;
      :)
        echo "Option -$OPTARG requires an argument." >&2
        usage
        exit 1
        ;;
    esac
  done

  WEEKS=${WEEKS:-8}
  LIVE=${LIVE:-0}

}

function usage {
    cat <<EOF
Usage: $0 [-w <weeks>] [-l]
   -w <weeks> - latest commit is as least <weeks> weeks old; default=8
   -l         - actually remove the branches instead of just showing what to run
   -h         - show this help

Remove merged branches whose latest commit is at least <weeks> old.
Never removes branches: develop, master, release/[0-9].

NOTE: Only branches merged into the current branch will be listed!
      Current branch: ${CURR_BRANCH}
EOF
}

function get_limit {
  unamestr=$(uname)
  if [[ "$unamestr" == 'Darwin' ]]; then
    LIMIT=$(date -j -v-${WEEKS}w +%s)
  else
    LIMIT=$(date --date="$WEEKS weeks ago" +%s)
  fi
}

function get_branches {
  git for-each-ref --sort=-committerdate refs/remotes --format="%(refname) %(committerdate:raw)"
}

function filter_by_date {
  while read branch date zone; do 
    if [[ "$date" -le "$LIMIT" ]]; then
      echo $branch
    fi

  done
}

function clean_branch_name {
  sed -e 's~^\s\+~~'              \
  | sed -e 's~refs/~~'            \
  | sed -e 's~remotes/origin/~~'  \
  | sed -e 's~^[ ]*origin/~~'
}

function merged_branches {
  git branch -r --merged
}

function delete_branches {
  while read branch; do
    if [[ "$LIVE" -eq "1" ]]; then
      # echo "Live"
      git push origin --delete $branch
    else
      echo "git push origin --delete $branch"
    fi
  done
}



# MAIN

process_args "$@"

get_limit

git fetch --prune --all --quiet


if [[ "$LIVE" -eq "1" ]]; then
    # echo "Live"
    echo "Deleting branches merged into '${CURR_BRANCH}'!"
    read -p "Are you sure (y/n)? " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
        echo "Aborting..."
        exit 1
    fi
else
    echo "Branches for deletion (merged into: ${CURR_BRANCH}):"
    echo ""
fi


old_branches=$(mktemp /tmp/purge-branches.XXXXXX)
merged_branches=$(mktemp /tmp/purge-branches.XXXXXX)

# echo old, $old_branches
# echo merged, $merged_branches

get_branches \
  | filter_by_date \
  | clean_branch_name \
  | sort \
  > $old_branches

merged_branches | grep -F -v ' -> ' | grep -F -v 'master' \
  | grep -F -v 'develop' | grep -E -v 'release\/[0-9]' \
  | clean_branch_name \
  | sort \
  > $merged_branches

# wc -l $merged_branches

join $old_branches $merged_branches \
  | delete_branches


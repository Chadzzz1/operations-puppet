#!/usr/bin/env bash

# Watch error log spam.  See /usr/bin/logspam for log-filtering implementation
# details.

set -eu

# shellcheck disable=SC1091
. /etc/profile.d/mw-log.sh

# Define some control characters - see tput(1):
readonly BOLD=$(tput bold)
readonly UNDERL=$(tput smul)
readonly NORMAL=$(tput sgr0)
readonly COLOR=$(tput setaf 2)

COLUMN_LABELS=(
  [1]="count"
  [2]="first"
  [3]="last"
  [4]="exception          "
  [5]="message"
)

# Our "view":
function display {
  logspam_output=$(run_logspam)
  # Only refresh if we've got new info - saves some terminal flashing:
  if [ "$old_logspam_output" == "$logspam_output" ]; then
    return
  fi
  old_logspam_output="$logspam_output"

  tput clear
  # Print column headers, highlighting the currently-selected sort and bolding
  # column numbers to indicate that they're hotkeys:
  for column in ${!COLUMN_LABELS[*]}; do
    printf '%s%s%s' "$BOLD" "$column" "$NORMAL"
    if [ "$sort_key" == "$column" ]; then
      printf "%s" "$COLOR$UNDERL"
    fi
    printf '%s%s\t' "${COLUMN_LABELS[$column]}" "$NORMAL"
  done

  printf '\n%s\n' "$logspam_output"

  # Current date and pattern, plus some pointers to hotkeys:
  printf '[%s]' "$COLOR$(date '+%H%M %Z')$NORMAL"
  printf '  [%sp%sattern: %s]' "$BOLD" "$NORMAL" "$COLOR$filter$NORMAL"
  printf '  [%s12345%s sort]  [%sq%suit] ' "$BOLD" "$NORMAL" "$BOLD" "$NORMAL"
}

function run_logspam {
  # shellcheck disable=SC2086
  logspam "$filter" | \
    sort $sort_dir $sort_type -t$'\t' -k "$sort_key" | \
    head -n "$(listing_height)"
}

# Get a height for the error listing that accounts for the current height of
# the terminal and leaves space for column & filter indicators:
function listing_height {
  local lines
  lines="$(tput lines)"
  printf "%d" $((lines - 3))
}

function flip_sort {
  if [ "$sort_dir" == '-r' ]; then
    sort_dir=''
  else
    sort_dir='-r'
  fi
}

# State variables:
old_logspam_output=''
sort_key=1
sort_type='-n'
sort_dir='-r'
filter='.*'

# Control loop - poll using read every "tick" and update display:
readonly MAXTICKS=10
readonly TICK_LEN=1
quit=""
ticks="$MAXTICKS"
while [ -z "$quit" ]; do
  if ((ticks >= MAXTICKS)); then
    ticks=0
    display
  fi

  ((++ticks))

  # Silently (-s) read 1 character of input (-n1) with a timeout of $TICK_LEN
  # seconds (-t$TICK_LEN), and don't error out if nothing is read:
  read -s -r -n1 -t$TICK_LEN input || true

  if [ ! -z "$input" ]; then
    case "$input" in
      [12345])
        # If we're already sorting on this column, flip the direction:
        if [ "$input" == "$sort_key" ]; then
          flip_sort
        fi

        # Numeric by default, alpha for exception class and error message:
        sort_type='-n'
        if [ "$input" == '4' ] || [ "$input" == '5' ]; then
          sort_type=''
        fi

        sort_key="$input"
        ticks="$MAXTICKS"
        ;;

      [pgf/])
        printf '\n'
        read -r -p 'new pattern (perl regex): ' -ei "$filter" filter
        if [ -z "$filter" ]; then
          filter='.*'
        fi
        ticks="$MAXTICKS"
        ;;

      [qQ])
        quit="yep"
        ;;
    esac
  fi
done

echo
exit 0

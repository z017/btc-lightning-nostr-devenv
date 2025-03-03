#!/usr/bin/env bash
#
# Common script configurations and utilities
# This should only be sourced, not executed directly
#
# https://github.com/z017/shell-script-skeleton

# Bash strict mode
set -Eeuo pipefail

readonly SHELL_SCRIPT_SKELETON_VERSION=0.1.0
readonly SHELL_SCRIPT_SKELETON_URL=http://github.com/z017/shell-script-skeleton

# -----------------------------------------------------------------------------
# Logs
# -----------------------------------------------------------------------------
declare -i LOG_INCLUDE_TIME=${LOG_INCLUDE_TIME-1}
declare LOG_TIME_FMT=${LOG_TIME_FMT-"%Y/%m/%d %H:%M:%S"}

declare -i LOG_INCLUDE_SEVERITY=${LOG_INCLUDE_SEVERITY-1}
declare LOG_LEVEL=${LOG_LEVEL-0}

readonly SEVERITY_RANGES=(-8 -4 0 4 8 12)
readonly SEVERITY_RANGES_NAMES=(trace debug info warn error fatal)
readonly SEVERITY_RANGES_SHORTNAMES=(TRC DBG INF WRN ERR FTL)
readonly SEVERITY_RANGES_COLORS=(62 63 86 192 204 134)

# Set log level using the severity name or number
# Usage: log_level severity_number|severity_name
function log_level() {
  local level=${1-$LOG_LEVEL}
  if [[ "$level" =~ ^[-]?[0-9]+$ ]]; then
    # level is a number
    LOG_LEVEL=$level
  else
    # level is a range name
    level=$(echo $level | tr "A-Z" "a-z")
    local found=0
    for i in "${!SEVERITY_RANGES_NAMES[@]}"; do
      if [[ "${SEVERITY_RANGES_NAMES[$i]}" == "$level" ]]; then
        level="${SEVERITY_RANGES[$i]}"
        found=1
        break
      fi
    done
    [[ "$found" == 0 ]] && fatal "invalid log level '$level', must be one of: ${SEVERITY_RANGES_NAMES[@]}"
    LOG_LEVEL=$level
  fi
}

# Run once to ensure LOG_LEVEL is a number.
# If LOG_LEVEL is a severity name, use the associated severity number.
log_level "$LOG_LEVEL"

# Log trace messages to stderr
function trace() {
  log -8 "$*"
}

# Log debug messages to stderr
function debug() {
  log -4 "$*"
}

# Log info messages to stderr
function info() {
  log 0 "$*"
}

# Log warning messages to stderr
function warn() {
  log 4 "$*"
}

# Log error messages to stderr
function error() {
  log 8 "$*"
}

# Log fatal messages to stderr and exit with status 1
function fatal() {
  log 12 "$*"
  exit 1
}

# Log messages to stderr with custom severity level
# Params: severity_level messages...
function log() {
  local severity_level=$1
  shift
  # if severity level is lower than log level, messages are discarded
  [[ $severity_level -lt $LOG_LEVEL ]] && return 0

  if [[ $LOG_INCLUDE_TIME -ne 0 ]]; then
    # print time with defined format
    local time=$(date "+$LOG_TIME_FMT")
    printf "\033[2;39m%s\033[0;00m " $time >&2
  fi

  if [[ $LOG_INCLUDE_SEVERITY -ne 0 ]]; then
    # print severity level
    local range=${SEVERITY_RANGES[0]}
    local range_index=0
    if [[ $severity_level -gt $range ]]; then
      for current_range in "${SEVERITY_RANGES[@]:1}"; do
        [[ $severity_level -lt $current_range ]] && break
        range=$current_range
        range_index=$((range_index + 1))
      done
    fi
    local severity_name="${SEVERITY_RANGES_SHORTNAMES[$range_index]}"
    local severity_color="${SEVERITY_RANGES_COLORS[$range_index]}"
    printf "\033[1;38;5;%dm%s\033[0;00m " $severity_color $severity_name >&2
  fi

  # print log
  printf -- "$*\n" >&2
}

# log_key key value
# Print to stdout a formatted key value for logs only if value is not an empty
# string.
# Example: info "log in successful$(log_key user $user)"
function log_key() {
  [[ $# -lt 2 || -z $2 ]] && return 0
  printf " \033[2;39m%s=\033[0;00m%s" $1 $2
}

# -----------------------------------------------------------------------------
# Ensure script is sourced
# -----------------------------------------------------------------------------
[[ -n "$BASH_VERSION" ]] || fatal "This file must be sourced from bash."
[[ "$(caller 2>/dev/null | awk '{print $1}')" != "0" ]] || fatal "This file must be sourced, not executed."

# -----------------------------------------------------------------------------
# Utility functions
# -----------------------------------------------------------------------------

# Load environment from file
function load_environment() {
  [[ $# -lt 1 ]] && error "load_environment requires env file" && return 1
  # parse env file param
  local env_file=$1
  [[ ! -f "$env_file" ]] && error "env must be a file$(log_key env $env_file)" && return 1
  # parse env
  set -a;
  source "$env_file";
  set +a;
}

# Load environment from file if exists
function load_environment_if_exists() {
  [[ $# -lt 1 ]] && error "load_environment_if_exists requires env file" && return 1
  # parse env file param
  local env_file=$1
  [[ ! -f "$env_file" ]] && return 0
  # parse env
  set -a;
  source "$env_file";
  set +a;
}

# Check if function exists
function fn_exists() {
  declare -F "$1" > /dev/null
}

# Ensure script is running as sudo
# Usage: ensure_sudo "$@"
# If you want to make execute_command run as sudo use ensure_sudo in on_init
# because execute_command arguments contain only the command params not all the
# script arguments.
function ensure_sudo() {
  if [[ $(id -u) -ne 0 ]]; then
    info "script require root privileges, trying sudo"
    exec sudo --preserve-env "$0" "$@"
  fi
}

# Shows an error if required tools are not installed.
function required {
  local e=0
  for tool in "$@"; do
    type $tool >/dev/null 2>&1 || {
      e=1 && error "$tool is required"
    }
  done
  [[ $e < 1 ]] || fatal "please install missing tools required for running this script and try again"
}

# Parse template file variables in the format "{{ VAR }}" with the value of "VAR".
# parse_template <input file template> <output file or directory>
function parse_template {
  [[ $# -lt 2 ]] && error "parse_template requires input and output" && return 1
  # parse input param
  local input=$1
  [[ ! -f "$input" ]] && error "input must be a file$(log_key input $input)" && return 1
  local filename="${input##*/}"
  # parse output param
  local output=$2
  [[ "$output" != "${output%/*}" ]] && mkdir -p "${output%/*}"
  [[ "$output" == */ ]] && output="${output%/}"
  [[ -d "$output" ]] && output="$output/$filename"
  # get template variables
  local -A vars=()
  while read -r line; do
    while [[ "$line" =~ \{\{[[:blank:]]*([a-zA-Z_][a-zA-Z_0-9]*)[[:blank:]]*\}\} ]]; do
      [[ ! -v vars[${BASH_REMATCH[1]}] ]] && vars[${BASH_REMATCH[1]}]=
      line="${line#*"${BASH_REMATCH[0]}"}"
    done
  done < $input
  # check if variables are defined and prepare sed arguments
  local has_error=0
  local sed_args=""
  for v in "${!vars[@]}"; do
    if [[ -z "${!v:-}" ]]; then
      error "template variable is undefined$(log_key var $v)$(log_key tpl $filename)"
      has_error=1
    else
      sed_args="${sed_args}s~{{ *$v *}}~${!v}~g;"
    fi
  done
  [[ "$has_error" == 1 ]] && return 1
  # generate output from input replacing variables
  sed "$sed_args" < $input > $output
}

# Parse all template files with a .tpl in the name from the input_dir and saved
# them to the output_dir removing the ".tpl".
# parse_templates <input_dir> <output_dir>
function parse_templates {
  [[ $# -lt 2 ]] && error "parse_templates requires input_dir and output_dir" && return 1
  # parse input param
  local input="${1%/}"
  [[ ! -d "$input" ]] && error "input must be a directory$(log_key input $input)" && return 1
  # parse output param
  local output="${2%/}"
  [[ ! -d "$output" ]] && error "output must be a directory$(log_key output $output)" && return 1
  # parse each template
  for file in "$input/"*.tpl*; do
    local filename=${file##*/}
    [[ $filename == '*.tpl*' ]] && debug "no templates ".tpl" found$(log_key input $input)" && return 0
    local outfile=${filename%.tpl*}${filename##*.tpl}
    parse_template $file $output/$outfile
  done
}

# Parse the arguments and executes the following functions:
# - on_init with the raw script arguments, before parsing the options. It can
#   be used to load environment.
# - on_option with the short or long option found, OPTARG contains the option
#   argument if defined. The valid options must be declared in LONG_OPTS and
#   SHORT_OPTS with a : (colon) after the proper option to expect an
#   argument.
# - before_execute with the arguments, before calling execute_command. It can
#   be used to set script variables modified by options to readonly.
# - execute_command with the arguments.
# If a list of valid commands are defined in COMMANDS the first argument is
# the command to be executed or '--' by default.
function parse_and_execute() {
  # call on_init if exists
  fn_exists on_init && on_init "$@"

  local only_args=0 # 1 is true, 0 is false
  local args=()
  if [[ "${1-}" == -?* ]]; then
    only_args=1
    local OPT
    while get_options "$@"; do
      if [[ "$OPT" == -- ]]; then
        # add param to accumulated arguments
        args+=($OPTARG)
        # the first argument could be a command
        only_args=0
        continue
      fi
      # verify errors
      case "$OPT" in
          ::)	fatal "Unexpected argument to option '$OPTARG'"; ;;
          :)	fatal "Missing argument to option '$OPTARG'"; ;;
          \?)	fatal "Unknown option '$OPTARG'"; ;;
      esac
      [[ "${OPTARG-}" =~ ^-[A-Za-z-]+ ]] && fatal "Missing argument to option '$OPT'"
      # call on_option if exists
      fn_exists on_option && on_option "$OPT"
    done
    shift $((OPTIND-1))
  fi

  # the remaining params are arguments
  args+=(${@})

  local send_command=1
  if [[ -z "${COMMANDS-}" || "${#COMMANDS[@]}" == 0 ]]; then
    # if valid commands are not defined, the first argument is not a command
    send_command=0
    only_args=1
  fi

  if [[ "$only_args" == 0 ]]; then
    # check if the first argument is a valid command
    only_args=1
    for valid_cmd in "${COMMANDS[@]}"; do
      if [[ "$valid_cmd" == "${args[0]}" ]]; then
        # the first argument is a command
        only_args=0
        break
      fi
    done
  fi

  if [[ "$only_args" == 1 && "$send_command" == 1 ]]; then
    # send '--' as the default command
    args=('--' ${args[@]})
  fi

  # call before_execute if exists
  fn_exists before_execute && before_execute "${args[@]}"

  # ensure log level is a number and make globals readonly
  log_level $LOG_LEVEL
  readonly LOG_TIME_FMT LOG_INCLUDE_TIME LOG_INCLUDE_SEVERITY LOG_LEVEL

  # call execute_command if exists
  fn_exists execute_command && execute_command "${args[@]}"
}

# Internal function used by parse_arguments to parse short and long options
# from arguments.
# Support options between commands or command arguments.
# All params after '--' are considered command arguments.
function get_options() {
  if [[ $# -lt $OPTIND ]]; then
    # no more params
    return 1
  fi
  OPT="${!OPTIND}"
  if [[ "$OPT" == -- ]]; then
    # only arguments left
    OPTIND=$((OPTIND+1))
    return 1
  elif [[ "$OPT" == --?* ]]; then
    # long option
    OPT="${OPT#--}"
    OPTIND=$((OPTIND+1))
    OPTARG=
    local has_arg=0
    if [[ "$OPT" == *=* ]]; then
      # option has an argument
      OPTARG="${OPT#*=}"
      OPT="${OPT%=$OPTARG}"
      has_arg=1
    fi
    # check if option is valid
    local state=0
    for valid_option in "${LONG_OPTS[@]}"; do
      [[ "$valid_option" == "$OPT" ]] && state=1 && break
      [[ "${valid_option%:}" == "$OPT" ]] && state=2 && break
    done
    if [[ $state = 0 ]]; then
      # unknown option
      OPTARG="$OPT"
      OPT='?'
    elif [[ $state = 1 && $has_arg = 1 ]]; then
      # unexpected argument to option
      OPTARG="$OPT"
      OPT='::'
    elif [[ $state = 2 && $has_arg = 0 ]]; then
      if [[ $# -ge $OPTIND ]]; then
        # next param is the option argument
        OPTARG="${!OPTIND}"
        OPTIND=$((OPTIND+1))
      else
        # missing argument to option
        OPTARG="$OPT"
        OPT=':'
      fi
    fi
    return 0
  elif [[ "$OPT" == -?* ]]; then
    # short option
    getopts ":${SHORT_OPTS-}" OPT
  else
    # command or argument
    OPTARG="$OPT"
    OPT='--'
    OPTIND=$((OPTIND+1))
    return 0
  fi
}

# Help command
# Prints a default help message.
# Define the function help_message to customize.
function execute_help() {
  if fn_exists help_message; then
    help_message
    exit 0
  fi

  if [[ "${SCRIPT_DESCRIPTION-}" ]]; then
    # description
    printf "\n  %s\n" "${SCRIPT_DESCRIPTION}"
  fi
  # usage
  printf "\nUsage:\n  %s " ${SCRIPT_NAME-0##*/}
  local so=${SHORT_OPTS-}
  local lo=${LONG_OPTS-}
  local c=${COMMANDS-}
  [[ "${#so}" > 0 || "${#lo}" > 0 ]] && printf "[options] "
  [[ "${#c}" > 0 ]] && printf "[command] "
  printf "[args]\n\n"
  # commands
  if [[ "${#c}" > 0 ]]; then
    printf "Available Commands:\n"
    for cmd in "${COMMANDS[@]}"; do
      printf "  %s\n" "$cmd"
    done
    printf "\n"
  fi
  # long options
  if [[ "${#lo}" > 0 ]]; then
    printf "Long Options:\n"
    for opt in "${LONG_OPTS[@]}"; do
      local has_arg=""
      [[ $opt =~ [:]$ ]] && has_arg=" arg" && opt=${opt%:}
      printf "  --%s%s\n" "$opt" "$has_arg"
    done
    printf "\n"
  fi
  # short options
  if [[ "${#so}" > 0 ]]; then
    printf "Short Options:\n"
    for ((i = 0; i < ${#so}; i++)); do
      local opt=${so:$i:1}
      local next=$((i+1))
      local has_arg=""
      [[ $next < ${#so} && ${so:$next:1} == ":" ]] && has_arg=" arg" && i=$next
      printf "  -%s%s\n" "$opt" "$has_arg"
    done
    printf "\n"
  fi
  exit 0
}

# Version command
# Prints a default version message using SCRIPT_NAME and SCRIPT_VERSION to
# stdout.
# Define the function version_message to customize.
function execute_version() {
  if fn_exists version_message; then
    version_message
  else
    printf "%s version %s\n" ${SCRIPT_NAME-0##*/} ${SCRIPT_VERSION-unknown}
    printf "\nGenerated by shell-script-skeleton %s <%s> %s\n" $SHELL_SCRIPT_SKELETON_VERSION $SHELL_SCRIPT_SKELETON_URL
  fi
  exit 0
}

# Convert INPUT string into a number saving it into OUTPUT variable.
# int_val "INPUT" "OUTPUT" [SET_READONLY=false]
function int_val() {
  # remove 0 prefix to avoid invalid base number interpretations
  # https://stackoverflow.com/questions/8078167/printf-in-bash-09-and-08-are-invalid-numbers-07-and-06-are-fine
  local input="${1#0}"
  local output_var_name="$2"
  local set_readonly=${3-false}

  local ERRTEXT="expected a number, got '$input'"
  printf -v "$output_var_name" '%d\n' "$input" 2>/dev/null
  [[ $set_readonly = true ]] && readonly "$output_var_name" || true
}

# -----------------------------------------------------------------------------
# Apt
# -----------------------------------------------------------------------------

readonly APT_UPDATE_INTERVAL=$((24 * 60 * 60)) # 24 hours
declare -i APT_HAS_NEW_REPOSITORY=0

# requires sudo
function apt_repository() {
  local repository="$1"
  local source_list="${2-}"
  local repository_lookup="$repository"
  if [[ "$repository" == ppa:* ]]; then
    repository_lookup="${repository##*:}"
    [[ -n "$source_list" ]] && warn "ppa repository ignores custom source list: $source_list"
    source_list=
  fi

  # check if already added
  local repositories=$(sudo cat /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null | grep ^[^#])
  echo "$repositories" | grep -qF "$repository_lookup" && return

  # add repository
  info "apt add repository: $repository"
  if [[ -z "$source_list" ]]; then
    sudo add-apt-repository -y "$repository"
  else
    write_file "$repository" "$source_list" --sudo
  fi
  # don't skip apt update on next call
  APT_HAS_NEW_REPOSITORY=1
}

# requires sudo
# https://askubuntu.com/questions/410247/how-to-know-last-time-apt-get-update-was-executed
function apt_update() {
  if [[ $APT_HAS_NEW_REPOSITORY -eq 0 ]]; then
    local apt_last_update_time=$(stat -c %Y '/var/cache/apt/pkgcache.bin')
    local current_time=$(date +'%s')
    local delta=$((current_time - apt_last_update_time))

    if [[ "${delta}" -lt "${APT_UPDATE_INTERVAL}" ]]; then
      local formatted_delta="$(date -u -d @"${delta}" +'%-Hh %-Mm %-Ss')"
      debug "apt update: skip because last run was $formatted_delta ago"
      return
    fi
  fi

  info "apt update"
  sudo apt update || true
  APT_HAS_NEW_REPOSITORY=0

  info "apt upgrade"
  sudo apt upgrade -y
}

# requires sudo
function apt_install() {
  for pkg in $*; do
    dpkg --verify $pkg 2>/dev/null ||
    (
        info "apt install: $pkg"
        sudo apt install -y $pkg
    )
  done
}

# Write to file
# By default append content, add a newline and runs with no sudo.
# write_file $content $file --no-append --sudo --no-newline
function write_file() {
  local content="$1"
  local file="$2"
  local -i is_append=1
  local -i is_sudo=0
  local newline="\n"
  for opt in "${@:3}"; do
    case "$opt" in
      "--no-append")  is_append=0 ;;
      "--sudo")       is_sudo=1 ;;
      "--no-newline") newline="" ;;
      *)              fatal "unmatched option '$opt'" ;;
    esac
  done

  local cmd="tee"
  [[ is_append -eq 1 ]] && cmd+=" -a"
  [[ is_sudo -eq 1 ]] && cmd="sudo $cmd"

  printf -- "$content$newline" | $cmd "$file" >/dev/null
}

function recursive_copy() {
  local from="$1"
  local to="$2"
  local -i is_overwrite=0
  for opt in "${@:3}"; do
    case "$opt" in
      "--overwrite")  is_overwrite=1 ;;
      *)              fatal "unmatched option '$opt'" ;;
    esac
  done

  local _RECURSIVE_COPY_ORIGINAL_TO="${_RECURSIVE_COPY_ORIGINAL_TO:-"$to"}"

  [[ -d "$from" ]] || fatal "from '$from' must be a directory"
  [[ $(ls -A "$from" | wc -l) -eq 0 ]] && return # directory is empty, nothing to copy

  for from_file in "$from/"*; do
    local to_file="$to/${from_file##"$from/"}"
    if [[ -d "$from_file" ]]; then
      # is a directory
      recursive_copy "$from_file" "$to_file" "${@:3}"
      continue
    fi
    local relative_path="${to_file##"$_RECURSIVE_COPY_ORIGINAL_TO/"}"
    if [[ -f "$to_file" ]]; then
      # already copied
      if ! cmp -s "$from_file" "$to_file"; then
        # file has changed
        if [[ $is_overwrite -eq 1 ]]; then
          # overwrite file
          info "overwrite $relative_path"
          cp "$from_file" "$to_file"
        else
          # avoid overwrite but warn
          warn "file $relative_path already exists and is different from input"
        fi
      fi
      continue
    fi

    # ensure directory exists
    local parent_dir="$(dirname "$to_file")"
    [[ -d "$parent_dir" ]] || mkdir -p "$parent_dir"

    # copy file
    info "generate $relative_path"
    cp "$from_file" "$to_file"
  done
}

function sync_directories() {
  local input_dir="$1"
  local output_dir="$2"
  local -i is_overwrite=0
  for opt in "${@:3}"; do
    case "$opt" in
      "--overwrite")  is_overwrite=1 ;;
      *)              fatal "unmatched option '$opt'" ;;
    esac
  done

  # first copy from input to output
  local copy_flags=""
  [[ $is_overwrite -eq 1 ]] && copy_flags+=" --overwrite"
  recursive_copy "$input_dir" "$output_dir" $copy_flags

  # then check which files or directories are only in output directory
  local files_not_expected=$(diff -r "$output_dir" "$input_dir" | grep "$output_dir" | awk -F'[: ]' '{print $3"/"$5}' || true)
  for extra_file in $files_not_expected; do
    local relative_path="${extra_file##"$output_dir/"}"
    local label="file"
    [[ -d "$extra_file" ]] && label="directory"

    if [[ $is_overwrite -eq 1 ]]; then
      # remove extra file
      info "remove extra $label from output dir: $relative_path"
      rm -rf "$extra_file"
    else
      # keep extra file but warn
      warn "output dir has an extra $label: $relative_path"
    fi
  done
}

# -----------------------------------------------------------------------------
# Traps
# -----------------------------------------------------------------------------

# Error trap
#
# Declare ERRTEXT before a possible error ocurrence to replace default error
# message, for example add the next code as first line of a function:
# local ERRTEXT="bootnode section failed"
function error_trap() {
  fatal "${ERRTEXT:-script failed}$(log_key code ${1-})$(log_key line ${2-})$(log_key fn ${3-})"
}
trap 'error_trap $? ${LINENO-} ${FUNCNAME-}' ERR

# Shutdown trap
function shutdown_trap() {
  printf "\n" >&2
  info "interruption received, shutting down"
  trap '' ERR
  # if on_shutdown function exists, execute it
  fn_exists on_shutdown && on_shutdown
}
trap shutdown_trap SIGINT SIGTERM

# Exit trap
function exit_trap() {
  # if on_exit function exists, execute it
  fn_exists on_exit && on_exit
  exit
}
trap exit_trap EXIT

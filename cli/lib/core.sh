# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# rufus-cli - core runtime: globals, logging, error handling, cleanup, helpers.
#
# Part of rufus-cli, a Linux command-line port of Rufus (https://rufus.ie).
# Copyright (C) 2026 rufus-cli contributors
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Conventions used throughout the code base
# -----------------------------------------
#  * Functions report failure through their exit status.  A function that
#    fails for a reason worth showing to the user calls `fail "message"`,
#    which records the message in ERR_MSG, logs it and returns 1.
#  * Functions that "return a string" store it in the global REPLY instead of
#    printing it, so that hot paths (rendering, polling) never fork.
#  * Every external command that touches the system goes through `run` (or
#    one of its variants) so that the log always shows what was executed.
#  * `set -e` is deliberately NOT used: every call site checks what it needs.

[[ -n ${_RC_CORE_LOADED:-} ]] && return 0
_RC_CORE_LOADED=1

RC_NAME='rufus-cli'
RC_VERSION='0.1.0'
RC_RUFUS_VERSION='4.16'
RC_HOMEPAGE='https://github.com/serkenn/rufus-cli'

# Set by the entry script before anything else is sourced.
: "${RC_ROOT:=}"	# directory that contains lib/ and share/
: "${RC_SELF:=}"	# absolute path of the entry script

ERR_MSG=''		# last user-facing error message (see `fail`)
RC_TMP=''		# private temporary directory (created on demand)
RC_CANCELLED=0		# set to 1 when the user asked to cancel the running job
RC_JOB_ACTIVE=0		# 1 while a destructive job is running

# ---------------------------------------------------------------------------
# Environment sanity
# ---------------------------------------------------------------------------

# Refuse to run on a bash that is too old.  This file must stay parseable by
# old shells up to this point, so keep the syntax above conservative.
core_check_bash() {
	local major=${BASH_VERSINFO[0]:-0} minor=${BASH_VERSINFO[1]:-0}
	if ((major < 4 || (major == 4 && minor < 4))); then
		printf '%s: bash 4.4 or newer is required (found %s).\n' "$RC_NAME" "${BASH_VERSION:-unknown}" >&2
		return 1
	fi
	return 0
}

# Administrative tools live in sbin directories that are not in the PATH of
# regular users on Debian; make sure we can always find them.
core_fix_path() {
	local d
	for d in /usr/local/sbin /usr/sbin /sbin; do
		case ":$PATH:" in
			*":$d:"*) ;;
			*) PATH="$PATH:$d" ;;
		esac
	done
	export PATH
}

have() { command -v "$1" >/dev/null 2>&1; }

core_is_root() { ((EUID == 0)); }

# Name and home directory of the human who started us (also when re-executed
# through sudo/doas), used for the file browser's starting point and to hand
# ownership of log files back.
RC_INVOKER=''
RC_INVOKER_HOME=''
core_detect_invoker() {
	local user=${SUDO_USER:-${DOAS_USER:-${RUFUS_CLI_INVOKER:-}}}
	if [[ -z $user || $user == root ]]; then
		user=${USER:-${LOGNAME:-}}
		[[ -n $user ]] || user=$(id -un 2>/dev/null) || user=root
	fi
	RC_INVOKER=$user
	local home=''
	if have getent; then
		home=$(getent passwd "$user" 2>/dev/null | cut -d: -f6)
	fi
	if [[ -z $home || ! -d $home ]]; then
		if [[ $user == "${USER:-}" && -n ${HOME:-} ]]; then home=$HOME; else home=/root; fi
	fi
	[[ -d $home ]] || home=/
	RC_INVOKER_HOME=$home
}

# Re-execute the program as root, keeping the bits of the environment that
# influence presentation.  Does not return on success.
core_reexec_as_root() {
	core_is_root && return 0
	local -a keep=() envv=("RUFUS_CLI_REEXEC=1" "RUFUS_CLI_INVOKER=${USER:-}")
	local v
	keep=(LANG LANGUAGE LC_ALL LC_MESSAGES LC_CTYPE TERM COLORTERM NO_COLOR TERM_PROGRAM
		RUFUS_CLI_LANG RUFUS_CLI_ASCII RUFUS_CLI_COLOR RUFUS_CLI_DEBUG TMPDIR)
	for v in "${keep[@]}"; do
		[[ -n ${!v+x} ]] && envv+=("$v=${!v}")
	done
	if [[ -n ${RUFUS_CLI_REEXEC:-} ]]; then
		fail "could not obtain root privileges"
		return 1
	fi
	if have sudo; then
		exec sudo -- env "${envv[@]}" "$BASH" "$RC_SELF" "$@"
	elif have doas; then
		exec doas env "${envv[@]}" "$BASH" "$RC_SELF" "$@"
	fi
	fail "root privileges are required, and neither sudo nor doas is available"
	return 1
}

# ---------------------------------------------------------------------------
# Time
# ---------------------------------------------------------------------------

# now_s / now_ms: store the current time in REPLY without forking.
now_s() { printf -v REPLY '%(%s)T' -1; }
if [[ -n ${EPOCHREALTIME:-} ]]; then
	now_ms() {
		# EPOCHREALTIME is "seconds<decimal point>microseconds"; the decimal
		# point follows the locale, so strip whatever single non-digit it is.
		local t=${EPOCHREALTIME//[!0-9]/}
		REPLY=${t:0:${#t}-3}
	}
else
	now_ms() {
		printf -v REPLY '%(%s)T' -1
		REPLY=$((REPLY * 1000))
	}
fi

# rc_sleep SECONDS - fractional sleep that does not fork (falls back to sleep).
_RC_SLEEP_FD=''
rc_sleep() {
	if [[ -z $_RC_SLEEP_FD ]]; then
		# A pipe that nobody ever writes to: reading from it only ever times out.
		if ! { exec {_RC_SLEEP_FD}<> <(:); } 2>/dev/null; then
			_RC_SLEEP_FD='none'
		fi
	fi
	if [[ $_RC_SLEEP_FD == none ]]; then
		sleep "$1"
	else
		read -r -t "$1" -u "$_RC_SLEEP_FD" _ 2>/dev/null || true
	fi
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

LOG_FILE=''
LOG_VERBOSE=0		# 1: mirror log lines on stderr (plain CLI mode only)
LOG_KEEP=1		# keep the log file after a successful run

log_init() {
	local path=${1:-}
	if [[ -z $path ]]; then
		local stamp
		printf -v stamp '%(%Y%m%d-%H%M%S)T' -1
		path="${TMPDIR:-/tmp}/${RC_NAME}-${stamp}-$$.log"
	fi
	if ! (umask 077 && : >>"$path") 2>/dev/null; then
		path=/dev/null
	fi
	LOG_FILE=$path
	# When running through sudo, let the invoking user read their own log.
	if [[ $path != /dev/null && $EUID -eq 0 && -n ${SUDO_UID:-} && -n ${SUDO_GID:-} ]]; then
		chown "$SUDO_UID:$SUDO_GID" "$path" 2>/dev/null || true
	fi
	log "$RC_NAME $RC_VERSION (based on Rufus $RC_RUFUS_VERSION) - bash $BASH_VERSION"
}

log() {
	[[ -n $LOG_FILE ]] || return 0
	local line
	printf -v line '%(%H:%M:%S)T %s' -1 "$*"
	printf '%s\n' "$line" >>"$LOG_FILE" 2>/dev/null
	if ((LOG_VERBOSE)); then
		printf '%s\n' "$line" >&2
	fi
	return 0
}

log_debug() {
	[[ -n ${RUFUS_CLI_DEBUG:-} ]] || return 0
	log "[debug] $*"
}

# Log a command line in a copy-pasteable form.
log_cmd() {
	local s
	printf -v s '%q ' "$@"
	log "+ ${s% }"
}

# ---------------------------------------------------------------------------
# Running commands
# ---------------------------------------------------------------------------

# run CMD ARGS...   run a command, sending its output to the log.
run() {
	log_cmd "$@"
	local rc=0
	"$@" >>"${LOG_FILE:-/dev/null}" 2>&1 || rc=$?
	((rc == 0)) || log "  -> exit status $rc"
	return "$rc"
}

# run_quiet CMD ARGS...   like run, but a failure is not worth a log line.
run_quiet() {
	"$@" >>"${LOG_FILE:-/dev/null}" 2>&1
}

# run_capture VAR CMD ARGS...   stdout goes to VAR, stderr to the log.
run_capture() {
	local -n _rc_out=$1
	shift
	log_cmd "$@"
	local rc=0
	_rc_out=$("$@" 2>>"${LOG_FILE:-/dev/null}") || rc=$?
	((rc == 0)) || log "  -> exit status $rc"
	return "$rc"
}

# run_retry TRIES DELAY CMD ARGS...   retry a command that may be racing udev.
run_retry() {
	local tries=$1 delay=$2 i
	shift 2
	for ((i = 1; i <= tries; i++)); do
		run "$@" && return 0
		((i < tries)) && rc_sleep "$delay"
	done
	return 1
}

# ---------------------------------------------------------------------------
# Errors
# ---------------------------------------------------------------------------

# fail MESSAGE...   record a user-facing error and return 1.
fail() {
	ERR_MSG=$*
	log "ERROR: $*"
	return 1
}

# die MESSAGE...   unrecoverable error: report and exit.
die() {
	local msg=$*
	log "FATAL: $msg"
	if declare -F ui_fatal >/dev/null; then
		ui_fatal "$msg"
	else
		printf '%s: %s\n' "$RC_NAME" "$msg" >&2
	fi
	exit 1
}

# ---------------------------------------------------------------------------
# Cleanup stack and signal handling
# ---------------------------------------------------------------------------

declare -a _RC_CLEANUP=()
_RC_EXITING=0

# cleanup_push 'shell code'   register code to run at exit (LIFO).
# The code is stored as a string and evaluated; quote arguments with %q.
cleanup_push() { _RC_CLEANUP+=("$1"); }

# cleanup_remove 'shell code'   forget a previously registered handler.
cleanup_remove() {
	local i
	for ((i = ${#_RC_CLEANUP[@]} - 1; i >= 0; i--)); do
		if [[ ${_RC_CLEANUP[i]} == "$1" ]]; then
			unset '_RC_CLEANUP[i]'
			_RC_CLEANUP=("${_RC_CLEANUP[@]}")
			return 0
		fi
	done
	return 1
}

core_run_cleanup() {
	local i
	for ((i = ${#_RC_CLEANUP[@]} - 1; i >= 0; i--)); do
		eval "${_RC_CLEANUP[i]}" >>"${LOG_FILE:-/dev/null}" 2>&1 || true
	done
	_RC_CLEANUP=()
}

_core_on_exit() {
	local rc=$?
	((_RC_EXITING)) && return
	_RC_EXITING=1
	trap - EXIT
	trap '' INT TERM HUP
	core_run_cleanup
	core_remove_tmp
	exit "$rc"
}

# Signals: while a job is running we only raise a flag and let the job loop
# unwind in an orderly fashion; otherwise we just leave.
_core_on_signal() {
	local sig=$1
	if ((RC_JOB_ACTIVE)); then
		RC_CANCELLED=1
		log "signal $sig received: cancelling"
		return 0
	fi
	log "signal $sig received: exiting"
	case $sig in
		INT) exit 130 ;;
		TERM) exit 143 ;;
		HUP) exit 129 ;;
	esac
	exit 1
}

core_install_traps() {
	trap _core_on_exit EXIT
	trap '_core_on_signal INT' INT
	trap '_core_on_signal TERM' TERM
	trap '_core_on_signal HUP' HUP
}

# ---------------------------------------------------------------------------
# Temporary files
# ---------------------------------------------------------------------------

core_tmp_init() {
	[[ -n $RC_TMP && -d $RC_TMP ]] && return 0
	local base
	for base in "${TMPDIR:-}" /run /tmp /var/tmp; do
		[[ -n $base && -d $base && -w $base ]] || continue
		if RC_TMP=$(mktemp -d "$base/${RC_NAME}.XXXXXXXX" 2>/dev/null); then
			chmod 700 "$RC_TMP"
			return 0
		fi
	done
	RC_TMP=''
	fail "cannot create a temporary directory"
}

# core_mktemp_dir NAME   create a sub-directory of the private temp dir -> REPLY
core_mktemp_dir() {
	core_tmp_init || return 1
	REPLY=$(mktemp -d "$RC_TMP/${1:-tmp}.XXXXXX") || {
		fail "cannot create a temporary directory"
		return 1
	}
}

# core_mktemp_file NAME   create an empty file in the private temp dir -> REPLY
core_mktemp_file() {
	core_tmp_init || return 1
	REPLY=$(mktemp "$RC_TMP/${1:-tmp}.XXXXXX") || {
		fail "cannot create a temporary file"
		return 1
	}
}

# core_path_has_mounts DIR   true when something is still mounted at or below DIR.
core_path_has_mounts() {
	local dir=$1 _ mnt rest
	[[ -r /proc/self/mountinfo ]] || return 1
	# mountinfo field 5 is the mount point, with spaces encoded as \040.
	while read -r _ _ _ _ mnt rest; do
		mnt=${mnt//\\040/ }
		if [[ $mnt == "$dir" || $mnt == "$dir"/* ]]; then
			return 0
		fi
	done </proc/self/mountinfo
	return 1
}

# Remove the private temp dir - but never while something is still mounted
# inside it: a recursive delete would then wipe the freshly written media.
core_remove_tmp() {
	[[ -n $RC_TMP && -d $RC_TMP ]] || return 0
	case $RC_TMP in
		*/"${RC_NAME}".????????) ;;
		*) return 0 ;;
	esac
	if core_path_has_mounts "$RC_TMP"; then
		local _ mnt rest
		local -a mounts=()
		while read -r _ _ _ _ mnt rest; do
			mnt=${mnt//\\040/ }
			[[ $mnt == "$RC_TMP"/* ]] && mounts+=("$mnt")
		done </proc/self/mountinfo
		local i
		for ((i = ${#mounts[@]} - 1; i >= 0; i--)); do
			umount "${mounts[i]}" >>"${LOG_FILE:-/dev/null}" 2>&1 ||
				umount -l "${mounts[i]}" >>"${LOG_FILE:-/dev/null}" 2>&1 || true
		done
	fi
	if core_path_has_mounts "$RC_TMP"; then
		log "not removing $RC_TMP: something is still mounted inside"
		return 0
	fi
	rm -rf --one-file-system -- "$RC_TMP" 2>/dev/null || true
	RC_TMP=''
}

# ---------------------------------------------------------------------------
# Numbers and strings
# ---------------------------------------------------------------------------

# is_uint STR   true for a non-empty string of decimal digits.
is_uint() { [[ -n $1 && $1 != *[!0-9]* ]]; }

# human_size BYTES   -> REPLY, binary units with one decimal ("28.7 GiB").
human_size() {
	local b=${1:-0} i=0 div=1 tenths
	local -a u=(B KiB MiB GiB TiB PiB)
	is_uint "$b" || b=0
	while ((b >= div * 1024 && i < 5)); do
		div=$((div * 1024))
		i=$((i + 1))
	done
	if ((i == 0)); then
		REPLY="$b B"
		return 0
	fi
	tenths=$(((b * 10 + div / 2) / div))
	if ((tenths >= 10240 && i < 5)); then
		# Rounding carried us into the next unit (e.g. 1023.96 MiB -> 1.0 GiB).
		div=$((div * 1024))
		i=$((i + 1))
		tenths=$(((b * 10 + div / 2) / div))
	fi
	REPLY="$((tenths / 10)).$((tenths % 10)) ${u[i]}"
}

# human_size_si BYTES   -> REPLY, decimal units with one decimal ("30.9 GB").
human_size_si() {
	local b=${1:-0} i=0 div=1 tenths
	local -a u=(B kB MB GB TB PB)
	is_uint "$b" || b=0
	while ((b >= div * 1000 && i < 5)); do
		div=$((div * 1000))
		i=$((i + 1))
	done
	if ((i == 0)); then
		REPLY="$b B"
		return 0
	fi
	tenths=$(((b * 10 + div / 2) / div))
	if ((tenths >= 10000 && i < 5)); then
		div=$((div * 1000))
		i=$((i + 1))
		tenths=$(((b * 10 + div / 2) / div))
	fi
	REPLY="$((tenths / 10)).$((tenths % 10)) ${u[i]}"
}

# human_duration SECONDS   -> REPLY ("0:07", "12:34", "1:02:03").
human_duration() {
	local s=${1:-0}
	is_uint "$s" || s=0
	if ((s >= 3600)); then
		printf -v REPLY '%d:%02d:%02d' $((s / 3600)) $((s % 3600 / 60)) $((s % 60))
	else
		printf -v REPLY '%d:%02d' $((s / 60)) $((s % 60))
	fi
}

# parse_size STR   "512", "64K", "4M", "8G", "1T", "16KiB", "4096 bytes" -> REPLY (bytes)
parse_size() {
	local s=${1//[[:space:]]/} num unit
	s=${s,,}
	if [[ $s =~ ^([0-9]+)([a-z]*)$ ]]; then
		num=${BASH_REMATCH[1]}
		unit=${BASH_REMATCH[2]}
	else
		return 1
	fi
	# Leading zeros must not turn the value into an octal constant.
	num=$((10#$num))
	case $unit in
		'' | b | byte | bytes) REPLY=$num ;;
		k | kb | kib | kilobytes) REPLY=$((num * 1024)) ;;
		m | mb | mib | megabytes) REPLY=$((num * 1024 * 1024)) ;;
		g | gb | gib | gigabytes) REPLY=$((num * 1024 * 1024 * 1024)) ;;
		t | tb | tib | terabytes) REPLY=$((num * 1024 * 1024 * 1024 * 1024)) ;;
		*) return 1 ;;
	esac
}

# str_trim STR   -> REPLY without leading/trailing whitespace.
str_trim() {
	local s=$1
	s=${s#"${s%%[![:space:]]*}"}
	s=${s%"${s##*[![:space:]]}"}
	REPLY=$s
}

# str_squeeze STR   -> REPLY with runs of whitespace collapsed and trimmed.
str_squeeze() {
	local s=$1 word out=''
	for word in $s; do
		out+="${out:+ }$word"
	done
	REPLY=$out
}

# in_list NEEDLE ITEMS...   true when NEEDLE equals one of ITEMS.
in_list() {
	local needle=$1 x
	shift
	for x in "$@"; do
		[[ $x == "$needle" ]] && return 0
	done
	return 1
}

# file_size PATH   -> REPLY (bytes); block devices report their capacity.
file_size() {
	local p=$1 n
	if [[ -b $p ]]; then
		n=$(blockdev --getsize64 "$p" 2>/dev/null) || return 1
	else
		n=$(stat -L -c %s -- "$p" 2>/dev/null) || return 1
	fi
	is_uint "$n" || return 1
	REPLY=$n
}

# read_u8/le16/le32/le64 FILE OFFSET   read a little-endian integer -> REPLY
_rc_read_le() {
	local file=$1 off=$2 n=$3 bytes b val=0 i=0
	bytes=$(dd if="$file" bs=1 skip="$off" count="$n" 2>/dev/null | od -An -v -tu1) || return 1
	# shellcheck disable=SC2086
	set -- $bytes
	(($# == n)) || return 1
	for b in "$@"; do
		val=$((val | (b << (8 * i))))
		i=$((i + 1))
	done
	REPLY=$val
}
read_u8() { _rc_read_le "$1" "$2" 1; }
read_le16() { _rc_read_le "$1" "$2" 2; }
read_le32() { _rc_read_le "$1" "$2" 4; }
read_le64() { _rc_read_le "$1" "$2" 8; }

# read_hex FILE OFFSET COUNT   -> REPLY: lowercase hex string of COUNT bytes
read_hex() {
	local out
	out=$(dd if="$1" bs=1 skip="$2" count="$3" 2>/dev/null | od -An -v -tx1) || return 1
	REPLY=${out//[[:space:]]/}
	((${#REPLY} == $3 * 2))
}

# ---------------------------------------------------------------------------
# Resources (boot code blobs, UEFI:NTFS image, FreeDOS files)
# ---------------------------------------------------------------------------

# rc_resource RELATIVE/PATH   locate a bundled resource -> REPLY (absolute path)
# Resources are looked up first in the installed layout (share/), then in the
# Rufus source tree this repository is a fork of (res/).
rc_resource() {
	local rel=$1 cand
	for cand in "$RC_ROOT/share/$rel" "$RC_ROOT/../res/$rel"; do
		if [[ -e $cand ]]; then
			REPLY=$cand
			return 0
		fi
	done
	fail "bundled resource not found: $rel"
}

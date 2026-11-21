# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# rufus-cli - minimal test harness (pure bash, no external dependencies).
#
# A test file looks like this:
#
#     #!/usr/bin/env bash
#     . "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
#     t_load core i18n format
#
#     t_case "labels are upper-cased for FAT"
#     fmt_label_sanitize fat32 'my usb'
#     t_eq "$REPLY" 'MY USB'
#
#     t_done
#
# Assertions never abort the file: every failure is reported with the line
# that made it, and t_done turns the tally into the exit status.

set -u

T_FILE=${BASH_SOURCE[1]:-${0}}
T_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
T_ROOT=$(cd "$T_DIR/.." && pwd)		# the cli/ directory
T_REPO=$(cd "$T_ROOT/.." && pwd)	# the repository root
T_CASE='(no case)'
T_PASS=0
T_FAIL=0
T_SKIP=0
T_TMP=''
T_STUBS=''

_t_cleanup() {
	if [[ -n $T_TMP && -d $T_TMP ]]; then
		rm -rf --one-file-system -- "$T_TMP" 2>/dev/null || rm -rf -- "$T_TMP" 2>/dev/null || true
	fi
}
trap _t_cleanup EXIT

# t_tmp [NAME]   create a fresh directory under the test's temp dir -> REPLY
t_tmp() {
	if [[ -z $T_TMP ]]; then
		T_TMP=$(mktemp -d "${TMPDIR:-/tmp}/rufus-cli-test.XXXXXXXX") || {
			echo "cannot create a temp dir" >&2
			exit 99
		}
	fi
	REPLY=$(mktemp -d "$T_TMP/${1:-d}.XXXXXX")
}

# t_load MODULE...   source modules from cli/lib with the usual globals set up
t_load() {
	local m
	export RC_ROOT=$T_ROOT
	export RC_SELF=$T_ROOT/rufus-cli
	for m in "$@"; do
		# shellcheck disable=SC1090
		. "$T_ROOT/lib/$m.sh" || {
			echo "cannot load module $m" >&2
			exit 99
		}
	done
	if declare -F core_fix_path >/dev/null; then
		core_fix_path
	fi
	if declare -F log_init >/dev/null && [[ -z ${LOG_FILE:-} ]]; then
		t_tmp log
		log_init "$REPLY/test.log"
	fi
}

t_case() { T_CASE=$*; }

_t_where() {
	# Line of the assertion in the test file (skip the harness frames).
	local i
	for ((i = 1; i < ${#BASH_SOURCE[@]}; i++)); do
		if [[ ${BASH_SOURCE[i]} != "${BASH_SOURCE[0]}" ]]; then
			REPLY="${BASH_SOURCE[i]##*/}:${BASH_LINENO[i - 1]}"
			return
		fi
	done
	REPLY='?'
}

_t_pass() { T_PASS=$((T_PASS + 1)); }

_t_fail() {
	T_FAIL=$((T_FAIL + 1))
	_t_where
	printf 'not ok - %s [%s]\n' "$T_CASE" "$REPLY"
	local line
	for line in "$@"; do
		printf '    %s\n' "$line"
	done
}

# t_eq ACTUAL EXPECTED [LABEL]
t_eq() {
	if [[ $1 == "$2" ]]; then
		_t_pass
	else
		_t_fail "${3:+$3}" "expected: $(printf '%q' "$2")" "actual:   $(printf '%q' "$1")"
	fi
}

# t_ne ACTUAL UNEXPECTED [LABEL]
t_ne() {
	if [[ $1 != "$2" ]]; then
		_t_pass
	else
		_t_fail "${3:+$3}" "value should differ from: $(printf '%q' "$2")"
	fi
}

# t_match STRING REGEX [LABEL]
t_match() {
	if [[ $1 =~ $2 ]]; then
		_t_pass
	else
		_t_fail "${3:+$3}" "regex:  $2" "string: $(printf '%q' "$1")"
	fi
}

# t_contains HAYSTACK NEEDLE [LABEL]
t_contains() {
	if [[ $1 == *"$2"* ]]; then
		_t_pass
	else
		_t_fail "${3:+$3}" "missing: $(printf '%q' "$2")" "in:      $(printf '%q' "$1")"
	fi
}

# t_true CMD ARGS...    the command must succeed
t_true() {
	if "$@"; then
		_t_pass
	else
		_t_fail "command failed (status $?): $*" "ERR_MSG: ${ERR_MSG:-}"
	fi
}

# t_false CMD ARGS...   the command must fail
t_false() {
	if "$@"; then
		_t_fail "command unexpectedly succeeded: $*"
	else
		_t_pass
	fi
}

# t_file_eq FILE_A FILE_B [LABEL]
t_file_eq() {
	local _a _b
	_a=$(sha256sum <"$1" 2>/dev/null) || _a="unreadable:$1"
	_b=$(sha256sum <"$2" 2>/dev/null) || _b="unreadable:$2"
	if [[ $_a == "$_b" ]]; then
		_t_pass
	else
		_t_fail "${3:+$3}" "files differ: $1 $2"
	fi
}

# t_skip REASON   count a skipped case
t_skip() {
	T_SKIP=$((T_SKIP + 1))
	printf 'skip - %s: %s\n' "$T_CASE" "$*"
}

# t_need CMD...   true when all commands exist; otherwise records a skip
t_need() {
	local c
	for c in "$@"; do
		if ! command -v "$c" >/dev/null 2>&1; then
			t_skip "'$c' is not installed"
			return 1
		fi
	done
	return 0
}

# t_need_root   true when running as root; otherwise records a skip
t_need_root() {
	if ((EUID != 0)); then
		t_skip "needs root"
		return 1
	fi
	return 0
}

# t_stub NAME [BODY]   put a fake command first in PATH.  BODY is the shell
# code of the script (default: succeed silently).  Calls are appended to
# $T_STUBS/NAME.calls, one line per invocation.
t_stub() {
	local name=$1 body=${2:-exit 0}
	if [[ -z $T_STUBS ]]; then
		t_tmp stubs
		T_STUBS=$REPLY
		PATH="$T_STUBS:$PATH"
		export PATH T_STUBS
	fi
	{
		printf '#!/usr/bin/env bash\n'
		printf 'printf "%%s\\n" "$*" >>"%s/%s.calls"\n' "$T_STUBS" "$name"
		printf '%s\n' "$body"
	} >"$T_STUBS/$name"
	chmod +x "$T_STUBS/$name"
	hash -r
}

# t_stub_calls NAME   -> REPLY: recorded invocations of a stub (newline separated)
t_stub_calls() {
	REPLY=''
	if [[ -n $T_STUBS && -f $T_STUBS/$1.calls ]]; then
		REPLY=$(<"$T_STUBS/$1.calls")
	fi
}

# t_done   print the tally and exit accordingly
t_done() {
	printf '# %s: %d passed, %d failed, %d skipped\n' "${T_FILE##*/}" "$T_PASS" "$T_FAIL" "$T_SKIP"
	if ((T_FAIL > 0)); then
		exit 1
	fi
	exit 0
}

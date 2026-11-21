#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Unit tests for core.sh, i18n.sh and progress.sh.
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
t_load core i18n progress

# --- sizes and durations ----------------------------------------------------

t_case "human_size"
human_size 0;             t_eq "$REPLY" "0 B"
human_size 1023;          t_eq "$REPLY" "1023 B"
human_size 1024;          t_eq "$REPLY" "1.0 KiB"
human_size 1536;          t_eq "$REPLY" "1.5 KiB"
human_size 1048576;       t_eq "$REPLY" "1.0 MiB"
human_size 30943995904;   t_eq "$REPLY" "28.8 GiB"
human_size 1073689395;    t_eq "$REPLY" "1023.9 MiB"
human_size 1073689396;    t_eq "$REPLY" "1.0 GiB" "rounding carries into the next unit"
human_size 2199023255552; t_eq "$REPLY" "2.0 TiB"
human_size garbage;       t_eq "$REPLY" "0 B"

t_case "human_size_si"
human_size_si 999;         t_eq "$REPLY" "999 B"
human_size_si 1000;        t_eq "$REPLY" "1.0 kB"
human_size_si 30943995904; t_eq "$REPLY" "30.9 GB"
human_size_si 999960000;   t_eq "$REPLY" "1.0 GB"

t_case "human_duration"
human_duration 0;    t_eq "$REPLY" "0:00"
human_duration 7;    t_eq "$REPLY" "0:07"
human_duration 754;  t_eq "$REPLY" "12:34"
human_duration 3723; t_eq "$REPLY" "1:02:03"

t_case "parse_size"
parse_size 512;      t_eq "$REPLY" 512
parse_size 4k;       t_eq "$REPLY" 4096
parse_size 64K;      t_eq "$REPLY" 65536
parse_size 16KiB;    t_eq "$REPLY" 16384
parse_size "4 M";    t_eq "$REPLY" 4194304
parse_size 8G;       t_eq "$REPLY" 8589934592
parse_size 1T;       t_eq "$REPLY" 1099511627776
parse_size 0010;     t_eq "$REPLY" 10 "leading zeros are decimal"
t_false parse_size ""
t_false parse_size "abc"
t_false parse_size "12X"

t_case "string helpers"
str_trim "  a b  ";          t_eq "$REPLY" "a b"
str_trim "";                 t_eq "$REPLY" ""
str_squeeze "  a   b  c ";   t_eq "$REPLY" "a b c"
t_true in_list b a b c
t_false in_list z a b c
t_true is_uint 0
t_true is_uint 123
t_false is_uint ""
t_false is_uint 12a
t_false is_uint -1

# --- binary readers ---------------------------------------------------------

t_case "little-endian readers"
t_tmp bin
bin=$REPLY/data.bin
printf '\x01\x02\x03\x04\x05\x06\x07\x08\xff\x00' >"$bin"
read_u8 "$bin" 0;   t_eq "$REPLY" 1
read_u8 "$bin" 8;   t_eq "$REPLY" 255
read_le16 "$bin" 0; t_eq "$REPLY" 513
read_le32 "$bin" 0; t_eq "$REPLY" 67305985
read_le64 "$bin" 0; t_eq "$REPLY" 578437695752307201
read_hex "$bin" 0 4; t_eq "$REPLY" "01020304"
t_false read_le32 "$bin" 8
file_size "$bin";   t_eq "$REPLY" 10

t_case "content comparison without diffutils"
printf 'abcdefghij' >"$bin.a"
printf 'abcdefghij' >"$bin.b"
printf 'abcdefghiX' >"$bin.c"
t_true files_equal "$bin.a" "$bin.b"
t_false files_equal "$bin.a" "$bin.c"
t_true range_equal "$bin.a" 0 "$bin.c" 0 9
t_false range_equal "$bin.a" 0 "$bin.c" 0 10
t_true range_equal "$bin.a" 2 "$bin.b" 2 5
range_sha256 "$bin.a" 0 10
t_eq "$REPLY" "72399361da6a7754fec986dca5b7cbaf1c810a28ded4abaf56b2106d06cb78b0"
head -c 2097152 /dev/zero >"$bin.z"
range_sha256 "$bin.z" 1048576 1048576
t_eq "$REPLY" "30e14955ebf1352266dc2ff8067e68104607e750abb9d3b36582b8af909fcb58" "1 MiB of zeros, block-aligned path"

# --- logging and errors -----------------------------------------------------

t_case "fail records the message"
ERR_MSG=''
t_false fail "something broke"
t_eq "$ERR_MSG" "something broke"
t_true grep -q 'ERROR: something broke' "$LOG_FILE"

t_case "run logs the command and its output"
t_true run printf 'hello-from-run\n'
t_true grep -q 'hello-from-run' "$LOG_FILE"
t_false run false
out=''
run_capture out printf 'captured'
t_eq "$out" "captured"

t_case "cleanup stack runs in reverse order"
t_tmp cl
order=$REPLY/order
cleanup_push "printf 'a' >>$(printf '%q' "$order")"
cleanup_push "printf 'b' >>$(printf '%q' "$order")"
cleanup_push "printf 'c' >>$(printf '%q' "$order")"
cleanup_remove "printf 'b' >>$(printf '%q' "$order")"
core_run_cleanup
t_eq "$(cat "$order")" "ca"

t_case "temp dir is private and removable"
core_mktemp_dir work
t_true test -d "$REPLY"
tmp_parent=$RC_TMP
t_false core_path_has_mounts "$RC_TMP"
core_remove_tmp
t_false test -d "$tmp_parent"

t_case "time helpers"
now_s; t_match "$REPLY" '^[0-9]{10,}$'
now_ms; t_match "$REPLY" '^[0-9]{13,}$'
now_ms; a=$REPLY
rc_sleep 0.2
now_ms; b=$REPLY
t_true test $((b - a)) -ge 0

# --- i18n -------------------------------------------------------------------

t_case "catalogue lookup"
msg_def test.hello 'Hello %s' 'こんにちは %s'
msg_def test.only_en 'English only'
msg_def test.pct '100%% done'
i18n_set_lang en
t test.hello World;      t_eq "$REPLY" "Hello World"
t test.pct;              t_eq "$REPLY" "100% done"
t test.unknown;          t_eq "$REPLY" "test.unknown"
i18n_set_lang ja_JP.UTF-8
t_eq "$RC_LANG" ja
t test.hello World;      t_eq "$REPLY" "こんにちは World"
t test.only_en;          t_eq "$REPLY" "English only" "falls back to English"
t_en test.hello World;   t_eq "$REPLY" "Hello World"
ERR_MSG=''
t_false fail_t test.hello Bob
t_eq "$ERR_MSG" "こんにちは Bob"
t_true grep -q 'ERROR: Hello Bob' "$LOG_FILE"
i18n_set_lang C;         t_eq "$RC_LANG" en
i18n_set_lang "";        t_eq "$RC_LANG" en
# The locale variables are only read as strings here; a subshell keeps the
# test's own locale untouched (the named locale may not even be installed).
lang_for() { (
	# shellcheck disable=SC2030
	export OPT_LANG=$1 RUFUS_CLI_LANG=$2 LC_ALL=$3 LC_MESSAGES=$4 LANG=$5
	i18n_init
	printf '%s' "$RC_LANG"
) 2>/dev/null; }
t_eq "$(lang_for ja '' '' '' '')" ja "explicit option"
t_eq "$(lang_for '' ja '' '' '')" ja "RUFUS_CLI_LANG"
t_eq "$(lang_for '' '' '' '' ja_JP.UTF-8)" ja "LANG"
t_eq "$(lang_for '' '' C '' ja_JP.UTF-8)" en "LC_ALL wins over LANG"
t_eq "$(lang_for '' '' '' ja_JP.UTF-8 en_US.UTF-8)" ja "LC_MESSAGES wins over LANG"
t_eq "$(lang_for en '' '' '' ja_JP.UTF-8)" en "option wins over the environment"
i18n_set_lang en

# --- progress runners -------------------------------------------------------

JOB_TICK=0.05
job_reset

t_case "job_spin returns the command status"
t_true job_spin true
job_spin sh -c 'exit 7'
t_eq "$?" 7

t_case "job_track_stdin follows the input offset"
t_tmp stdin
src=$REPLY/src.bin
dst=$REPLY/dst.bin
head -c 3000000 /dev/zero >"$src"
ticks=0
count_ticks() { ticks=$((ticks + 1)); }
JOB_UI_HOOK=count_ticks
t_true job_track_stdin 3000000 "$src" "$dst" cat
JOB_UI_HOOK=''
t_file_eq "$src" "$dst"
t_eq "$JOB_PCT" 1000
t_eq "$JOB_DONE" 3000000
t_true test "$ticks" -ge 1

t_case "a shell function can be tracked"
slow_copy() { local i; for i in 1 2 3; do sleep 0.05; done; cat; }
t_true job_track_stdin 3000000 "$src" "$dst" slow_copy
t_file_eq "$src" "$dst"

t_case "job_note travels from a background subshell"
noisy() { job_note "from-the-background"; sleep 0.3; }
t_true job_spin noisy
t_eq "$JOB_NOTE" "from-the-background"

t_case "cancellation kills the whole process tree"
t_tmp cancel
marker=$REPLY/pids
spawn_tree() {
	sleep 300 &
	echo "$!" >>"$marker"
	sleep 300 &
	echo "$!" >>"$marker"
	wait
}
cancel_soon() { ticks=$((ticks + 1)); if ((ticks >= 4)); then RC_CANCELLED=1; fi; }
ticks=0
JOB_UI_HOOK=cancel_soon
job_spin spawn_tree
rc=$?
JOB_UI_HOOK=''
RC_CANCELLED=0
t_eq "$rc" 130
sleep 0.3
# A process that was killed but not yet reaped still answers kill -0, so look
# at its state instead: anything other than a zombie counts as alive.
is_running() {
	local stat
	{ IFS= read -r stat <"/proc/$1/stat"; } 2>/dev/null || return 1
	stat=${stat##*) }
	[[ ${stat:0:1} != Z ]]
}
alive=0
while read -r p; do
	if is_running "$p"; then alive=$((alive + 1)); fi
done <"$marker"
t_eq "$alive" 0 "no child survives"
t_eq "$(wc -l <"$marker" | tr -d ' ')" 2

t_case "a cancelled job refuses to start anything else"
RC_CANCELLED=1
job_spin true
t_eq "$?" 130
RC_CANCELLED=0

t_case "step weights feed the overall figure"
job_step 200 500
t_eq "$JOB_OVERALL" 200
t_true job_track_stdin 3000000 "$src" "$dst" cat
t_eq "$JOB_OVERALL" 700

core_remove_tmp
t_done

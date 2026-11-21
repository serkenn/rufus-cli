#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Unit tests for ui.sh: text metrics, key decoding, bars and frame diffing.
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
t_load core i18n ui

# Not as a prefix assignment: those are undone when the function returns, and
# the locale chosen by ui_setup_locale has to stick.
export LANG=C.UTF-8
unset LC_ALL LC_CTYPE
ui_setup_locale
if ! _ui_bash_utf8; then
	t_case "UTF-8 locale"
	t_skip "no working UTF-8 locale in this environment"
	t_done
fi
RUFUS_CLI_COLOR=never
ui_init

t_case "locale setup yields a UTF-8 shell"
t_eq "$UI_UTF8" 1
s='日本語'
t_eq "${#s}" 3 "string length counts characters"

t_case "ui_width"
ui_width '';                 t_eq "$REPLY" 0
ui_width 'abc';              t_eq "$REPLY" 3
ui_width 'a b~';             t_eq "$REPLY" 4
ui_width '日本語';           t_eq "$REPLY" 6
ui_width 'USBドライブ';      t_eq "$REPLY" 11
ui_width 'ｶﾀｶﾅ';             t_eq "$REPLY" 4 "half-width katakana are narrow"
ui_width 'ＡＢ';             t_eq "$REPLY" 4 "full-width latin is wide"
ui_width 'é';                t_eq "$REPLY" 1
ui_width $'é';         t_eq "$REPLY" 1 "combining accent takes no cell"
ui_width '─│█░';             t_eq "$REPLY" 4 "box drawing is narrow"
ui_width '한국어';           t_eq "$REPLY" 6
ui_width '[*?]\';            t_eq "$REPLY" 5 "pattern characters are plain text"

t_case "ui_trunc"
ui_trunc 'hello' 10;         t_eq "$REPLY" 'hello'
ui_trunc 'hello world' 8;    ui_width "$REPLY"; t_eq "$REPLY" 8
ui_trunc 'hello world' 8;    t_eq "$REPLY" 'hello w…'
ui_trunc '日本語のテキスト' 7; t_eq "$REPLY" '日本語…' "never splits a wide character"
ui_trunc '日本語のテキスト' 7; ui_width "$REPLY"; t_true test "$REPLY" -le 7
ui_trunc 'abc' 0;            t_eq "$REPLY" ''
ui_trunc 'abcdef' 1;         t_eq "$REPLY" 'a'

t_case "ui_trunc_mid keeps both ends"
ui_trunc_mid '/home/user/Downloads/ubuntu-24.04.1-desktop-amd64.iso' 30
ui_width "$REPLY";           t_true test "$REPLY" -le 30
ui_trunc_mid '/home/user/Downloads/ubuntu-24.04.1-desktop-amd64.iso' 30
t_match "$REPLY" '^/home.*amd64\.iso$'
ui_trunc_mid 'short' 30;     t_eq "$REPLY" 'short'

t_case "ui_pad"
ui_pad 'ab' 5;               t_eq "$REPLY" 'ab   '
ui_pad 'ab' 5 right;         t_eq "$REPLY" '   ab'
ui_pad 'ab' 6 center;        t_eq "$REPLY" '  ab  '
ui_pad '日本' 6;             t_eq "$REPLY" '日本  '
ui_pad 'abcdefgh' 5;         t_eq "$REPLY" 'abcd…'
ui_pad 'x' 0;                t_eq "$REPLY" ''

t_case "ui_repeat"
ui_repeat '-' 5;             t_eq "$REPLY" '-----'
ui_repeat '─' 3;             t_eq "$REPLY" '───'
ui_repeat 'ab' 2;            t_eq "$REPLY" 'abab'
ui_repeat 'x' 0;             t_eq "$REPLY" ''

t_case "ui_wrap (latin)"
ui_wrap 'the quick brown fox jumps over the lazy dog' 16
t_eq "${#UI_WRAPPED[@]}" 3
t_eq "${UI_WRAPPED[0]}" 'the quick brown'
t_eq "${UI_WRAPPED[1]}" 'fox jumps over'
t_eq "${UI_WRAPPED[2]}" 'the lazy dog'
ui_wrap $'first\n\nsecond' 20
t_eq "${#UI_WRAPPED[@]}" 3
t_eq "${UI_WRAPPED[1]}" ''
ui_wrap 'supercalifragilistic' 8
t_eq "${UI_WRAPPED[0]}" 'supercal'
t_eq "${UI_WRAPPED[2]}" 'stic'

t_case "ui_wrap (japanese)"
ui_wrap 'デバイス上のすべてのデータは消去されます。' 16
for line in "${UI_WRAPPED[@]}"; do
	ui_width "$line"
	t_true test "$REPLY" -le 16
done
joined=''
for line in "${UI_WRAPPED[@]}"; do joined+=$line; done
t_eq "$joined" 'デバイス上のすべてのデータは消去されます。' "no character is lost"
ui_wrap 'あいうえおかきく。' 16
t_eq "${#UI_WRAPPED[@]}" 2
t_eq "${UI_WRAPPED[1]}" 'く。' "closing punctuation does not start a line"
ui_wrap 'Windows のインストール' 12
t_eq "${UI_WRAPPED[0]}" 'Windows のイ'

t_case "progress bar has the requested width"
strip_sgr() { REPLY=$(printf '%s' "$1" | sed -E $'s/\e\\[[0-9;]*m//g'); }
for pm in 0 1 250 500 999 1000 -1; do
	ui_progress_bar "$pm" 40
	strip_sgr "$REPLY"
	ui_width "$REPLY"
	t_eq "$REPLY" 40 "permille $pm"
done
ui_progress_bar 500 20
strip_sgr "$REPLY"
t_eq "${REPLY:0:10}" '██████████'

t_case "ascii fallback"
RUFUS_CLI_ASCII=1 ui_init
t_eq "$UI_GLYPHS" ascii
ui_progress_bar 500 10
t_eq "$REPLY" '#####.....'
ui_trunc 'hello world' 8;    t_eq "$REPLY" 'hello...'
RUFUS_CLI_ASCII='' ui_init
t_eq "$UI_GLYPHS" rich

t_case "colour tiers"
RUFUS_CLI_COLOR=never ui_init;     t_eq "$UI_COLORS" 0; t_eq "$C_ACCENT" ''
RUFUS_CLI_COLOR=256 ui_init;       t_eq "$UI_COLORS" 256; t_eq "$C_ACCENT" $'\e[38;5;77m'
RUFUS_CLI_COLOR=truecolor ui_init; t_eq "$C_ACCENT" $'\e[38;2;86;211;100m'
RUFUS_CLI_COLOR=16 ui_init;        t_eq "$C_ACCENT" $'\e[92m'
NO_COLOR=1 RUFUS_CLI_COLOR=auto ui_init; t_eq "$UI_COLORS" 0
RUFUS_CLI_COLOR=never ui_init

t_case "key decoding"
t_tmp keys
keyfile=$REPLY/keys
decode() {
	# decode BYTES -> REPLY: space separated key names
	local out=''
	printf '%b' "$1" >"$keyfile"
	exec {kfd}<"$keyfile"
	UI_IN_FD=$kfd
	while ui_read_key 0.2; do out+="${out:+ }$REPLY"; done
	exec {kfd}<&-
	REPLY=$out
}
decode 'a';                              t_eq "$REPLY" 'a'
decode '\r';                             t_eq "$REPLY" 'enter'
decode '\n';                             t_eq "$REPLY" 'enter'
decode '\t ';                            t_eq "$REPLY" 'tab space'
decode '\x7f';                           t_eq "$REPLY" 'backspace'
decode '\e[A\e[B\e[C\e[D';               t_eq "$REPLY" 'up down right left'
decode '\eOA\eOB';                       t_eq "$REPLY" 'up down' "application cursor keys"
decode '\e[H\e[F\e[1~\e[4~';             t_eq "$REPLY" 'home end home end'
decode '\e[5~\e[6~\e[3~\e[2~';           t_eq "$REPLY" 'pgup pgdn delete insert'
decode '\e[1;5C\e[1;2A';                 t_eq "$REPLY" 'right up' "modifiers are ignored"
decode '\e[Z';                           t_eq "$REPLY" 'backtab'
decode '\eOP\e[15~\e[24~';               t_eq "$REPLY" 'f1 f5 f12'
decode '\e';                             t_eq "$REPLY" 'esc' "a lone escape"
decode '\ex';                            t_eq "$REPLY" 'alt-x'
decode '\x03\x0c\x15';                   t_eq "$REPLY" 'ctrl-c ctrl-l ctrl-u'
decode 'あ';                             t_eq "$REPLY" 'あ' "multi-byte characters arrive whole"
decode 'q\e[Bz';                         t_eq "$REPLY" 'q down z'
decode '\e[99x';                         t_eq "$REPLY" 'unknown'
decode '';                               t_eq "$REPLY" ''

t_case "frames only repaint what changed"
t_tmp frame
out=$REPLY/out
# Append mode, so that truncating the file between checks also rewinds it.
: >"$out"
exec {ofd}>>"$out"
UI_FD=$ofd
UI_ROWS=10
UI_COLS=40
ui_frame_invalidate
ui_frame_begin
ui_frame_add 'line one'
ui_frame_add 'line two'
ui_frame_add 'line three'
ui_frame_flush
first=$(<"$out")
t_contains "$first" 'line one'
t_contains "$first" 'line three'
: >"$out"
ui_frame_begin
ui_frame_add 'line one'
ui_frame_add 'line 2'
ui_frame_add 'line three'
ui_frame_flush
second=$(<"$out")
t_contains "$second" 'line 2'
t_false test "${second/line one/}" != "$second"
t_false test "${second/line three/}" != "$second"
: >"$out"
ui_frame_flush
t_eq "$(<"$out")" '' "an identical frame sends nothing"
ui_frame_begin
ui_frame_add 'only line'
ui_frame_flush
third=$(<"$out")
t_contains "$third" $'\e[2;1H' "shrinking clears the rows below"
t_contains "$third" $'\e[J'
exec {ofd}>&-

t_done

#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Unit tests for widgets.sh: every widget is driven with scripted key strokes.
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
t_load core i18n ui widgets

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
UI_ROWS=24
UI_COLS=80

t_tmp io
io=$REPLY
screen=$io/screen
: >"$screen"
exec {scr_fd}>>"$screen"
UI_FD=$scr_fd

# keys BYTES   make the widgets read BYTES (printf %b escapes) as their input.
key_fd=''
keys() {
	[[ -n $key_fd ]] && exec {key_fd}<&-
	printf '%b' "$1" >"$io/keys"
	exec {key_fd}<"$io/keys"
	UI_IN_FD=$key_fd
	: >"$screen"
}
screen_text() { REPLY=$(sed -E $'s/\e\\[[0-9;?]*[A-Za-z]//g' "$screen"); }

# --- menu -------------------------------------------------------------------

menu3() {
	ui_menu_reset
	ui_menu_add 'Alpha' 'first'
	ui_menu_add 'Beta'
	ui_menu_add 'Gamma' '' 'not available'
	ui_menu_add 'Delta'
}

t_case "menu: arrows and enter"
menu3
keys '\e[B\r'
t_true ui_menu 'Pick one' 0
t_eq "$REPLY" 1
screen_text
t_contains "$REPLY" 'Pick one'
t_contains "$REPLY" 'Alpha'
t_contains "$REPLY" 'not available'

t_case "menu: default selection, home/end"
menu3
keys '\r'
t_true ui_menu 'Pick one' 1
t_eq "$REPLY" 1
menu3
keys '\e[F\r'
t_true ui_menu 'Pick one' 0
t_eq "$REPLY" 3
menu3
keys '\e[F\e[H\r'
t_true ui_menu 'Pick one' 2
t_eq "$REPLY" 0

t_case "menu: a disabled entry cannot be chosen"
menu3
keys '\e[B\e[B\r\e[B\r'
t_true ui_menu 'Pick one' 0
t_eq "$REPLY" 3

t_case "menu: escape and end of input cancel"
menu3
keys '\e'
t_false ui_menu 'Pick one' 0
menu3
keys ''
t_false ui_menu 'Pick one' 0

t_case "menu: long lists scroll"
ui_menu_reset
for i in $(seq 1 60); do ui_menu_add "Entry $i"; done
keys '\e[6~\e[6~\e[B\r'
t_true ui_menu 'Many' 0
t_true test "$REPLY" -gt 20
ui_menu_reset
for i in $(seq 1 60); do ui_menu_add "Entry $i"; done
keys '\e[F\r'
t_true ui_menu 'Many' 0
t_eq "$REPLY" 59

# --- text input -------------------------------------------------------------

t_case "input: typing and editing"
keys 'abc\r'
t_true ui_input 'Title' 'Prompt' ''
t_eq "$REPLY" 'abc'
keys '\x7f\x7fp!\r'
t_true ui_input 'Title' 'Prompt' 'hello'
t_eq "$REPLY" 'help!'
keys '\e[Ha\e[Fd\r'
t_true ui_input 'Title' '' 'bc'
t_eq "$REPLY" 'abcd'
keys '\e[D\e[D\e[3~\r'
t_true ui_input 'Title' '' 'abcd'
t_eq "$REPLY" 'abd'
keys '\x15new\r'
t_true ui_input 'Title' '' 'old text'
t_eq "$REPLY" 'new'
keys 'a b\r'
t_true ui_input 'Title' '' ''
t_eq "$REPLY" 'a b'

t_case "input: multi-byte text"
keys 'ラベル\x7f\r'
t_true ui_input 'Title' '' ''
t_eq "$REPLY" 'ラベ'

t_case "input: length limit, cancel"
keys 'abcdefgh\r'
t_true ui_input 'Title' '' '' 5
t_eq "$REPLY" 'abcde'
keys 'abc\e'
t_false ui_input 'Title' '' ''

t_case "input: very long text scrolls instead of overflowing"
long=$(printf 'x%.0s' $(seq 1 200))
keys '\r'
t_true ui_input 'Title' '' "$long"
t_eq "${#REPLY}" 200

t_case "input: path completion"
t_tmp paths
pdir=$REPLY
: >"$pdir/alpha.iso"
mkdir "$pdir/alps"
: >"$pdir/beta.img"
UI_INPUT_COMPLETE=path
keys '\t\r'
t_true ui_input 'Path' '' "$pdir/al"
t_eq "$REPLY" "$pdir/alp" "common prefix"
keys '\th\t\r'
t_true ui_input 'Path' '' "$pdir/al"
t_eq "$REPLY" "$pdir/alpha.iso"
keys '\t\r'
t_true ui_input 'Path' '' "$pdir/alps"
t_eq "$REPLY" "$pdir/alps/" "a directory gets a trailing slash"
keys '\t\r'
t_true ui_input 'Path' '' "$pdir/zzz"
t_eq "$REPLY" "$pdir/zzz" "no match leaves the text alone"
UI_INPUT_COMPLETE=''

# --- dialogs ----------------------------------------------------------------

t_case "confirm: the negative button has the focus"
keys '\r'
t_false ui_confirm 'Warning' 'All data will be destroyed.'
keys '\e[C\r'
t_true ui_confirm 'Warning' 'All data will be destroyed.'
keys '\t\r'
t_true ui_confirm 'Warning' 'All data will be destroyed.'
keys '\t\t\r'
t_false ui_confirm 'Warning' 'All data will be destroyed.'
keys '\e'
t_false ui_confirm 'Warning' 'All data will be destroyed.'
keys '\e[C\r'
ui_confirm 'Warning' $'A long body that needs wrapping because it goes on and on and on well past the width of the box.\n\nSecond paragraph.' 'Erase' 'Keep' danger
screen_text
t_contains "$REPLY" 'Erase'
t_contains "$REPLY" 'Keep'
t_contains "$REPLY" 'Second paragraph.'

t_case "message box"
keys '\r'
t_true ui_message 'Info' 'Something happened.'
screen_text
t_contains "$REPLY" 'Something happened.'

# --- check list -------------------------------------------------------------

t_case "check list: toggling and confirming"
ui_check_reset
ui_check_add 'First option' 1 'Tip one'
ui_check_add 'Second option' 0 'Tip two'
ui_check_add 'Account name:' 0 'Tip three' 'taro'
keys ' \e[B \r'
t_true ui_checklist 'Options' 'Choose'
t_eq "${UI_CHECK_STATE[*]}" '0 1 0'
screen_text
t_contains "$REPLY" 'Account name: taro'

t_case "check list: editing a value, cancelling"
ui_check_reset
ui_check_add 'First option' 1
ui_check_add 'Account name:' 0 '' 'taro'
keys '\e[Be\x15hanako\r\r'
t_true ui_checklist 'Options' ''
t_eq "${UI_CHECK_VALUE[1]}" 'hanako'
t_eq "${UI_CHECK_STATE[1]}" 1 "giving a value ticks the box"
ui_check_reset
ui_check_add 'First option' 1
ui_check_add 'Second option' 0
keys ' \e[B \e'
t_false ui_checklist 'Options' ''
t_eq "${UI_CHECK_STATE[*]}" '1 0' "cancel restores the states"

# --- file browser -----------------------------------------------------------

if t_need find; then
	t_tmp tree
	tree=$REPLY
	mkdir -p "$tree/sub dir" "$tree/.hidden"
	: >"$tree/a.iso"
	: >"$tree/b.IMG"
	: >"$tree/notes.txt"
	: >"$tree/.secret.iso"
	: >"$tree/sub dir/inner.iso"
	: >"$tree/日本語.iso"

	t_case "file browser: listing and filtering"
	keys '\e'
	t_false ui_filepicker 'Open' "$tree"
	screen_text
	shown=$REPLY
	t_contains "$shown" 'a.iso'
	t_contains "$shown" 'b.IMG'
	t_contains "$shown" 'sub dir/'
	t_contains "$shown" '日本語.iso'
	t_false test "${shown/notes.txt/}" != "$shown"
	t_false test "${shown/.secret.iso/}" != "$shown"

	t_case "file browser: directories first, then choosing a file"
	keys '\e[B\r'
	t_true ui_filepicker 'Open' "$tree"
	t_eq "$REPLY" "$tree/a.iso"

	t_case "file browser: entering a directory and going back"
	keys '\r\r'
	t_true ui_filepicker 'Open' "$tree"
	t_eq "$REPLY" "$tree/sub dir/inner.iso"
	keys '\r\e[D\e[B\r'
	t_true ui_filepicker 'Open' "$tree"
	t_eq "$REPLY" "$tree/a.iso" "back in the parent, selection on the folder we left"

	t_case "file browser: show all and hidden files"
	keys 'a\e'
	ui_filepicker 'Open' "$tree"
	screen_text
	t_contains "$REPLY" 'notes.txt'
	keys '.\e'
	ui_filepicker 'Open' "$tree"
	screen_text
	t_contains "$REPLY" '.secret.iso'

	t_case "file browser: starting from a file path, typing a path"
	keys '\e'
	ui_filepicker 'Open' "$tree/sub dir/inner.iso"
	screen_text
	t_contains "$REPLY" 'inner.iso'
	keys "/\\x15$tree/b.IMG\\r"
	t_true ui_filepicker 'Open' "$tree"
	t_eq "$REPLY" "$tree/b.IMG"

	t_case "directory reader"
	t_true _w_read_dir "$tree" 0 0
	t_eq "${_W_ENT_NAME[0]}" 'sub dir'
	t_eq "${_W_ENT_TYPE[0]}" 'd'
	t_eq "${#_W_ENT_NAME[@]}" 4
	t_true _w_read_dir "$tree" 1 1
	t_eq "${#_W_ENT_NAME[@]}" 7
	t_false _w_read_dir "$tree/does-not-exist" 0 0
fi

# --- text viewer ------------------------------------------------------------

t_case "text viewer"
for i in $(seq 1 100); do printf '12:00:00 line %d\n' "$i"; done >"$io/log.txt"
printf '12:00:01 ERROR: something broke\n' >>"$io/log.txt"
keys 'q'
t_true ui_textview 'Log' "$io/log.txt"
screen_text
t_contains "$REPLY" 'ERROR: something broke'
t_false test "${REPLY/line 1$'\n'/}" != "$REPLY"
keys '\e[Hq'
t_true ui_textview 'Log' "$io/log.txt"
screen_text
t_contains "$REPLY" 'line 1 '
keys 'q'
t_true ui_textview 'Log' "$io/missing.txt"

t_done

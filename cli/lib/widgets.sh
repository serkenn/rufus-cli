# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# rufus-cli - modal widgets for the full-screen interface: drop-down menu,
# text input, confirmation / message boxes, check list, file browser and a
# scrolling text viewer.  They are drawn on top of whatever frame is on screen;
# the caller repaints its own screen afterwards (ui_frame_invalidate is called
# for it) and may provide UI_BASE_REDRAW, a function that repaints the screen
# underneath when the terminal is resized while a widget is open.

[[ -n ${_RC_WIDGETS_LOADED:-} ]] && return 0
_RC_WIDGETS_LOADED=1

msg_def ui.ok 'OK' 'OK'
msg_def ui.cancel 'Cancel' 'キャンセル'
msg_def ui.close 'Close' '閉じる'
msg_def ui.yes 'Yes' 'はい'
msg_def ui.no 'No' 'いいえ'
msg_def ui.h.move 'move' '移動'
msg_def ui.h.select 'select' '選択'
msg_def ui.h.toggle 'toggle' '切替'
msg_def ui.h.edit 'edit' '編集'
msg_def ui.h.confirm 'confirm' '決定'
msg_def ui.h.cancel 'cancel' 'キャンセル'
msg_def ui.h.close 'close' '閉じる'
msg_def ui.h.open 'open' '開く'
msg_def ui.h.parent 'parent folder' '上のフォルダー'
msg_def ui.h.typepath 'type a path' 'パスを入力'
msg_def ui.h.hidden 'hidden files' '隠しファイル'
msg_def ui.h.allfiles 'all files' 'すべてのファイル'
msg_def ui.h.home 'home' 'ホーム'
msg_def ui.h.complete 'complete' '補完'
msg_def ui.h.scroll 'scroll' 'スクロール'
msg_def ui.pick.empty '(no matching files here)' '(該当するファイルがありません)'
msg_def ui.pick.unreadable '(cannot read this folder)' '(このフォルダーを読み取れません)'
msg_def ui.pick.path 'Path' 'パス'
msg_def ui.pick.nofile 'No such file: %s' 'ファイルが見つかりません: %s'
msg_def ui.more_above '%d more above' '上にあと %d 件'
msg_def ui.more_below '%d more below' '下にあと %d 件'

UI_BASE_REDRAW=''	# optional function repainting the screen under a widget
W_INNER=0		# inner width of the window being drawn
W_ROW=1			# top-left corner of the last window (1-based)
W_COL=1
declare -a W_LINES=()

# --- helpers ----------------------------------------------------------------

# _w_hint KEY LABEL [KEY LABEL...]   -> REPLY: a styled key legend
_w_hint() {
	local out='' key label
	while (($# >= 2)); do
		key=$1
		label=$2
		shift 2
		[[ -n $out ]] && out+="  "
		out+="${C_FOCUS}${key}${S_RESET}${C_MUTED} ${label}${S_RESET}"
	done
	REPLY=$out
}

# _w_hint_plain: the same legend without escapes (to measure it).
_w_hint_plain() {
	local out='' key label
	while (($# >= 2)); do
		key=$1
		label=$2
		shift 2
		[[ -n $out ]] && out+="  "
		out+="$key $label"
	done
	REPLY=$out
}

_w_keys() {
	if [[ $UI_GLYPHS == rich ]]; then
		K_UPDOWN='↑↓' K_LEFTRIGHT='←→' K_LEFT='←' K_RIGHT='→'
	else
		K_UPDOWN='Up/Dn' K_LEFTRIGHT='Left/Right' K_LEFT='Left' K_RIGHT='Right'
	fi
}

# _w_line TEXT [STYLE]   append a content line: TEXT (plain) padded to the
# inner width, optionally wrapped in STYLE.
_w_line() {
	ui_pad "$1" "$W_INNER"
	W_LINES+=("${2:-}${REPLY}${S_RESET}")
}

# _w_styled STYLED_TEXT PLAIN_TEXT   append a line whose styled form is given;
# PLAIN_TEXT (same characters, no escapes) is used to compute the padding.
_w_styled() {
	local pad
	ui_width "$2"
	pad=$((W_INNER - REPLY))
	((pad < 0)) && pad=0
	printf -v REPLY '%*s' "$pad" ''
	W_LINES+=("$1$REPLY")
}

# _w_window TITLE FOOTER_STYLED FOOTER_PLAIN [BORDER_STYLE] [ROW]
# Draw W_LINES[] in a bordered window, centred horizontally; vertically
# centred unless ROW is given.  Sets W_ROW / W_COL.
_w_window() {
	local title=$1 fstyled=$2 fplain=$3 bstyle=${4:-$C_SUBTLE} row=${5:-}
	local inner=$W_INNER n=${#W_LINES[@]} total_w total_h out i tw fw fill
	total_w=$((inner + 4))
	total_h=$((n + 2))
	W_COL=$(((UI_COLS - total_w) / 2 + 1))
	((W_COL < 1)) && W_COL=1
	if [[ -n $row ]]; then
		W_ROW=$row
	else
		W_ROW=$(((UI_ROWS - total_h) / 2 + 1))
	fi
	((W_ROW + total_h - 1 > UI_ROWS)) && W_ROW=$((UI_ROWS - total_h + 1))
	((W_ROW < 1)) && W_ROW=1

	# Top border with the title.
	if [[ -n $title ]]; then
		ui_trunc "$title" $((inner - 2 > 1 ? inner - 2 : 1))
		title=$REPLY
		ui_width "$title"
		tw=$REPLY
		fill=$((inner - 1 - tw))
		((fill < 0)) && fill=0
		ui_repeat "$G_H" "$fill"
		out=$'\e['"${W_ROW};${W_COL}H${bstyle}${G_TL}${G_H}${S_RESET} ${S_BOLD}${C_BRIGHT}${title}${S_RESET} ${bstyle}${REPLY}${G_TR}${S_RESET}"
	else
		ui_repeat "$G_H" $((inner + 2))
		out=$'\e['"${W_ROW};${W_COL}H${bstyle}${G_TL}${REPLY}${G_TR}${S_RESET}"
	fi
	for ((i = 0; i < n; i++)); do
		out+=$'\e['"$((W_ROW + 1 + i));${W_COL}H${bstyle}${G_V}${S_RESET} ${W_LINES[i]}${S_RESET} ${bstyle}${G_V}${S_RESET}"
	done
	# Bottom border, with the key legend when it fits.
	ui_width "$fplain"
	fw=$REPLY
	if [[ -n $fplain ]] && ((fw <= inner - 2)); then
		fill=$((inner - 1 - fw))
		ui_repeat "$G_H" "$fill"
		out+=$'\e['"$((W_ROW + n + 1));${W_COL}H${bstyle}${G_BL}${G_H}${S_RESET} ${fstyled}${S_RESET} ${bstyle}${REPLY}${G_BR}${S_RESET}"
	else
		ui_repeat "$G_H" $((inner + 2))
		out+=$'\e['"$((W_ROW + n + 1));${W_COL}H${bstyle}${G_BL}${REPLY}${G_BR}${S_RESET}"
	fi
	printf '%s' $'\e[?2026h'"$out"$'\e[?2026l' >&"$UI_FD"
}

# Repaint what is underneath after a resize, then let the widget redraw.
_w_handle_resize() {
	ui_check_resize || return 1
	if [[ -n $UI_BASE_REDRAW ]]; then
		"$UI_BASE_REDRAW"
	fi
	return 0
}

# _w_key   wait up to a second for a key -> REPLY.  Returns 1 when nothing was
# typed (a pending resize has then been handled, so the caller just redraws).
# If the input has gone away the widget is cancelled rather than left spinning.
_w_key() {
	local rc=0
	ui_read_key 1 || rc=$?
	if ((rc == 0)); then
		return 0
	fi
	if ((rc == 2)); then
		REPLY='esc'
		return 0
	fi
	_w_handle_resize || true
	return 1
}

# Erase the window area by asking the base screen to repaint.
_w_close() {
	ui_cursor_hide
	ui_frame_invalidate
	if [[ -n $UI_BASE_REDRAW ]]; then
		"$UI_BASE_REDRAW"
	fi
	return 0
}

# --- menu -------------------------------------------------------------------

declare -a UI_MENU_LABEL=() UI_MENU_HINT=() UI_MENU_DISABLED=()

# ui_menu_reset / ui_menu_add LABEL [HINT] [DISABLED-REASON]
ui_menu_reset() {
	UI_MENU_LABEL=()
	UI_MENU_HINT=()
	UI_MENU_DISABLED=()
}
ui_menu_add() {
	UI_MENU_LABEL+=("$1")
	UI_MENU_HINT+=("${2:-}")
	UI_MENU_DISABLED+=("${3:-}")
}

# ui_menu TITLE [DEFAULT_INDEX] [ANCHOR_ROW]   choose one entry of UI_MENU_*.
# -> REPLY: index of the chosen entry.  Returns 1 when cancelled.
ui_menu() {
	local title=$1 sel=${2:-0} anchor=${3:-}
	local n=${#UI_MENU_LABEL[@]} i w lw hw maxl=0 maxh=0 visible top=0 key
	local fstyled fplain label hint line plain mark
	((n == 0)) && return 1
	((sel < 0 || sel >= n)) && sel=0
	_w_keys
	while :; do
		for ((i = 0; i < n; i++)); do
			ui_width "${UI_MENU_LABEL[i]}"
			((REPLY > maxl)) && maxl=$REPLY
			hint=${UI_MENU_HINT[i]}
			[[ -n ${UI_MENU_DISABLED[i]} ]] && hint=${UI_MENU_DISABLED[i]}
			ui_width "$hint"
			((REPLY > maxh)) && maxh=$REPLY
		done
		ui_width "$title"
		w=$((maxl + (maxh > 0 ? maxh + 3 : 0) + 3))
		((w < REPLY + 2)) && w=$((REPLY + 2))
		((w < 28)) && w=28
		((w > UI_COLS - 6)) && w=$((UI_COLS - 6))
		W_INNER=$w
		visible=$((UI_ROWS - 4))
		((visible > n)) && visible=$n
		((visible < 1)) && visible=1
		# Keep the selection inside the scrolling window.
		((sel < top)) && top=$sel
		((sel >= top + visible)) && top=$((sel - visible + 1))
		((top > n - visible)) && top=$((n - visible))
		((top < 0)) && top=0

		W_LINES=()
		for ((i = top; i < top + visible; i++)); do
			label=${UI_MENU_LABEL[i]}
			hint=${UI_MENU_HINT[i]}
			[[ -n ${UI_MENU_DISABLED[i]} ]] && hint=${UI_MENU_DISABLED[i]}
			ui_width "$hint"
			hw=$REPLY
			lw=$((w - 3 - (hw > 0 ? hw + 2 : 0)))
			((lw < 4)) && lw=4
			ui_pad "$label" "$lw"
			label=$REPLY
			if ((hw > 0)); then
				ui_pad "$hint" $((w - 3 - lw - 1)) right
				hint=" $REPLY"
			else
				ui_pad '' $((w - 3 - lw))
				hint=$REPLY
			fi
			mark='  '
			((i == sel)) && mark="$G_POINTER "
			plain="$mark$label$hint "
			if ((i == sel)); then
				line="${C_SEL}${C_FOCUS}${mark}${S_RESET}${C_SEL}${S_BOLD}${label}${S_RESET}${C_SEL}${C_MUTED}${hint} ${S_RESET}"
				if [[ -n ${UI_MENU_DISABLED[i]} ]]; then
					line="${C_SEL}${C_MUTED}${mark}${label}${hint} ${S_RESET}"
				fi
			elif [[ -n ${UI_MENU_DISABLED[i]} ]]; then
				line="${C_SUBTLE}${mark}${label}${hint} ${S_RESET}"
			else
				line="${mark}${label}${C_MUTED}${hint} ${S_RESET}"
			fi
			_w_styled "$line" "$plain"
		done
		t ui.h.select; local h1=$REPLY
		t ui.h.confirm; local h2=$REPLY
		t ui.h.cancel; local h3=$REPLY
		_w_hint "$K_UPDOWN" "$h1" Enter "$h2" Esc "$h3"
		fstyled=$REPLY
		_w_hint_plain "$K_UPDOWN" "$h1" Enter "$h2" Esc "$h3"
		fplain=$REPLY
		if ((n > visible)); then
			# Not everything fits: say how much is hidden.
			fplain="$((sel + 1))/$n"
			fstyled="${C_MUTED}${fplain}${S_RESET}"
		fi
		_w_window "$title" "$fstyled" "$fplain" "$C_FOCUS" "$anchor"

		_w_key || continue
		key=$REPLY
		case $key in
			up | k | ctrl-p) ((sel > 0)) && sel=$((sel - 1)) ;;
			down | j | ctrl-n) ((sel < n - 1)) && sel=$((sel + 1)) ;;
			home | g) sel=0 ;;
			end | G) sel=$((n - 1)) ;;
			pgup) sel=$((sel - visible)); ((sel < 0)) && sel=0 ;;
			pgdn) sel=$((sel + visible)); ((sel > n - 1)) && sel=$((n - 1)) ;;
			enter | space)
				if [[ -z ${UI_MENU_DISABLED[sel]} ]]; then
					_w_close
					REPLY=$sel
					return 0
				fi
				;;
			esc | q | ctrl-c)
				_w_close
				return 1
				;;
		esac
	done
}

# --- message / confirmation boxes -------------------------------------------

# _w_dialog TITLE BODY STYLE BUTTONS DEFAULT   BUTTONS: newline separated labels.
# -> REPLY: index of the chosen button; returns 1 on Esc.
_w_dialog() {
	local title=$1 body=$2 style=$3 buttons=$4 focus=${5:-0}
	local -a btn=() body_lines=()
	local w i key row rowplain b bw nb
	mapfile -t btn <<<"$buttons"
	nb=${#btn[@]}
	_w_keys
	while :; do
		w=$((UI_COLS - 12))
		((w > 68)) && w=68
		((w < 24)) && w=24
		W_INNER=$w
		ui_wrap "$body" "$w"
		body_lines=("${UI_WRAPPED[@]}")
		W_LINES=()
		_w_line ''
		for ((i = 0; i < ${#body_lines[@]}; i++)); do
			_w_line "${body_lines[i]}"
		done
		_w_line ''
		# Button row, right aligned.
		row=''
		rowplain=''
		for ((i = 0; i < nb; i++)); do
			b="  ${btn[i]}  "
			if ((i == focus)); then
				row+=" ${C_SEL}${S_BOLD}${b}${S_RESET}"
			else
				row+=" ${C_MUTED}${b}${S_RESET}"
			fi
			rowplain+=" $b"
		done
		ui_width "$rowplain"
		bw=$REPLY
		printf -v REPLY '%*s' $((w - bw > 0 ? w - bw : 0)) ''
		W_LINES+=("${REPLY}${row}")
		_w_window "$title" '' '' "$style"

		_w_key || continue
		key=$REPLY
		case $key in
			left | backtab | h) focus=$(((focus - 1 + nb) % nb)) ;;
			right | tab | l) focus=$(((focus + 1) % nb)) ;;
			enter | space)
				_w_close
				REPLY=$focus
				return 0
				;;
			esc | ctrl-c)
				_w_close
				return 1
				;;
		esac
	done
}

# ui_message TITLE BODY [warn|error|info]   a box with a single OK button.
ui_message() {
	local style=$C_FOCUS
	case ${3:-info} in
		warn) style=$C_WARN ;;
		error) style=$C_ERR ;;
	esac
	t ui.ok
	_w_dialog "$1" "$2" "$style" "$REPLY" 0 || true
	return 0
}

# ui_confirm TITLE BODY [OK_LABEL] [CANCEL_LABEL] [danger]
# Returns 0 when confirmed.  The negative button has the focus initially,
# like Rufus' own warnings.
ui_confirm() {
	local title=$1 body=$2 ok=${3:-} cancel=${4:-} danger=${5:-} style=$C_FOCUS
	if [[ -z $ok ]]; then t ui.ok; ok=$REPLY; fi
	if [[ -z $cancel ]]; then t ui.cancel; cancel=$REPLY; fi
	[[ -n $danger ]] && style=$C_WARN
	if _w_dialog "$title" "$body" "$style" "$cancel"$'\n'"$ok" 0; then
		[[ $REPLY == 1 ]]
		return
	fi
	return 1
}

# --- text input -------------------------------------------------------------

UI_INPUT_HINT=''	# optional line shown under the field
UI_INPUT_COMPLETE=''	# "path" enables Tab completion of file names
UI_INPUT_HOME=''	# what a leading "~" expands to

# _w_expand_tilde PATH   -> REPLY
_w_expand_tilde() {
	local p=$1 home=${UI_INPUT_HOME:-${HOME:-/}}
	# shellcheck disable=SC2088  # a literal tilde typed by the user
	if [[ $p == '~' ]]; then
		p=$home
	elif [[ $p == '~/'* ]]; then
		p=$home/${p#'~/'}
	fi
	REPLY=$p
}

# _w_complete_path TEXT   -> REPLY: completed text; array W_CANDIDATES[]
_w_complete_path() {
	local text=$1 cand prefix first i
	W_CANDIDATES=()
	_w_expand_tilde "$text"
	text=$REPLY
	mapfile -t W_CANDIDATES < <(compgen -f -- "$text" 2>/dev/null | sort 2>/dev/null)
	if ((${#W_CANDIDATES[@]} == 0)); then
		REPLY=$text
		return 1
	fi
	if ((${#W_CANDIDATES[@]} == 1)); then
		cand=${W_CANDIDATES[0]}
		[[ -d $cand ]] && cand+=/
		REPLY=$cand
		W_CANDIDATES=()
		return 0
	fi
	# Longest common prefix of all candidates.
	first=${W_CANDIDATES[0]}
	prefix=$first
	for cand in "${W_CANDIDATES[@]}"; do
		i=0
		while ((i < ${#prefix})) && [[ ${prefix:i:1} == "${cand:i:1}" ]]; do
			i=$((i + 1))
		done
		prefix=${prefix:0:i}
	done
	if ((${#prefix} > ${#text})); then
		REPLY=$prefix
	else
		REPLY=$text
	fi
	return 0
}

# ui_input TITLE PROMPT [INITIAL] [MAX_CHARS]   -> REPLY.  Returns 1 if cancelled.
ui_input() {
	local title=$1 prompt=$2 text=${3:-} max=${4:-1024}
	local cur=${#text} w key field off pre fw cw ccol i shown hint_line
	W_CANDIDATES=()
	_w_keys
	while :; do
		w=$((UI_COLS - 12))
		((w > 72)) && w=72
		((w < 24)) && w=24
		W_INNER=$w
		fw=$((w - 2))
		# Horizontal scrolling: find the left-most offset that keeps the
		# cursor inside the field.
		off=0
		while :; do
			ui_width "${text:off:cur-off}"
			((REPLY < fw)) && break
			off=$((off + 1))
		done
		pre=${text:off:cur-off}
		ui_width "$pre"
		ccol=$REPLY
		# Characters from the offset that fit in the field.
		shown=''
		cw=0
		for ((i = off; i < ${#text}; i++)); do
			ui_width "${text:i:1}"
			((cw + REPLY > fw)) && break
			shown+=${text:i:1}
			cw=$((cw + REPLY))
		done
		ui_pad "$shown" "$fw"
		field=$REPLY

		W_LINES=()
		_w_line ''
		[[ -n $prompt ]] && _w_line "$prompt" "$C_MUTED"
		_w_styled "${C_FOCUS}${G_POINTER}${S_RESET} ${S_UL}${field}${S_RESET}" "$G_POINTER $field"
		hint_line=$UI_INPUT_HINT
		if ((${#W_CANDIDATES[@]} > 0)); then
			hint_line=''
			for ((i = 0; i < ${#W_CANDIDATES[@]} && i < 6; i++)); do
				hint_line+="${W_CANDIDATES[i]##*/}  "
			done
			((${#W_CANDIDATES[@]} > 6)) && hint_line+="$G_ELLIPSIS"
		fi
		_w_line "$hint_line" "$C_MUTED"
		t ui.h.confirm; local h1=$REPLY
		t ui.h.cancel; local h2=$REPLY
		t ui.h.complete; local h3=$REPLY
		local fs fp
		if [[ $UI_INPUT_COMPLETE == path ]]; then
			_w_hint Enter "$h1" Tab "$h3" Esc "$h2"; fs=$REPLY
			_w_hint_plain Enter "$h1" Tab "$h3" Esc "$h2"; fp=$REPLY
		else
			_w_hint Enter "$h1" Esc "$h2"; fs=$REPLY
			_w_hint_plain Enter "$h1" Esc "$h2"; fp=$REPLY
		fi
		_w_window "$title" "$fs" "$fp" "$C_FOCUS"
		# Show the real cursor inside the field.
		local prow=$((W_ROW + 2))
		[[ -n $prompt ]] && prow=$((prow + 1))
		printf '\e[%d;%dH\e[?25h' "$prow" $((W_COL + 4 + ccol)) >&"$UI_FD"

		_w_key || continue
		key=$REPLY
		W_CANDIDATES=()
		case $key in
			enter)
				_w_close
				REPLY=$text
				return 0
				;;
			esc | ctrl-c)
				_w_close
				return 1
				;;
			left | ctrl-b) ((cur > 0)) && cur=$((cur - 1)) ;;
			right | ctrl-f) ((cur < ${#text})) && cur=$((cur + 1)) ;;
			home | ctrl-a) cur=0 ;;
			end | ctrl-e) cur=${#text} ;;
			backspace)
				if ((cur > 0)); then
					text=${text:0:cur-1}${text:cur}
					cur=$((cur - 1))
				fi
				;;
			delete | ctrl-d)
				((cur < ${#text})) && text=${text:0:cur}${text:cur+1}
				;;
			ctrl-u)
				text=${text:cur}
				cur=0
				;;
			ctrl-k) text=${text:0:cur} ;;
			ctrl-w)
				# Delete the word (or path component) before the cursor.
				pre=${text:0:cur}
				while [[ $pre == *[/\ ] ]]; do pre=${pre%?}; done
				while [[ -n $pre && $pre != *[/\ ] ]]; do pre=${pre%?}; done
				text=$pre${text:cur}
				cur=${#pre}
				;;
			tab)
				if [[ $UI_INPUT_COMPLETE == path ]]; then
					_w_complete_path "$text" || true
					text=$REPLY
					cur=${#text}
				fi
				;;
			space)
				if ((${#text} < max)); then
					text="${text:0:cur} ${text:cur}"
					cur=$((cur + 1))
				fi
				;;
			up | down | pgup | pgdn | insert | backtab | unknown | nul | f[0-9]* | ctrl-* | alt-*) ;;
			*)
				# A printable character (possibly multi-byte).
				if ((${#text} < max)) && [[ ${#key} -eq 1 ]]; then
					text=${text:0:cur}${key}${text:cur}
					cur=$((cur + 1))
				fi
				;;
		esac
	done
}

# --- check list -------------------------------------------------------------

declare -a UI_CHECK_LABEL=() UI_CHECK_STATE=() UI_CHECK_TIP=() UI_CHECK_VALUE=() UI_CHECK_EDITABLE=()

ui_check_reset() {
	UI_CHECK_LABEL=()
	UI_CHECK_STATE=()
	UI_CHECK_TIP=()
	UI_CHECK_VALUE=()
	UI_CHECK_EDITABLE=()
}

# ui_check_add LABEL STATE [TIP] [EDITABLE_VALUE]
# When a fourth argument is given (even an empty string) the row carries a
# text value that can be edited, shown after the label.
ui_check_add() {
	UI_CHECK_LABEL+=("$1")
	UI_CHECK_STATE+=("${2:-0}")
	UI_CHECK_TIP+=("${3:-}")
	if (($# >= 4)); then
		UI_CHECK_VALUE+=("$4")
		UI_CHECK_EDITABLE+=(1)
	else
		UI_CHECK_VALUE+=('')
		UI_CHECK_EDITABLE+=(0)
	fi
}

# ui_checklist TITLE PROMPT   toggle entries of UI_CHECK_*.  Returns 0 on OK
# (states and values updated in place), 1 when cancelled (arrays restored).
ui_checklist() {
	local title=$1 prompt=$2 n=${#UI_CHECK_LABEL[@]} sel=0 i w key line plain box label tipw
	local -a save_state=("${UI_CHECK_STATE[@]}") save_value=("${UI_CHECK_VALUE[@]}") tip_lines=()
	((n == 0)) && return 0
	_w_keys
	while :; do
		w=$((UI_COLS - 10))
		((w > 74)) && w=74
		((w < 30)) && w=30
		W_INNER=$w
		W_LINES=()
		if [[ -n $prompt ]]; then
			_w_line ''
			_w_line "$prompt" "$S_BOLD"
		fi
		_w_line ''
		for ((i = 0; i < n; i++)); do
			if ((UI_CHECK_STATE[i])); then box=$G_CHECK_ON; else box=$G_CHECK_OFF; fi
			label=${UI_CHECK_LABEL[i]}
			if ((UI_CHECK_EDITABLE[i])); then
				label+=" ${UI_CHECK_VALUE[i]}"
			fi
			ui_width "$box"
			ui_pad "$label" $((w - REPLY - 4))
			label=$REPLY
			plain="  $box $label "
			if ((i == sel)); then
				if ((UI_CHECK_STATE[i])); then
					line="${C_SEL}  ${C_ACCENT}${box}${S_RESET}${C_SEL}${S_BOLD} ${label} ${S_RESET}"
				else
					line="${C_SEL}  ${box}${S_BOLD} ${label} ${S_RESET}"
				fi
			elif ((UI_CHECK_STATE[i])); then
				line="  ${C_ACCENT}${box}${S_RESET} ${label} "
			else
				line="  ${C_MUTED}${box}${S_RESET} ${label} "
			fi
			_w_styled "$line" "$plain"
		done
		_w_line ''
		# Explanation of the highlighted entry, always three lines tall so
		# that the window does not jump around.
		tipw=$((w - 2))
		ui_wrap "${UI_CHECK_TIP[sel]}" "$tipw"
		tip_lines=("${UI_WRAPPED[@]}")
		for ((i = 0; i < 3; i++)); do
			_w_line " ${tip_lines[i]:-}" "$C_MUTED"
		done
		t ui.h.toggle; local h1=$REPLY
		t ui.h.confirm; local h2=$REPLY
		t ui.h.cancel; local h3=$REPLY
		t ui.h.edit; local h4=$REPLY
		local fs fp
		if ((UI_CHECK_EDITABLE[sel])); then
			_w_hint Space "$h1" e "$h4" Enter "$h2" Esc "$h3"; fs=$REPLY
			_w_hint_plain Space "$h1" e "$h4" Enter "$h2" Esc "$h3"; fp=$REPLY
		else
			_w_hint Space "$h1" Enter "$h2" Esc "$h3"; fs=$REPLY
			_w_hint_plain Space "$h1" Enter "$h2" Esc "$h3"; fp=$REPLY
		fi
		_w_window "$title" "$fs" "$fp" "$C_FOCUS"

		_w_key || continue
		key=$REPLY
		case $key in
			up | k | backtab) sel=$(((sel - 1 + n) % n)) ;;
			down | j | tab) sel=$(((sel + 1) % n)) ;;
			home) sel=0 ;;
			end) sel=$((n - 1)) ;;
			space | x) UI_CHECK_STATE[sel]=$((1 - UI_CHECK_STATE[sel])) ;;
			e | right)
				if ((UI_CHECK_EDITABLE[sel])); then
					if ui_input "$title" "${UI_CHECK_LABEL[sel]}" "${UI_CHECK_VALUE[sel]}" 64; then
						UI_CHECK_VALUE[sel]=$REPLY
						[[ -n $REPLY ]] && UI_CHECK_STATE[sel]=1
					fi
				fi
				;;
			enter)
				_w_close
				return 0
				;;
			esc | q | ctrl-c)
				UI_CHECK_STATE=("${save_state[@]}")
				UI_CHECK_VALUE=("${save_value[@]}")
				_w_close
				return 1
				;;
		esac
	done
}

# --- file browser -----------------------------------------------------------

UI_PICK_SUFFIXES='iso img raw dd bin usb gz xz bz2 bzip2 zst zip lzma z'

declare -a _W_ENT_NAME=() _W_ENT_TYPE=() _W_ENT_SIZE=() _W_ENT_TIME=()

# _w_read_dir DIR SHOW_HIDDEN SHOW_ALL   fill _W_ENT_* (directories first,
# then files, each group sorted case-insensitively).  Returns 1 if unreadable.
_w_read_dir() {
	local dir=$1 hidden=$2 all=$3 type size mtime name lower suffix keep rec
	local -a recs=()
	_W_ENT_NAME=()
	_W_ENT_TYPE=()
	_W_ENT_SIZE=()
	_W_ENT_TIME=()
	[[ -d $dir && -r $dir && -x $dir ]] || return 1
	# One find for the whole listing: type, size, mtime, name (NUL separated).
	while IFS= read -r -d '' rec; do
		type=${rec%%$'\t'*}
		rec=${rec#*$'\t'}
		size=${rec%%$'\t'*}
		rec=${rec#*$'\t'}
		mtime=${rec%%$'\t'*}
		name=${rec#*$'\t'}
		mtime=${mtime%%.*}
		# Names with tabs or newlines would break the sort records below.
		[[ $name == *$'\n'* || $name == *$'\t'* ]] && continue
		if ((!hidden)) && [[ $name == .* ]]; then
			continue
		fi
		case $type in
			d) recs+=("0"$'\t'"${name,,}"$'\t'"d"$'\t'"$size"$'\t'"$mtime"$'\t'"$name") ;;
			f)
				keep=$all
				if ((!keep)); then
					lower=${name,,}
					for suffix in $UI_PICK_SUFFIXES; do
						if [[ $lower == *."$suffix" ]]; then
							keep=1
							break
						fi
					done
				fi
				((keep)) && recs+=("1"$'\t'"${name,,}"$'\t'"f"$'\t'"$size"$'\t'"$mtime"$'\t'"$name")
				;;
		esac
	done < <(find -L "$dir" -mindepth 1 -maxdepth 1 -printf '%y\t%s\t%T@\t%f\0' 2>/dev/null)
	((${#recs[@]} == 0)) && return 0
	while IFS=$'\t' read -r _ _ type size mtime name; do
		[[ -n $name ]] || continue
		_W_ENT_NAME+=("$name")
		_W_ENT_TYPE+=("$type")
		_W_ENT_SIZE+=("$size")
		_W_ENT_TIME+=("$mtime")
	done < <(printf '%s\n' "${recs[@]}" | LC_ALL=C sort -t $'\t' -k1,1 -k2,2)
	return 0
}

# ui_filepicker TITLE START   START: a directory or a file path.
# -> REPLY: the chosen file.  Returns 1 when cancelled.
ui_filepicker() {
	local title=$1 start=${2:-} dir sel=0 top=0 hidden=0 all=0 reload=1 readable=1
	local n visible w key i name line plain meta mw nw path rows mark stamp
	_w_keys
	_w_expand_tilde "$start"
	start=$REPLY
	if [[ -d $start ]]; then
		dir=$start
	elif [[ -n $start && -d ${start%/*} ]]; then
		dir=${start%/*}
	else
		dir=${UI_INPUT_HOME:-${HOME:-/}}
	fi
	[[ -d $dir ]] || dir=/
	while :; do
		if ((reload)); then
			dir=$(cd "$dir" 2>/dev/null && pwd -P) || dir=/
			if _w_read_dir "$dir" "$hidden" "$all"; then readable=1; else readable=0; fi
			reload=0
			((sel >= ${#_W_ENT_NAME[@]})) && sel=0
			top=0
		fi
		n=${#_W_ENT_NAME[@]}
		w=$((UI_COLS - 8))
		((w > 96)) && w=96
		((w < 40)) && w=40
		W_INNER=$w
		rows=$((UI_ROWS - 7))
		((rows < 3)) && rows=3
		visible=$rows
		((sel < top)) && top=$sel
		((sel >= top + visible)) && top=$((sel - visible + 1))
		((top < 0)) && top=0

		W_LINES=()
		ui_trunc_mid "$dir" $((w - 2))
		_w_line " $REPLY" "$S_BOLD$C_BRIGHT"
		ui_repeat "$G_H" "$w"
		W_LINES+=("${C_SUBTLE}${REPLY}${S_RESET}")
		if ((n == 0)); then
			if ((readable)); then t ui.pick.empty; else t ui.pick.unreadable; fi
			_w_line " $REPLY" "$C_MUTED"
			for ((i = 1; i < visible; i++)); do _w_line ''; done
		else
			for ((i = top; i < top + visible; i++)); do
				if ((i >= n)); then
					_w_line ''
					continue
				fi
				name=${_W_ENT_NAME[i]}
				if [[ ${_W_ENT_TYPE[i]} == d ]]; then
					meta=''
					name+=/
				else
					human_size "${_W_ENT_SIZE[i]}"
					meta=$REPLY
					printf -v stamp '%(%Y-%m-%d %H:%M)T' "${_W_ENT_TIME[i]:-0}"
					ui_pad "$meta" 10 right
					meta="$REPLY  $stamp"
				fi
				ui_width "$meta"
				mw=$REPLY
				nw=$((w - 4 - mw - (mw > 0 ? 2 : 0)))
				((nw < 8)) && nw=8
				ui_pad "$name" "$nw"
				name=$REPLY
				mark='  '
				((i == sel)) && mark="$G_POINTER "
				if ((mw > 0)); then meta="  $meta"; fi
				plain=" $mark$name$meta "
				if ((i == sel)); then
					line="${C_SEL} ${C_FOCUS}${mark}${S_RESET}${C_SEL}${S_BOLD}${name}${S_RESET}${C_SEL}${C_MUTED}${meta} ${S_RESET}"
				elif [[ ${_W_ENT_TYPE[i]} == d ]]; then
					line=" ${mark}${C_FOCUS}${name}${S_RESET}${meta} "
				else
					line=" ${mark}${name}${C_MUTED}${meta}${S_RESET} "
				fi
				_w_styled "$line" "$plain"
			done
		fi
		ui_repeat "$G_H" "$w"
		W_LINES+=("${C_SUBTLE}${REPLY}${S_RESET}")
		t ui.h.open; local h1=$REPLY
		t ui.h.parent; local h2=$REPLY
		t ui.h.typepath; local h3=$REPLY
		t ui.h.hidden; local h4=$REPLY
		t ui.h.allfiles; local h5=$REPLY
		t ui.h.cancel; local h6=$REPLY
		_w_hint Enter "$h1" "$K_LEFT" "$h2" / "$h3" . "$h4" a "$h5" Esc "$h6"
		local fs=$REPLY
		_w_hint_plain Enter "$h1" "$K_LEFT" "$h2" / "$h3" . "$h4" a "$h5" Esc "$h6"
		ui_trunc "$REPLY" $((w - 1))
		if [[ $REPLY == *"$G_ELLIPSIS" ]]; then
			# The full legend does not fit: fall back to the essentials.
			_w_hint Enter "$h1" / "$h3" Esc "$h6"
			fs=$REPLY
			_w_hint_plain Enter "$h1" / "$h3" Esc "$h6"
		fi
		_w_styled " $fs" " $REPLY"
		_w_window "$title" '' '' "$C_FOCUS"

		_w_key || continue
		key=$REPLY
		case $key in
			up | k | ctrl-p) ((sel > 0)) && sel=$((sel - 1)) ;;
			down | j | ctrl-n) ((sel < n - 1)) && sel=$((sel + 1)) ;;
			home) sel=0 ;;
			end) ((n > 0)) && sel=$((n - 1)) ;;
			pgup) sel=$((sel - visible)); ((sel < 0)) && sel=0 ;;
			pgdn)
				sel=$((sel + visible))
				((sel > n - 1)) && sel=$((n - 1))
				((sel < 0)) && sel=0
				;;
			left | backspace | h)
				if [[ $dir != / ]]; then
					name=${dir##*/}
					dir=${dir%/*}
					[[ -n $dir ]] || dir=/
					reload=1
					# Put the selection back on the folder we came from.
					if _w_read_dir "$dir" "$hidden" "$all"; then
						for ((i = 0; i < ${#_W_ENT_NAME[@]}; i++)); do
							if [[ ${_W_ENT_NAME[i]} == "$name" ]]; then
								sel=$i
								break
							fi
						done
						reload=0
						readable=1
						top=0
					fi
				fi
				;;
			'~')
				dir=${UI_INPUT_HOME:-${HOME:-/}}
				sel=0
				reload=1
				;;
			.)
				hidden=$((1 - hidden))
				sel=0
				reload=1
				;;
			a)
				all=$((1 - all))
				sel=0
				reload=1
				;;
			/)
				UI_INPUT_COMPLETE=path
				t ui.pick.path
				path=$dir/
				[[ $dir == / ]] && path=/
				if ui_input "$title" "$REPLY" "$path"; then
					_w_expand_tilde "$REPLY"
					path=$REPLY
					UI_INPUT_COMPLETE=''
					if [[ -d $path ]]; then
						dir=$path
						sel=0
						reload=1
					elif [[ -f $path ]]; then
						_w_close
						REPLY=$path
						return 0
					elif [[ -n $path ]]; then
						t ui.pick.nofile "$path"
						ui_message "$title" "$REPLY" warn
					fi
				fi
				UI_INPUT_COMPLETE=''
				;;
			enter | right | l)
				if ((n > 0)); then
					if [[ ${_W_ENT_TYPE[sel]} == d ]]; then
						if [[ $dir == / ]]; then dir="/${_W_ENT_NAME[sel]}"; else dir="$dir/${_W_ENT_NAME[sel]}"; fi
						sel=0
						reload=1
					elif [[ $key != right && $key != l ]]; then
						if [[ $dir == / ]]; then path="/${_W_ENT_NAME[sel]}"; else path="$dir/${_W_ENT_NAME[sel]}"; fi
						_w_close
						REPLY=$path
						return 0
					fi
				fi
				;;
			esc | q | ctrl-c)
				_w_close
				return 1
				;;
		esac
	done
}

# --- text viewer ------------------------------------------------------------

# ui_textview TITLE FILE   scrollable view of a text file, opened at its end.
ui_textview() {
	local title=$1 file=$2 top=-1 n w rows key i line
	local -a lines=()
	_w_keys
	while :; do
		lines=()
		if [[ -r $file ]]; then
			mapfile -t lines <"$file" 2>/dev/null || lines=()
		fi
		n=${#lines[@]}
		w=$((UI_COLS - 6))
		((w < 30)) && w=30
		W_INNER=$w
		rows=$((UI_ROWS - 4))
		((rows < 3)) && rows=3
		# top = -1 means "follow the end of the file".
		if ((top < 0 || top > n - rows)); then
			top=$((n - rows))
		fi
		((top < 0)) && top=0
		W_LINES=()
		for ((i = top; i < top + rows; i++)); do
			line=${lines[i]:-}
			# Control characters would break the layout.
			line=${line//$'\t'/    }
			line=${line//$'\r'/}
			line=${line//$'\e'/}
			if [[ $line == *' ERROR: '* || $line == *' FATAL: '* ]]; then
				_w_line "$line" "$C_ERR"
			elif [[ $line == *' == '* ]]; then
				_w_line "$line" "$C_ACCENT"
			elif [[ $line == *' + '* ]]; then
				_w_line "$line" "$C_MUTED"
			else
				_w_line "$line"
			fi
		done
		t ui.h.scroll; local h1=$REPLY
		t ui.h.close; local h2=$REPLY
		_w_hint "$K_UPDOWN" "$h1" Esc "$h2"
		local fs=$REPLY
		_w_hint_plain "$K_UPDOWN" "$h1" Esc "$h2"
		_w_window "$title" "$fs" "$REPLY" "$C_SUBTLE"

		if ! _w_key; then
			# Idle: the file is re-read on the next pass (it may still be
			# growing); keep following its end if that is where we are.
			if ((top >= n - rows)); then top=-1; fi
			continue
		fi
		key=$REPLY
		case $key in
			up | k) ((top > 0)) && top=$((top - 1)) ;;
			down | j) top=$((top + 1)) ;;
			pgup) top=$((top - rows)); ((top < 0)) && top=0 ;;
			pgdn | space) top=$((top + rows)) ;;
			home | g) top=0 ;;
			end | G) top=-1 ;;
			esc | q | enter | ctrl-c | l)
				_w_close
				return 0
				;;
		esac
	done
}

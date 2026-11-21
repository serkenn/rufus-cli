# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# rufus-cli - terminal layer: capabilities, theme, text metrics, key input and
# flicker-free frame rendering.  Nothing in here knows about drives or images.
#
# Design notes
#  * Three glyph tiers: "rich" (any modern UTF-8 terminal emulator), "vt"
#    (the Linux console, whose fonts only cover a CP437-like repertoire) and
#    "ascii" (non UTF-8 locales, TERM=dumb, or on request).
#  * Colour tiers: truecolor, 256, 16, 8, none.  NO_COLOR is honoured.
#  * Wrapping is switched off while the full-screen UI is up (DECAWM), so a
#    line that is too long is clipped by the terminal instead of scrolling the
#    layout apart - a safety net for width mistakes with exotic characters.
#  * Everything is drawn through UI_FD and read through UI_IN_FD, never through
#    plain stdout/stdin, so redirections inside the program cannot corrupt
#    the screen.

[[ -n ${_RC_UI_LOADED:-} ]] && return 0
_RC_UI_LOADED=1

# Character ranges in patterns ("[ -~]") must mean code point ranges whatever
# the collation of the locale (this is only the default from bash 5.0 on).
shopt -s globasciiranges 2>/dev/null || true

UI_FD=1			# file descriptor the interface is drawn on
UI_IN_FD=0		# file descriptor keys are read from
_UI_FDS_READY=0
UI_TTY=0		# 1 when both ends are a real terminal
UI_UTF8=0		# 1 when multi-byte output is safe
UI_COLORS=0		# 0, 8, 16, 256 or 16777216
UI_GLYPHS='ascii'	# rich | vt | ascii
UI_COLS=80
UI_ROWS=24
UI_FULLSCREEN=0
UI_RESIZED=0
_UI_STTY_SAVED=''
_UI_SPIN=0

# --- capability detection ---------------------------------------------------

# True when bash itself decodes UTF-8 (i.e. LC_CTYPE is a working UTF-8 locale).
_ui_bash_utf8() {
	local n=0
	printf -v n '%d' "'あ" 2>/dev/null
	[[ $n == 12354 ]]
}

# Make sure the shell runs in a UTF-8 locale that really exists, so that
# string lengths count characters.  Tool output becomes predictable (English)
# as a side effect, which keeps the log consistent.
ui_setup_locale() {
	local want=${LC_ALL:-${LC_CTYPE:-${LANG:-}}} cand
	case ${want,,} in
		*utf-8* | *utf8*) ;;
		*)
			# The terminal is presumably not UTF-8: leave everything alone.
			UI_UTF8=0
			return 0
			;;
	esac
	for cand in C.UTF-8 C.utf8 en_US.UTF-8 en_US.utf8 "$want"; do
		# Assigning LC_ALL makes bash switch locale immediately; a missing
		# locale only produces a warning, hence the functional check.
		{ LC_ALL=$cand; } 2>/dev/null
		if _ui_bash_utf8; then
			export LC_ALL
			UI_UTF8=1
			return 0
		fi
	done
	{ LC_ALL=C; } 2>/dev/null
	export LC_ALL
	UI_UTF8=0
}

_ui_detect_colors() {
	local term=${TERM:-dumb} force=${RUFUS_CLI_COLOR:-auto}
	case $force in
		never | no | 0 | off) UI_COLORS=0; return ;;
		truecolor | 24bit) UI_COLORS=16777216; return ;;
		256) UI_COLORS=256; return ;;
		16) UI_COLORS=16; return ;;
		always | yes | on) force=always ;;
		*) force=auto ;;
	esac
	if [[ $force == auto ]]; then
		if [[ -n ${NO_COLOR:-} || $term == dumb || ! -t $UI_FD ]]; then
			UI_COLORS=0
			return
		fi
	fi
	case ${COLORTERM:-} in
		truecolor | 24bit) UI_COLORS=16777216; return ;;
	esac
	case $term in
		*-256color | *-direct | xterm-kitty | alacritty | foot | foot-* | wezterm | contour | ghostty | xterm-ghostty)
			UI_COLORS=256 ;;
		linux | linux-*) UI_COLORS=8 ;;
		xterm* | screen* | tmux* | rxvt* | vte* | konsole* | gnome* | st | st-* | putty* | cygwin | ansi) UI_COLORS=16 ;;
		dumb) UI_COLORS=0 ;;
		*) UI_COLORS=8 ;;
	esac
	[[ $force == always && $UI_COLORS -eq 0 ]] && UI_COLORS=8
	return 0
}

# _ui_sgr TRUECOLOR-RGB C256 C16 C8-ATTRS   -> REPLY: the escape for this tier
_ui_fg() {
	local rgb=$1 c256=$2 c16=$3 c8=$4
	if ((UI_COLORS >= 16777216)); then
		REPLY=$'\e[38;2;'"${rgb//,/;}m"
	elif ((UI_COLORS >= 256)); then
		REPLY=$'\e[38;5;'"${c256}m"
	elif ((UI_COLORS >= 16)); then
		REPLY=$'\e['"${c16}m"
	elif ((UI_COLORS >= 8)); then
		REPLY=$'\e['"${c8}m"
	else
		REPLY=''
	fi
}

_ui_bg() {
	local rgb=$1 c256=$2
	if ((UI_COLORS >= 16777216)); then
		REPLY=$'\e[48;2;'"${rgb//,/;}m"
	elif ((UI_COLORS >= 256)); then
		REPLY=$'\e[48;5;'"${c256}m"
	else
		REPLY=''
	fi
}

_ui_theme() {
	if ((UI_COLORS > 0)) || [[ -t $UI_FD && ${TERM:-dumb} != dumb ]]; then
		S_RESET=$'\e[0m' S_BOLD=$'\e[1m' S_DIM=$'\e[2m' S_REV=$'\e[7m' S_UL=$'\e[4m'
	else
		S_RESET='' S_BOLD='' S_DIM='' S_REV='' S_UL=''
	fi
	_ui_fg 86,211,100 77 92 '1;32';   C_ACCENT=$REPLY	# brand green
	_ui_fg 46,160,67 71 32 32;         C_ACCENT_DIM=$REPLY
	_ui_fg 88,166,255 75 96 '1;36';    C_FOCUS=$REPLY	# focus / keys
	_ui_fg 139,148,158 246 37 37;      C_MUTED=$REPLY	# secondary text
	_ui_fg 88,96,105 240 90 '1;30';    C_SUBTLE=$REPLY	# rules, borders
	_ui_fg 227,179,65 179 93 '1;33';   C_WARN=$REPLY
	_ui_fg 255,123,114 203 91 '1;31';  C_ERR=$REPLY
	_ui_fg 240,246,252 255 97 '1;37';  C_BRIGHT=$REPLY
	C_OK=$C_ACCENT
	# Selected row: a soft background where the terminal can do it, reverse
	# video everywhere else.
	_ui_bg 33,48,74 24
	if [[ -n $REPLY ]]; then
		C_SEL=$REPLY$C_BRIGHT
	else
		C_SEL=$S_REV
	fi
	_ui_bg 48,54,61 237
	C_TRACK=$REPLY
	if ((UI_COLORS >= 8 && UI_COLORS < 256)); then
		# "Bright black" is unreadable on several default palettes.
		C_SUBTLE=$S_DIM
	fi
}

_ui_glyphs() {
	local mode=$UI_GLYPHS
	G_ELLIPSIS='...'
	case $mode in
		rich)
			G_H='─' G_V='│' G_TL='╭' G_TR='╮' G_BL='╰' G_BR='╯' G_LT='├' G_RT='┤'
			G_OK='✔' G_FAIL='✖' G_WARN='▲' G_INFO='●' G_DOT='·' G_PENDING='○'
			G_POINTER='❯' G_DROP='▾' G_UP='▴' G_DOWN='▾' G_RIGHT='›' G_LEFT='‹'
			G_RADIO_ON='◉' G_RADIO_OFF='○' G_CHECK_ON='■' G_CHECK_OFF='□'
			G_BAR_FULL='█' G_BAR_EMPTY='░' G_ELLIPSIS='…' G_SEP='·' G_DIR='▸'
			G_BAR_PART=('' '▏' '▎' '▍' '▌' '▋' '▊' '▉')
			G_SPINNER=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
			;;
		vt)
			G_H='─' G_V='│' G_TL='┌' G_TR='┐' G_BL='└' G_BR='┘' G_LT='├' G_RT='┤'
			G_OK='+' G_FAIL='x' G_WARN='!' G_INFO='*' G_DOT='·' G_PENDING='-'
			G_POINTER='>' G_DROP='v' G_UP='^' G_DOWN='v' G_RIGHT='>' G_LEFT='<'
			G_RADIO_ON='(*)' G_RADIO_OFF='( )' G_CHECK_ON='[x]' G_CHECK_OFF='[ ]'
			G_BAR_FULL='█' G_BAR_EMPTY='░' G_SEP='·' G_DIR='>'
			G_BAR_PART=('' '' '' '' '▌' '▌' '▌' '▌')
			G_SPINNER=('|' '/' '-' "\\")
			;;
		*)
			G_H='-' G_V='|' G_TL='+' G_TR='+' G_BL='+' G_BR='+' G_LT='+' G_RT='+'
			G_OK='+' G_FAIL='x' G_WARN='!' G_INFO='*' G_DOT='.' G_PENDING='-'
			G_POINTER='>' G_DROP='v' G_UP='^' G_DOWN='v' G_RIGHT='>' G_LEFT='<'
			G_RADIO_ON='(*)' G_RADIO_OFF='( )' G_CHECK_ON='[x]' G_CHECK_OFF='[ ]'
			G_BAR_FULL='#' G_BAR_EMPTY='.' G_SEP='-' G_DIR='>'
			G_BAR_PART=('' '' '' '' '' '' '' '')
			G_SPINNER=('|' '/' '-' "\\")
			;;
	esac
}

# ui_init   detect everything; safe to call again after options changed.
ui_init() {
	if ((!_UI_FDS_READY)); then
		# Private duplicates of the original stdout/stdin: later redirections
		# of fd 1 (for instance while cleanup handlers run with their output
		# sent to the log) must not swallow what is meant for the terminal.
		if { exec {UI_FD}>&1; } 2>/dev/null && { exec {UI_IN_FD}<&0; } 2>/dev/null; then
			_UI_FDS_READY=1
		else
			UI_FD=1
			UI_IN_FD=0
		fi
	fi
	if [[ -t $UI_IN_FD && -t $UI_FD && ${TERM:-dumb} != dumb ]]; then
		UI_TTY=1
	else
		UI_TTY=0
	fi
	_ui_bash_utf8 && UI_UTF8=1
	if [[ -n ${RUFUS_CLI_ASCII:-} && ${RUFUS_CLI_ASCII} != 0 ]] || ((!UI_UTF8)); then
		UI_GLYPHS='ascii'
	elif [[ ${TERM:-} == linux || ${TERM:-} == linux-* ]]; then
		UI_GLYPHS='vt'
	else
		UI_GLYPHS='rich'
	fi
	_ui_detect_colors
	_ui_theme
	_ui_glyphs
	ui_measure
	# Japanese needs a UTF-8 terminal; the Linux console has no CJK glyphs.
	if [[ ${RC_LANG:-en} == ja ]] && { ((!UI_UTF8)) || [[ ${TERM:-} == linux || ${TERM:-} == linux-* ]]; }; then
		if [[ -z ${OPT_LANG:-} ]]; then
			i18n_set_lang en
		fi
	fi
	return 0
}

# ui_measure   refresh UI_ROWS / UI_COLS.
ui_measure() {
	local size r=0 c=0
	if ((UI_TTY)) && size=$(stty size <&"$UI_IN_FD" 2>/dev/null) && [[ $size =~ ^([0-9]+)\ ([0-9]+)$ ]]; then
		r=${BASH_REMATCH[1]}
		c=${BASH_REMATCH[2]}
	fi
	# Serial consoles and pseudo terminals without a size report 0x0.
	if ((r < 4)); then r=${LINES:-24}; fi
	if ((c < 20)); then c=${COLUMNS:-80}; fi
	if ! is_uint "$r" || ((r < 4)); then r=24; fi
	if ! is_uint "$c" || ((c < 20)); then c=80; fi
	UI_ROWS=$r
	UI_COLS=$c
}

# --- text metrics -----------------------------------------------------------

# ui_width STRING   -> REPLY: number of terminal cells the string occupies.
# East-Asian wide and full-width characters count double, combining marks and
# zero-width characters count nothing.  STRING must not contain escapes.
ui_width() {
	local s=$1 w i n c cp
	# Fast path: printable ASCII only.
	if [[ $s != *[!\ -~]* ]]; then
		REPLY=${#s}
		return 0
	fi
	n=${#s}
	w=0
	for ((i = 0; i < n; i++)); do
		c=${s:i:1}
		if [[ $c == [\ -~] ]]; then
			w=$((w + 1))
			continue
		fi
		printf -v cp '%d' "'$c" 2>/dev/null || cp=0
		if ((cp < 32 || (cp >= 127 && cp < 160))); then
			:	# control characters occupy no cell
		elif ((cp >= 0x300 && cp <= 0x36F)) || ((cp >= 0x200B && cp <= 0x200F)) ||
			((cp >= 0xFE00 && cp <= 0xFE0F)) || ((cp == 0xFEFF)) || ((cp >= 0x3099 && cp <= 0x309A)); then
			:	# combining marks, zero-width characters, variation selectors
		elif ((cp >= 0x1100 && cp <= 0x115F)) || ((cp >= 0x2E80 && cp <= 0x303E)) ||
			((cp >= 0x3041 && cp <= 0x33FF)) || ((cp >= 0x3400 && cp <= 0x4DBF)) ||
			((cp >= 0x4E00 && cp <= 0x9FFF)) || ((cp >= 0xA000 && cp <= 0xA4CF)) ||
			((cp >= 0xAC00 && cp <= 0xD7A3)) || ((cp >= 0xF900 && cp <= 0xFAFF)) ||
			((cp >= 0xFE30 && cp <= 0xFE4F)) || ((cp >= 0xFF00 && cp <= 0xFF60)) ||
			((cp >= 0xFFE0 && cp <= 0xFFE6)) || ((cp >= 0x1F300 && cp <= 0x1F64F)) ||
			((cp >= 0x1F900 && cp <= 0x1F9FF)) || ((cp >= 0x20000 && cp <= 0x3FFFD)); then
			w=$((w + 2))
		else
			w=$((w + 1))
		fi
	done
	REPLY=$w
}

# ui_trunc STRING MAX   -> REPLY: STRING cut to at most MAX cells, ending in an
# ellipsis when something was removed.
ui_trunc() {
	local s=$1 max=$2 w i n c out='' cw ell=$G_ELLIPSIS ew
	((max <= 0)) && { REPLY=''; return 0; }
	ui_width "$s"
	if ((REPLY <= max)); then
		REPLY=$s
		return 0
	fi
	ui_width "$ell"
	ew=$REPLY
	if ((max <= ew)); then
		ell=''
		ew=0
	fi
	n=${#s}
	w=0
	for ((i = 0; i < n; i++)); do
		c=${s:i:1}
		ui_width "$c"
		cw=$REPLY
		((w + cw > max - ew)) && break
		out+=$c
		w=$((w + cw))
	done
	REPLY=$out$ell
}

# ui_trunc_mid STRING MAX   -> REPLY: keeps both ends (good for paths).
ui_trunc_mid() {
	local s=$1 max=$2 n i c cw w head='' tail='' ell=$G_ELLIPSIS ew keep_head keep_tail
	((max <= 0)) && { REPLY=''; return 0; }
	ui_width "$s"
	if ((REPLY <= max)); then
		REPLY=$s
		return 0
	fi
	ui_width "$ell"
	ew=$REPLY
	if ((max <= ew + 2)); then
		ui_trunc "$s" "$max"
		return 0
	fi
	keep_tail=$(((max - ew) * 2 / 3))
	keep_head=$((max - ew - keep_tail))
	n=${#s}
	w=0
	for ((i = 0; i < n; i++)); do
		c=${s:i:1}
		ui_width "$c"
		cw=$REPLY
		((w + cw > keep_head)) && break
		head+=$c
		w=$((w + cw))
	done
	w=0
	for ((i = n - 1; i >= 0; i--)); do
		c=${s:i:1}
		ui_width "$c"
		cw=$REPLY
		((w + cw > keep_tail)) && break
		tail=$c$tail
		w=$((w + cw))
	done
	REPLY=$head$ell$tail
}

# ui_pad STRING WIDTH [left|right|center]   -> REPLY: padded (and truncated)
# to exactly WIDTH cells.
ui_pad() {
	local s=$1 width=$2 align=${3:-left} w fill lpad rpad
	((width <= 0)) && { REPLY=''; return 0; }
	ui_trunc "$s" "$width"
	s=$REPLY
	ui_width "$s"
	w=$REPLY
	fill=$((width - w))
	((fill < 0)) && fill=0
	case $align in
		right) printf -v REPLY '%*s%s' "$fill" '' "$s" ;;
		center)
			lpad=$((fill / 2))
			rpad=$((fill - lpad))
			printf -v REPLY '%*s%s%*s' "$lpad" '' "$s" "$rpad" ''
			;;
		*) printf -v REPLY '%s%*s' "$s" "$fill" '' ;;
	esac
}

# ui_repeat STRING COUNT   -> REPLY
ui_repeat() {
	local s=$1 n=$2 out=''
	if ((n <= 0)); then
		REPLY=''
		return 0
	fi
	printf -v out '%*s' "$n" ''
	REPLY=${out// /$s}
}

# ui_wrap TEXT WIDTH   -> array UI_WRAPPED[]: wrap to WIDTH cells.  Embedded
# newlines are honoured.  Latin words are kept whole; East-Asian text, which
# has no spaces, may break between any two wide characters (but not right
# before closing punctuation).
ui_wrap() {
	local text=$1 width=$2 para line lw atom aw i n c cw pending_space
	UI_WRAPPED=()
	((width < 4)) && width=4
	while IFS= read -r para || [[ -n $para ]]; do
		if [[ -z $para ]]; then
			UI_WRAPPED+=('')
			continue
		fi
		line=''
		lw=0
		atom=''
		aw=0
		pending_space=0
		n=${#para}
		for ((i = 0; i <= n; i++)); do
			c=''
			cw=0
			if ((i < n)); then
				c=${para:i:1}
				if [[ $c != ' ' && $c != $'\t' ]]; then
					ui_width "$c"
					cw=$REPLY
					if ((cw < 2)); then
						# Narrow character: it extends the current word.
						atom+=$c
						aw=$((aw + cw))
						continue
					fi
				fi
			fi
			# A space, a wide character or the end of the paragraph ends the word.
			if [[ -n $atom ]]; then
				_ui_wrap_emit "$atom" "$aw"
				atom=''
				aw=0
			fi
			if [[ -z $c ]]; then
				break
			elif [[ $c == ' ' || $c == $'\t' ]]; then
				pending_space=1
			else
				_ui_wrap_emit "$c" "$cw"
			fi
		done
		[[ -n $line ]] && UI_WRAPPED+=("$line")
	done <<<"$text"
	return 0
}

# Append one unbreakable piece to the line being built by ui_wrap (whose
# local variables are used directly).
_ui_wrap_emit() {
	local a=$1 w=$2 sep=0 i n c cw last lastw
	if ((pending_space && lw > 0)); then sep=1; fi
	pending_space=0
	if ((lw + sep + w <= width)); then
		if ((sep)); then line+=' '; fi
		line+=$a
		lw=$((lw + sep + w))
		return 0
	fi
	if ((lw > 0)); then
		last=''
		case $a in
			'、' | '。' | '，' | '．' | '！' | '？' | '）' | '」' | '』' | '】')
				# Closing punctuation must not start a line: take the last
				# character of the current line along with it.
				if ((${#line} > 1)); then
					last=${line: -1}
					line=${line%?}
				fi
				;;
		esac
		UI_WRAPPED+=("$line")
		line=''
		lw=0
		if [[ -n $last ]]; then
			ui_width "$last"
			lastw=$REPLY
			line=$last
			lw=$lastw
		fi
	fi
	if ((lw + w <= width)); then
		line+=$a
		lw=$((lw + w))
		return 0
	fi
	# A single word wider than a whole line: break it by cells.
	n=${#a}
	for ((i = 0; i < n; i++)); do
		c=${a:i:1}
		ui_width "$c"
		cw=$REPLY
		if ((lw + cw > width && lw > 0)); then
			UI_WRAPPED+=("$line")
			line=''
			lw=0
		fi
		line+=$c
		lw=$((lw + cw))
	done
	return 0
}

# --- size / time formatting for display --------------------------------------

# ui_progress_bar PERMILLE WIDTH   -> REPLY: a coloured bar of WIDTH cells.
# PERMILLE < 0 draws an "indeterminate" bar animated by the spinner counter.
ui_progress_bar() {
	local pm=$1 width=$2 full part cells eighths rest bar track
	((width < 4)) && width=4
	if ((pm < 0)); then
		# A short block travelling back and forth.
		local seg=$((width / 5)) pos span
		((seg < 2)) && seg=2
		span=$((width - seg))
		pos=$((_UI_SPIN % (span * 2 > 0 ? span * 2 : 1)))
		((pos > span)) && pos=$((span * 2 - pos))
		ui_repeat "$G_BAR_EMPTY" "$pos"
		bar=$C_SUBTLE$REPLY
		ui_repeat "$G_BAR_FULL" "$seg"
		bar+=$C_ACCENT$REPLY
		ui_repeat "$G_BAR_EMPTY" $((width - pos - seg))
		REPLY=$bar$C_SUBTLE$REPLY$S_RESET
		return 0
	fi
	((pm > 1000)) && pm=1000
	eighths=$((pm * width * 8 / 1000))
	full=$((eighths / 8))
	part=$((eighths % 8))
	cells=$full
	ui_repeat "$G_BAR_FULL" "$full"
	bar=$REPLY
	if ((part > 0 && full < width)) && [[ -n ${G_BAR_PART[part]} ]]; then
		bar+=${G_BAR_PART[part]}
		cells=$((cells + 1))
	fi
	rest=$((width - cells))
	if [[ -n $C_TRACK && $UI_GLYPHS == rich ]]; then
		# Solid track: a background colour behind the unfilled cells (and
		# behind the partial block, whose right-hand part is "empty").
		ui_repeat ' ' "$rest"
		track=$REPLY
		REPLY=$C_TRACK$C_ACCENT$bar$track$S_RESET
	else
		ui_repeat "$G_BAR_EMPTY" "$rest"
		REPLY=$C_ACCENT$bar$C_SUBTLE$REPLY$S_RESET
	fi
}

# ui_spinner   -> REPLY: the current spinner frame (advance with ui_tick).
ui_spinner() { REPLY=${G_SPINNER[_UI_SPIN % ${#G_SPINNER[@]}]}; }
ui_tick() { _UI_SPIN=$((_UI_SPIN + 1)); }

# ui_rate BYTES_PER_SECOND   -> REPLY ("31.4 MB/s"), decimal units like most tools.
ui_rate() {
	human_size_si "$1"
	REPLY="$REPLY/s"
}

# --- key input --------------------------------------------------------------

# ui_read_key [TIMEOUT]   -> REPLY: a key name, or the character typed.
# Names: enter esc tab backtab space backspace delete insert up down left
# right home end pgup pgdn f1..f12 ctrl-a .. ctrl-z, alt-<char>.
# Returns 1 on timeout and 2 at end of input (REPLY is then empty).
ui_read_key() {
	local timeout=${1:-} k='' seq='' c='' rc=0
	REPLY=''
	if [[ -n $timeout ]]; then
		IFS= read -rsN1 -t "$timeout" -u "$UI_IN_FD" k 2>/dev/null || rc=$?
	else
		IFS= read -rsN1 -u "$UI_IN_FD" k 2>/dev/null || rc=$?
	fi
	if ((rc != 0)); then
		# A timeout (or an interrupting signal such as SIGWINCH) reports a
		# status above 128; anything else means the input is gone.
		if ((rc > 128)); then return 1; fi
		return 2
	fi
	case $k in
		$'\e')
			# Either the Escape key or the start of a sequence: the rest of a
			# sequence follows immediately, a human is much slower.
			if ! IFS= read -rsN1 -t 0.05 -u "$UI_IN_FD" c 2>/dev/null; then
				REPLY='esc'
				return 0
			fi
			if [[ $c == '[' || $c == 'O' ]]; then
				seq=$c
				# Parameter and intermediate bytes, then one final byte.
				while IFS= read -rsN1 -t 0.05 -u "$UI_IN_FD" c 2>/dev/null; do
					seq+=$c
					[[ $c == [A-Za-z~] ]] && break
					((${#seq} > 16)) && break
				done
				_ui_decode_seq "$seq"
			elif [[ $c == $'\e' ]]; then
				REPLY='esc'
			else
				REPLY="alt-$c"
			fi
			;;
		$'\n' | $'\r') REPLY='enter' ;;
		$'\t') REPLY='tab' ;;
		$'\x7f' | $'\b') REPLY='backspace' ;;
		' ') REPLY='space' ;;
		$'\x01') REPLY='ctrl-a' ;; $'\x02') REPLY='ctrl-b' ;; $'\x03') REPLY='ctrl-c' ;;
		$'\x04') REPLY='ctrl-d' ;; $'\x05') REPLY='ctrl-e' ;; $'\x06') REPLY='ctrl-f' ;;
		$'\x07') REPLY='ctrl-g' ;; $'\x0b') REPLY='ctrl-k' ;; $'\x0c') REPLY='ctrl-l' ;;
		$'\x0e') REPLY='ctrl-n' ;; $'\x0f') REPLY='ctrl-o' ;; $'\x10') REPLY='ctrl-p' ;;
		$'\x12') REPLY='ctrl-r' ;; $'\x14') REPLY='ctrl-t' ;; $'\x15') REPLY='ctrl-u' ;;
		$'\x16') REPLY='ctrl-v' ;; $'\x17') REPLY='ctrl-w' ;; $'\x18') REPLY='ctrl-x' ;;
		$'\x19') REPLY='ctrl-y' ;; $'\x1a') REPLY='ctrl-z' ;;
		'') REPLY='nul' ;;
		*) REPLY=$k ;;
	esac
	return 0
}

_ui_decode_seq() {
	local seq=$1
	# Strip modifier parameters such as "1;5" (ctrl) so that ctrl/shift-arrows
	# still navigate: "[1;5C" -> "[C".
	if [[ $seq =~ ^\[1\;[0-9]+([A-Z])$ ]]; then
		seq="[${BASH_REMATCH[1]}"
	elif [[ $seq =~ ^\[([0-9]+)\;[0-9]+~$ ]]; then
		seq="[${BASH_REMATCH[1]}~"
	fi
	case $seq in
		'[A' | 'OA') REPLY='up' ;;
		'[B' | 'OB') REPLY='down' ;;
		'[C' | 'OC') REPLY='right' ;;
		'[D' | 'OD') REPLY='left' ;;
		'[H' | 'OH' | '[1~' | '[7~') REPLY='home' ;;
		'[F' | 'OF' | '[4~' | '[8~') REPLY='end' ;;
		'[2~') REPLY='insert' ;;
		'[3~') REPLY='delete' ;;
		'[5~') REPLY='pgup' ;;
		'[6~') REPLY='pgdn' ;;
		'[Z') REPLY='backtab' ;;
		'OP' | '[11~' | '[[A') REPLY='f1' ;;
		'OQ' | '[12~' | '[[B') REPLY='f2' ;;
		'OR' | '[13~' | '[[C') REPLY='f3' ;;
		'OS' | '[14~' | '[[D') REPLY='f4' ;;
		'[15~' | '[[E') REPLY='f5' ;;
		'[17~') REPLY='f6' ;; '[18~') REPLY='f7' ;; '[19~') REPLY='f8' ;;
		'[20~') REPLY='f9' ;; '[21~') REPLY='f10' ;; '[23~') REPLY='f11' ;; '[24~') REPLY='f12' ;;
		*) REPLY='unknown' ;;
	esac
}

# ui_flush_input   discard pending keystrokes (e.g. after a long operation, so
# that keys typed "blind" do not confirm a dialog).
ui_flush_input() {
	local _k
	while IFS= read -rsN1 -t 0.01 -u "$UI_IN_FD" _k 2>/dev/null; do :; done
	return 0
}

# --- terminal modes ---------------------------------------------------------

_ui_out() { printf '%s' "$1" >&"$UI_FD"; }

# ui_raw_on / ui_raw_off   no echo, no line editing; signals stay enabled so
# that Ctrl-C still reaches our trap.
ui_raw_on() {
	((UI_TTY)) || return 0
	if [[ -z $_UI_STTY_SAVED ]]; then
		_UI_STTY_SAVED=$(stty -g <&"$UI_IN_FD" 2>/dev/null) || _UI_STTY_SAVED=''
	fi
	stty -echo -icanon -ixon min 1 time 0 <&"$UI_IN_FD" 2>/dev/null || true
}

ui_raw_off() {
	((UI_TTY)) || return 0
	if [[ -n $_UI_STTY_SAVED ]]; then
		stty "$_UI_STTY_SAVED" <&"$UI_IN_FD" 2>/dev/null || stty sane <&"$UI_IN_FD" 2>/dev/null || true
		_UI_STTY_SAVED=''
	fi
}

# Some terminals (set up for East-Asian "ambiguous = wide") draw box and block
# characters two cells wide, which would ruin every layout.  Ask the terminal
# where the cursor ends up after printing one of them.
_ui_ambiguous_is_wide() {
	local reply='' col
	[[ $UI_GLYPHS == ascii ]] && return 1
	_ui_out $'\r'"$G_H"$'\e[6n'
	if ! IFS= read -rs -t 0.4 -d R -u "$UI_IN_FD" reply 2>/dev/null; then
		_ui_out $'\r\e[K'
		return 1
	fi
	_ui_out $'\r\e[K'
	col=${reply##*;}
	[[ $col == 3 ]]
}

ui_screen_enter() {
	((UI_TTY)) || return 1
	((UI_FULLSCREEN)) && return 0
	ui_raw_on
	if _ui_ambiguous_is_wide; then
		log "terminal renders ambiguous-width characters as wide: using ASCII drawing characters"
		UI_GLYPHS='ascii'
		_ui_glyphs
	fi
	# Alternate screen, hide cursor, no auto-wrap, cursor home.
	_ui_out $'\e[?1049h\e[?25l\e[?7l\e[H\e[2J'
	UI_FULLSCREEN=1
	_UI_PREV=()
	trap 'UI_RESIZED=1' WINCH
	cleanup_push 'ui_screen_leave'
	return 0
}

ui_screen_leave() {
	((UI_FULLSCREEN)) || { ui_raw_off; return 0; }
	_ui_out $'\e[0m\e[?7h\e[?25h\e[?1049l'
	UI_FULLSCREEN=0
	trap - WINCH
	ui_raw_off
	cleanup_remove 'ui_screen_leave' || true
	return 0
}

ui_cursor_show() { _ui_out $'\e[?25h'; }
ui_cursor_hide() { _ui_out $'\e[?25l'; }

# --- frame rendering --------------------------------------------------------
#
# A frame is an array of ready-to-print lines (escapes included, each no wider
# than the screen).  Only the lines that changed since the previous frame are
# sent to the terminal.

declare -a UI_FRAME=() _UI_PREV=()

ui_frame_begin() { UI_FRAME=(); }
ui_frame_add() { UI_FRAME+=("$1"); }

# ui_frame_invalidate   force the next flush to repaint everything (after an
# overlay was drawn on top of the frame, or after a resize).
ui_frame_invalidate() { _UI_PREV=(); }

ui_frame_flush() {
	local out='' i n=${#UI_FRAME[@]} prev=${#_UI_PREV[@]} rows=$UI_ROWS
	((n > rows)) && n=$rows
	for ((i = 0; i < n; i++)); do
		if ((i >= prev)) || [[ ${UI_FRAME[i]} != "${_UI_PREV[i]}" ]]; then
			out+=$'\e['"$((i + 1));1H${UI_FRAME[i]}"$'\e[0m\e[K'
		fi
	done
	if ((prev > n || prev == 0)); then
		# Clear whatever the previous frame had below this one.
		if ((n < rows)); then
			out+=$'\e['"$((n + 1));1H"$'\e[0m\e[J'
		fi
	fi
	if [[ -n $out ]]; then
		# Synchronized update where supported (ignored elsewhere).
		printf '%s' $'\e[?2026h'"$out"$'\e[?2026l' >&"$UI_FD"
	fi
	_UI_PREV=("${UI_FRAME[@]:0:n}")
}

# ui_put ROW COL TEXT   draw TEXT at an absolute position (1-based), on top of
# the current frame.  Callers must ui_frame_invalidate afterwards.
ui_put() {
	printf '\e[%d;%dH%s\e[0m' "$1" "$2" "$3" >&"$UI_FD"
}

# ui_check_resize   returns 0 (and re-measures) when the window size changed.
ui_check_resize() {
	((UI_RESIZED)) || return 1
	UI_RESIZED=0
	ui_measure
	ui_frame_invalidate
	_ui_out $'\e[2J'
	return 0
}

# --- plain (non full-screen) output -----------------------------------------

# ui_line TEXT...   print a line on the interface descriptor.
ui_line() { printf '%s\n' "$*" >&"$UI_FD"; }

# ui_err_line TEXT  print a line on stderr (plain CLI errors).
ui_err_line() { printf '%s\n' "$*" >&2; }

ui_ok() { ui_line "  ${C_OK}${G_OK}${S_RESET} $*"; }
ui_fail() { ui_line "  ${C_ERR}${G_FAIL}${S_RESET} $*"; }
ui_warn() { ui_line "  ${C_WARN}${G_WARN}${S_RESET} $*"; }
ui_info() { ui_line "  ${C_FOCUS}${G_INFO}${S_RESET} $*"; }
ui_dimline() { ui_line "  ${C_MUTED}$*${S_RESET}"; }

# ui_kv LABEL VALUE [LABEL_WIDTH]   aligned "label   value" line.
ui_kv() {
	local lw=${3:-18}
	ui_pad "$1" "$lw"
	ui_line "  ${C_MUTED}${REPLY}${S_RESET} $2"
}

# ui_rule [TITLE]   horizontal rule across the usable width, optional title.
ui_rule_text() {
	local title=${1:-} width=${2:-$((UI_COLS - 4))} tw
	((width > 76)) && width=76
	((width < 10)) && width=10
	if [[ -n $title ]]; then
		ui_width "$title"
		tw=$REPLY
		ui_repeat "$G_H" $((width - tw - 1 > 0 ? width - tw - 1 : 0))
		REPLY="${S_BOLD}${C_BRIGHT}${title}${S_RESET} ${C_SUBTLE}${REPLY}${S_RESET}"
	else
		ui_repeat "$G_H" "$width"
		REPLY="${C_SUBTLE}${REPLY}${S_RESET}"
	fi
}

# ui_fatal MESSAGE   used by die(): leave the full-screen UI first.
ui_fatal() {
	ui_screen_leave
	printf '%s%s%s %s\n' "$C_ERR" "${G_FAIL}" "$S_RESET" "$1" >&2
}

# ui_banner_lines   -> array UI_BANNER[]: the product logo, 2 lines.
ui_banner_lines() {
	UI_BANNER=()
	if [[ $UI_GLYPHS == ascii ]]; then
		UI_BANNER+=("${S_BOLD}${C_ACCENT}RUFUS CLI${S_RESET}")
		UI_BANNER+=("")
		return 0
	fi
	# A compact two-row block font.
	UI_BANNER+=("${C_ACCENT}█▀█ █ █ █▀▀ █ █ █▀${S_RESET}")
	UI_BANNER+=("${C_ACCENT_DIM}█▀▄ █▄█ █▀  █▄█ ▄█${S_RESET}")
	return 0
}

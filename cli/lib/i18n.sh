# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# rufus-cli - message catalogue (English and Japanese).
#
# Every module registers its own user-facing strings next to the code that
# uses them:
#
#     msg_def dev.busy 'Device %s is in use' 'デバイス %s は使用中です'
#
# and looks them up with `t KEY [ARGS...]`, which leaves the formatted text in
# REPLY.  Strings are printf formats.  The log is always written in English
# (as upstream Rufus does), so helpers exist for both variants.

[[ -n ${_RC_I18N_LOADED:-} ]] && return 0
_RC_I18N_LOADED=1

declare -gA _MSG_EN=() _MSG_JA=()
RC_LANG='en'

# msg_def KEY ENGLISH [JAPANESE]
msg_def() {
	_MSG_EN[$1]=$2
	if [[ -n ${3:-} ]]; then
		_MSG_JA[$1]=$3
	fi
	return 0
}

# i18n_set_lang LOCALE-OR-CODE   ("ja", "ja_JP.UTF-8", "en", "C", ...)
i18n_set_lang() {
	case ${1,,} in
		ja | ja[_.@-]* | jp | jpn | japanese) RC_LANG='ja' ;;
		*) RC_LANG='en' ;;
	esac
}

# Pick the UI language: explicit option, then our own variable, then the
# usual locale variables in their order of precedence.
i18n_init() {
	local want=${OPT_LANG:-}
	[[ -n $want ]] || want=${RUFUS_CLI_LANG:-}
	[[ -n $want ]] || want=${LC_ALL:-}
	[[ -n $want ]] || want=${LC_MESSAGES:-}
	[[ -n $want ]] || want=${LANG:-}
	i18n_set_lang "$want"
}

# _i18n_format LANG KEY [ARGS...]   -> REPLY
_i18n_format() {
	local lang=$1 key=$2 fmt
	shift 2
	if [[ $lang == ja && -n ${_MSG_JA[$key]+x} ]]; then
		fmt=${_MSG_JA[$key]}
	elif [[ -n ${_MSG_EN[$key]+x} ]]; then
		fmt=${_MSG_EN[$key]}
	else
		# Unknown key: show it rather than nothing, so the omission is visible.
		REPLY=$key
		(($# > 0)) && REPLY+=" $*"
		return 0
	fi
	# shellcheck disable=SC2059  # the catalogue entries are format strings
	printf -v REPLY "$fmt" "$@"
}

# t KEY [ARGS...]      localized text   -> REPLY
t() { _i18n_format "$RC_LANG" "$@"; }

# t_en KEY [ARGS...]   English text     -> REPLY
t_en() { _i18n_format en "$@"; }

# tp KEY [ARGS...]     print the localized text followed by a newline
tp() {
	_i18n_format "$RC_LANG" "$@"
	printf '%s\n' "$REPLY"
}

# msg_known KEY        true when the key is defined
msg_known() { [[ -n ${_MSG_EN[$1]+x} ]]; }

# fail_t KEY [ARGS...] like `fail`, with a catalogue message: the log gets the
# English text, ERR_MSG the localized one.  Always returns 1.
fail_t() {
	_i18n_format en "$@"
	log "ERROR: $REPLY"
	_i18n_format "$RC_LANG" "$@"
	ERR_MSG=$REPLY
	return 1
}

# log_t KEY [ARGS...]  log the English text of a catalogue message
log_t() {
	_i18n_format en "$@"
	log "$REPLY"
}

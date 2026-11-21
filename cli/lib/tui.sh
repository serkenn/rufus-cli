# shellcheck shell=bash disable=SC2153
# SPDX-License-Identifier: GPL-3.0-or-later
#
# rufus-cli - the full-screen interface: one dashboard laid out like the Rufus
# window (Drive Properties / Format Options / Status), driven from the
# keyboard.  Every field shows the value the plan resolved to; changing a
# field re-evaluates the fields that depend on it, as the Rufus dialog does.

[[ -n ${_RC_TUI_LOADED:-} ]] && return 0
_RC_TUI_LOADED=1

msg_def tui.sec.drive 'Drive Properties' 'ドライブ プロパティ'
msg_def tui.sec.format 'Format Options' 'フォーマット オプション'
msg_def tui.sec.status 'Status' '状態'
msg_def tui.f.device 'Device' 'デバイス'
msg_def tui.f.boot 'Boot selection' 'ブートの種類'
msg_def tui.f.mode 'Image option' 'イメージ オプション'
msg_def tui.f.scheme 'Partition scheme' 'パーティション構成'
msg_def tui.f.target 'Target system' 'ターゲット システム'
msg_def tui.f.label 'Volume label' 'ボリューム ラベル'
msg_def tui.f.fs 'File system' 'ファイル システム'
msg_def tui.f.cluster 'Cluster size' 'クラスター サイズ'
msg_def tui.f.quick 'Quick format' 'クイック フォーマット'
msg_def tui.f.extlabel 'Create extended label and icon files' '機能拡張されたラベルとアイコン ファイルを作成'
msg_def tui.f.badblocks 'Check device for bad blocks' '不良ブロックを検出'
msg_def tui.f.listhdd 'List USB Hard Drives' 'USB 接続の HDD を一覧表示'
msg_def tui.f.oldbios 'Add fixes for old BIOSes (extra partition, align, etc.)' '古い BIOS のために修正を追加 (パーティションの拡張、並び替え、その他)'
msg_def tui.f.verify 'Verify written data' '書き込んだデータを検証'
msg_def tui.b.start 'START' 'スタート'
msg_def tui.b.cancel 'CANCEL' 'キャンセル'
msg_def tui.b.close 'CLOSE' '閉じる'
msg_def tui.none '(none)' '(なし)'
msg_def tui.no_device 'No drive detected - plug in a USB drive' 'ドライブが見つかりません - USB ドライブを接続してください'
msg_def tui.image_file 'Image file: %s' 'イメージ ファイル: %s'
msg_def tui.ready 'READY' '準備完了'
msg_def tui.done 'READY - completed in %s' '準備完了 - %s で完了しました'
msg_def tui.failed 'Failed: %s' '失敗しました: %s'
msg_def tui.cancelled 'Cancelled' 'キャンセルされました'
msg_def tui.cancelling 'Cancelling - Please wait...' 'キャンセル中 - お待ちください...'
msg_def tui.scanning 'Scanning image...' 'イメージをスキャン中...'
msg_def tui.scan_failed 'Failed to scan image' 'イメージのスキャンに失敗'
msg_def tui.using_image 'Using image: %s' '%s を使用中'
msg_def tui.devices1 '%d device found' '%d 個のデバイスを検出しました。'
msg_def tui.devicesn '%d devices found' '%d 個のデバイスを検出しました。'
msg_def tui.passes.1 '1 pass' '1 パス'
msg_def tui.passes.2 '2 passes' '2 パス'
msg_def tui.passes.3 '4 passes (SLC)' '4 パス (SLC)'
msg_def tui.passes.4 '4 passes (MLC)' '4 パス (MLC)'
msg_def tui.passes.5 '4 passes (TLC)' '4 パス (TLC)'
msg_def tui.boot.select_file 'Select an image file...' 'イメージ ファイルを選択...'
msg_def tui.boot.type_path 'Type the path of an image file...' 'イメージ ファイルのパスを入力...'
msg_def tui.boot.pick_title 'Select a disk or ISO image' 'ディスクまたは ISO イメージを選択'
msg_def tui.k.move 'move' '移動'
msg_def tui.k.change 'change' '変更'
msg_def tui.k.start 'start' '開始'
msg_def tui.k.log 'log' 'ログ'
msg_def tui.k.hash 'checksums' 'チェックサム'
msg_def tui.k.refresh 'refresh' '更新'
msg_def tui.k.quit 'quit' '終了'
msg_def tui.k.cancel 'cancel' 'キャンセル'
msg_def tui.warn.title 'WARNING' '警告'
msg_def tui.warn.destroy "ALL DATA ON DEVICE '%s' WILL BE DESTROYED.\nTo continue with this operation, select OK. To quit select Cancel." \
	'デバイス “%s” のデータは消去されます。\nこの操作を続けるには [OK] を、終了する場合は [キャンセル] を選択してください。'
msg_def tui.warn.multipart 'IMPORTANT: THIS DRIVE CONTAINS MULTIPLE PARTITIONS!!\n\nThis may include partitions/volumes that are not mounted or even visible. Should you wish to proceed, you are responsible for any data loss on these partitions.' \
	'重要: このドライブは複数のパーティションを含んでいます!!\n\nマウントされていない、あるいは見えていないパーティション/ボリュームが含まれている可能性があります。続行した場合、これらのパーティションのデータ損失はすべて自己責任となります。'
msg_def tui.warn.multipart_title 'Multiple partitions detected' '複数のパーティションを検出しました。'
msg_def tui.warn.type_name 'This is not a removable flash drive (%s). Type its name (%s) to confirm:' \
	'これはリムーバブルのフラッシュ ドライブではありません (%s)。確認のためデバイス名 (%s) を入力してください:'
msg_def tui.cancel.title 'Cancel' 'キャンセル'
msg_def tui.cancel.body 'Cancelling may leave the device in an UNUSABLE state.\nIf you are sure you want to cancel, select YES. Otherwise, select NO.' \
	'キャンセルするとデバイスは使用不可能になるかもしれません。\nキャンセルするには [はい] を、そうではない場合は [いいえ] を選択してください。'
msg_def tui.quit.body 'An operation is in progress. Cancel it and quit?' '処理の実行中です。キャンセルして終了しますか?'
msg_def tui.wue.title 'Windows User Experience' 'Windows ユーザーエクスペリエンス'
msg_def tui.wue.prompt 'Customize Windows installation?' 'インストーラーをカスタムしますか?'
msg_def tui.deps.title 'Missing packages' '不足しているパッケージ'
msg_def tui.deps.body 'The following packages are required for this operation:\n\n  %s\n\nInstall them now?' \
	'この操作には次のパッケージが必要です:\n\n  %s\n\n今すぐインストールしますか?'
msg_def tui.deps.epel 'The EPEL repository will be enabled.' 'EPEL リポジトリを有効化します。'
msg_def tui.deps.install 'Install' 'インストール'
msg_def tui.error 'Error' 'エラー'
msg_def tui.hash.title 'Checksums' 'チェックサム'
msg_def tui.hash.computing 'Computing image checksums' 'イメージのチェックサムを計算中'
msg_def tui.log.title 'Log' 'ログ'
msg_def tui.too_small 'The terminal window is too small (%dx%d). Please enlarge it to at least %dx%d.' \
	'端末ウィンドウが小さすぎます (%dx%d)。%dx%d 以上に広げてください。'
msg_def tui.default_mark '%s (Default)' '%s (既定)'
msg_def tui.image_removed 'The selected image is no longer available' '選択したイメージは利用できなくなりました'
msg_def tui.elapsed 'Elapsed %s' '経過時間 %s'

TUI_STATE='idle'	# idle | running | done | failed | cancelled
TUI_STATUS=''		# text of the status line while idle
TUI_STATUS_KIND='ok'	# ok | warn | error | info
TUI_FOCUS=0		# index into TUI_ROW[]
TUI_DEV_NAME=''		# kernel name of the selected drive ('' = none)
TUI_DEV_FINGERPRINT=''
TUI_QUIT=0
declare -a TUI_ROW=()		# ids of the focusable rows, in display order
declare -a TUI_DEVS=()		# indices (into DEV_*) of the drives on offer

# --- data -------------------------------------------------------------------

# A cheap signature of the block devices present, to notice hot-plugging
# without re-scanning every second.
_tui_fingerprint() {
	local d size fp=''
	for d in "${RC_SYSFS:-/sys}"/block/*; do
		[[ -e $d ]] || continue
		size=''
		{ read -r size <"$d/size"; } 2>/dev/null || size=''
		fp+="${d##*/}:$size;"
	done
	REPLY=$fp
}

# Re-scan the drives and keep (or pick) the selected one.
_tui_scan() {
	local i found=-1
	dev_scan || true
	TUI_DEVS=()
	for ((i = 0; i < DEV_COUNT; i++)); do
		((DEV_LISTED[i])) && TUI_DEVS+=("$i")
	done
	if ((${TGT_IS_IMAGE_FILE:-0})); then
		# An image-file target was given on the command line: keep it.
		_tui_fingerprint
		TUI_DEV_FINGERPRINT=$REPLY
		return 0
	fi
	for i in "${TUI_DEVS[@]}"; do
		if [[ ${DEV_NAME[i]} == "$TUI_DEV_NAME" ]]; then
			found=$i
			break
		fi
	done
	if ((found < 0 && ${#TUI_DEVS[@]} > 0)); then
		# Like Rufus: a newly plugged drive is selected automatically.
		found=${TUI_DEVS[0]}
	fi
	_tui_select_device "$found"
	_tui_fingerprint
	TUI_DEV_FINGERPRINT=$REPLY
}

_tui_select_device() {
	local idx=$1
	if ((idx < 0)); then
		TUI_DEV_NAME=''
		TGT_PATH=''
		TGT_NAME=''
		TGT_SIZE=0
		TGT_SECTOR=512
		TGT_DISPLAY=''
		TGT_LABEL=''
		TGT_KIND=''
		TGT_PARTS=0
		TGT_IS_IMAGE_FILE=0
		return 0
	fi
	if dev_select "$idx"; then
		TUI_DEV_NAME=${DEV_NAME[idx]}
		TGT_LABEL=${DEV_LABEL[idx]:-}
		TGT_KIND=${DEV_KIND[idx]:-}
		TGT_PARTS=${DEV_PARTS[idx]:-0}
	else
		TUI_STATUS=$ERR_MSG
		TUI_STATUS_KIND='error'
		_tui_select_device -1
	fi
	return 0
}

# Options below the given level fall back to "automatic", so that they are
# derived again from what is above them (device/image -> mode -> scheme ->
# target -> file system -> cluster size).
_tui_reset_below() {
	case $1 in
		image) OPT_MODE='auto'; OPT_SCHEME='auto'; OPT_TARGET='auto'; OPT_FS='auto'; OPT_CLUSTER=0; OPT_LABEL_SET=0; OPT_LABEL=''; OPT_WUE_FLAGS=0 ;;
		mode) OPT_SCHEME='auto'; OPT_TARGET='auto'; OPT_FS='auto'; OPT_CLUSTER=0 ;;
		scheme) OPT_TARGET='auto'; OPT_FS='auto'; OPT_CLUSTER=0 ;;
		target) OPT_FS='auto'; OPT_CLUSTER=0 ;;
		fs | device) OPT_CLUSTER=0 ;;
	esac
}

# Re-evaluate the plan and derive the status line from it.
_tui_replan() {
	if plan_resolve; then
		if [[ $TUI_STATE == idle ]]; then
			t tui.ready
			TUI_STATUS=$REPLY
			TUI_STATUS_KIND='ok'
		fi
	else
		if [[ $TUI_STATE == idle ]]; then
			TUI_STATUS=$PLAN_ERROR
			case $PLAN_ERROR_KEY in
				plan.no_device | plan.no_image | plan.no_boot) TUI_STATUS_KIND='info' ;;
				*) TUI_STATUS_KIND='error' ;;
			esac
			if [[ $PLAN_ERROR_KEY == plan.no_device && ${#TUI_DEVS[@]} -eq 0 ]]; then
				t tui.no_device
				TUI_STATUS=$REPLY
			fi
		fi
	fi
	_tui_rows
	return 0
}

# Which rows exist (and can take the focus) in the current situation.
_tui_rows() {
	local old=${TUI_ROW[TUI_FOCUS]:-device} i
	TUI_ROW=(device boot)
	if [[ $OPT_BOOT == image && -n ${IMG_PATH:-} && ${#PLAN_MODES[@]} -gt 0 ]]; then
		TUI_ROW+=(mode)
	fi
	if [[ ${PLAN_MODE:-} != dd ]]; then
		TUI_ROW+=(scheme target label fs cluster quick extlabel)
		if [[ ${PLAN_SCHEME:-} == mbr && ${PLAN_TARGET:-} == bios && ${PLAN_BOOTABLE:-0} == 1 ]]; then
			TUI_ROW+=(oldbios)
		fi
	else
		TUI_ROW+=(verify)
	fi
	TUI_ROW+=(badblocks listhdd start)
	# Keep the focus on the same field when the list changes.
	TUI_FOCUS=0
	for ((i = 0; i < ${#TUI_ROW[@]}; i++)); do
		if [[ ${TUI_ROW[i]} == "$old" ]]; then
			TUI_FOCUS=$i
			break
		fi
	done
}

# --- drawing ----------------------------------------------------------------

_TUI_W=76	# content width
_TUI_PAD=''	# left margin

# _tui_field ID LABEL VALUE KIND [ENABLED]   one "label   value" row.
# KIND: select (a list opens), text (free text), ro (derived, not editable).
_tui_field() {
	local id=$1 label=$2 value=$3 kind=$4 enabled=${5:-1}
	local focused=0 lw=21 vw mark='  ' drop=' ' line
	[[ ${TUI_ROW[TUI_FOCUS]:-} == "$id" && $TUI_STATE != running ]] && focused=1
	((focused)) && mark="$G_POINTER "
	[[ $kind == select ]] && drop=$G_DROP
	vw=$((_TUI_W - 2 - 2 - lw - 1 - 2 - 1))
	ui_pad "$label" "$lw"
	label=$REPLY
	ui_pad "$value" "$vw"
	value=$REPLY
	if ((focused)); then
		line="${C_SEL} ${C_FOCUS}${mark}${S_RESET}${C_SEL}${label} ${S_BOLD}${C_BRIGHT}${value}${S_RESET}${C_SEL} ${C_FOCUS}${drop}${S_RESET}${C_SEL}  ${S_RESET}"
	elif ((!enabled)) || [[ $TUI_STATE == running ]]; then
		line=" ${mark}${C_SUBTLE}${label} ${value} ${drop}${S_RESET}  "
	elif [[ $kind == ro ]]; then
		line=" ${mark}${C_MUTED}${label}${S_RESET} ${C_MUTED}${value}${S_RESET} ${drop}  "
	else
		line=" ${mark}${C_MUTED}${label}${S_RESET} ${value} ${C_SUBTLE}${drop}${S_RESET}  "
	fi
	ui_frame_add "${_TUI_PAD}${line}"
}

# _tui_check ID LABEL STATE [EXTRA] [ENABLED]   a check-box row.
_tui_check() {
	local id=$1 label=$2 state=$3 extra=${4:-} enabled=${5:-1}
	local focused=0 mark='  ' box line bw ew lw
	[[ ${TUI_ROW[TUI_FOCUS]:-} == "$id" && $TUI_STATE != running ]] && focused=1
	((focused)) && mark="$G_POINTER "
	if ((state)); then box=$G_CHECK_ON; else box=$G_CHECK_OFF; fi
	ui_width "$box"
	bw=$REPLY
	ui_width "$extra"
	ew=$REPLY
	lw=$((_TUI_W - 1 - 2 - bw - 1 - (ew > 0 ? ew + 2 : 0) - 2))
	ui_pad "$label" "$lw"
	label=$REPLY
	[[ -n $extra ]] && extra="  $extra"
	if ((focused)); then
		line="${C_SEL} ${C_FOCUS}${mark}${S_RESET}${C_SEL}"
		if ((state)); then line+="${C_ACCENT}${box}${S_RESET}${C_SEL}"; else line+="${box}"; fi
		line+=" ${S_BOLD}${C_BRIGHT}${label}${S_RESET}${C_SEL}${extra}  ${S_RESET}"
	elif ((!enabled)) || [[ $TUI_STATE == running ]]; then
		line=" ${mark}${C_SUBTLE}${box} ${label}${extra}${S_RESET}  "
	elif ((state)); then
		line=" ${mark}${C_ACCENT}${box}${S_RESET} ${label}${C_MUTED}${extra}${S_RESET}  "
	else
		line=" ${mark}${C_MUTED}${box}${S_RESET} ${label}${C_MUTED}${extra}${S_RESET}  "
	fi
	ui_frame_add "${_TUI_PAD}${line}"
}

_tui_section() {
	t "$1"
	ui_rule_text "$REPLY" "$_TUI_W"
	ui_frame_add "${_TUI_PAD}${REPLY}"
}

_tui_blank() { ui_frame_add ''; }

# Text of the fields.
_tui_value_device() {
	if ((${TGT_IS_IMAGE_FILE:-0})); then
		t tui.image_file "${TGT_FILE:-}"
	elif [[ -n ${TGT_DISPLAY:-} ]]; then
		REPLY=$TGT_DISPLAY
	else
		t tui.none
	fi
}

_tui_value_boot() {
	case $OPT_BOOT in
		none) t plan.boot.none ;;
		freedos) t plan.boot.freedos ;;
		image)
			if [[ -n ${IMG_PATH:-} ]]; then
				REPLY=${IMG_NAME:-${IMG_PATH##*/}}
				[[ -n ${IMG_DESC:-} ]] && REPLY+="  ${G_SEP} ${IMG_DESC}"
			else
				t plan.boot.image_select
			fi
			;;
		*) t plan.boot.image_select ;;
	esac
}

_tui_value_mode() {
	case ${PLAN_MODE:-} in
		windows) t plan.mode.windows ;;
		isocopy) t plan.mode.iso ;;
		dd) t plan.mode.dd ;;
		*) REPLY='' ;;
	esac
}

_tui_passes_name() { t "tui.passes.${1:-1}"; }

_tui_draw() {
	local w rows=$UI_ROWS cols=$UI_COLS spaced=0 pad v fmt_on=1 pm bar barw pct left right lwid rwid fill
	local need_rows=22 need_cols=62
	w=$((cols - 2))
	((w > 78)) && w=78
	_TUI_W=$w
	pad=$(((cols - w) / 2))
	printf -v _TUI_PAD '%*s' "$pad" ''
	ui_frame_begin
	if ((rows < need_rows || cols < need_cols)); then
		t tui.too_small "$cols" "$rows" "$need_cols" "$need_rows"
		ui_wrap "$REPLY" $((cols - 2 > 10 ? cols - 2 : 10))
		for v in "${UI_WRAPPED[@]}"; do ui_frame_add " $v"; done
		ui_frame_flush
		return 0
	fi
	# Blank lines between the sections only when there is room for them.
	((rows >= ${#TUI_ROW[@]} + 15)) && spaced=1

	# Header.
	ui_banner_lines
	t cli.based_on "$RC_RUFUS_VERSION"
	v=$REPLY
	((spaced)) && _tui_blank
	if [[ -n ${UI_BANNER[1]} ]]; then
		ui_frame_add "${_TUI_PAD} ${UI_BANNER[0]}   ${S_BOLD}${C_BRIGHT}Rufus CLI${S_RESET} ${C_MUTED}${RC_VERSION} ${G_SEP} ${v}${S_RESET}"
		t cli.tagline
		ui_frame_add "${_TUI_PAD} ${UI_BANNER[1]}   ${C_MUTED}${REPLY}${S_RESET}"
	else
		ui_frame_add "${_TUI_PAD} ${UI_BANNER[0]} ${C_MUTED}${RC_VERSION} - ${v}${S_RESET}"
	fi
	((spaced)) && _tui_blank

	# Drive properties.
	_tui_section tui.sec.drive
	_tui_value_device; v=$REPLY
	t tui.f.device; _tui_field device "$REPLY" "$v" select
	_tui_value_boot; v=$REPLY
	t tui.f.boot; _tui_field boot "$REPLY" "$v" select
	if in_list mode "${TUI_ROW[@]}"; then
		_tui_value_mode; v=$REPLY
		t tui.f.mode
		if ((${#PLAN_MODES[@]} > 1)); then _tui_field mode "$REPLY" "$v" select; else _tui_field mode "$REPLY" "$v" ro; fi
	fi
	if [[ ${PLAN_MODE:-} != dd ]]; then
		if [[ -n ${PLAN_SCHEME:-} ]]; then plan_scheme_name "$PLAN_SCHEME"; v=$REPLY; else v='-'; fi
		t tui.f.scheme
		if ((${#PLAN_SCHEMES[@]} > 1)); then _tui_field scheme "$REPLY" "$v" select; else _tui_field scheme "$REPLY" "$v" ro; fi
		if [[ -n ${PLAN_TARGET:-} ]]; then plan_target_name "$PLAN_TARGET"; v=$REPLY; else v='-'; fi
		t tui.f.target
		if ((${#PLAN_TARGETS[@]} > 1)); then _tui_field target "$REPLY" "$v" select; else _tui_field target "$REPLY" "$v" ro; fi
	fi
	((spaced)) && _tui_blank

	# Format options.
	_tui_section tui.sec.format
	if [[ ${PLAN_MODE:-} != dd ]]; then
		t tui.f.label; _tui_field label "$REPLY" "${PLAN_FS_LABEL:-}" text
		if [[ -n ${PLAN_FS:-} ]]; then
			plan_fs_name "$PLAN_FS"; v=$REPLY
			if ((${PLAN_UEFI_NTFS:-0})); then t plan.fs.uefi_ntfs_note; v+="  (${REPLY})"; fi
			if ((${PLAN_SPLIT_WIM:-0})); then t plan.fs.split_note; v+="  (${REPLY})"; fi
		else
			v='-'
		fi
		t tui.f.fs
		if ((${#PLAN_FILESYSTEMS[@]} > 1)); then _tui_field fs "$REPLY" "$v" select; else _tui_field fs "$REPLY" "$v" ro; fi
		plan_cluster_name "${PLAN_CLUSTER:-0}"; v=$REPLY
		if ((${PLAN_CLUSTER:-0} > 0 && ${PLAN_CLUSTER:-0} == ${PLAN_CLUSTER_DEFAULT:-0})); then t tui.default_mark "$v"; v=$REPLY; fi
		t tui.f.cluster
		if ((${#FMT_CLUSTERS[@]} > 1)); then _tui_field cluster "$REPLY" "$v" select; else _tui_field cluster "$REPLY" "$v" ro; fi
		t tui.f.quick; _tui_check quick "$REPLY" "$OPT_QUICK"
		case ${PLAN_FS:-} in ext*) fmt_on=0 ;; esac
		((${IMG_HAS_AUTORUN:-0})) && [[ ${PLAN_MODE:-} == windows || ${PLAN_MODE:-} == isocopy ]] && fmt_on=0
		t tui.f.extlabel
		if ((fmt_on)); then _tui_check extlabel "$REPLY" "$OPT_EXTLABEL"; else _tui_check extlabel "$REPLY" 0 '' 0; fi
		if in_list oldbios "${TUI_ROW[@]}"; then
			t tui.f.oldbios; _tui_check oldbios "$REPLY" "$OPT_OLD_BIOS"
		fi
	else
		t tui.f.verify; _tui_check verify "$REPLY" "$OPT_VERIFY"
	fi
	v=''
	if ((OPT_BADBLOCKS > 0)); then _tui_passes_name "$OPT_BADBLOCKS"; v="$REPLY $G_DROP"; fi
	t tui.f.badblocks; _tui_check badblocks "$REPLY" $((OPT_BADBLOCKS > 0 ? 1 : 0)) "$v"
	t tui.f.listhdd; _tui_check listhdd "$REPLY" "$OPT_LIST_HDD"
	((spaced)) && _tui_blank

	# Status.
	_tui_section tui.sec.status
	barw=$((w - 2 - 9))
	case $TUI_STATE in
		running)
			pm=$JOB_OVERALL
			((pm < 0)) && pm=$JOB_PCT
			;;
		'done') pm=1000 ;;
		*) pm=0 ;;
	esac
	ui_progress_bar "$pm" "$barw"
	bar=$REPLY
	if ((pm >= 0)); then
		printf -v pct '%5d.%d%%' $((pm / 10)) $((pm % 10))
	else
		pct='        '
	fi
	ui_frame_add "${_TUI_PAD} ${bar} ${S_BOLD}${pct}${S_RESET}"

	left=''
	right=''
	if [[ $TUI_STATE == running ]]; then
		ui_spinner
		left="$REPLY $JOB_PHASE"
		[[ -n $JOB_NOTE ]] && left+=": $JOB_NOTE"
		if ((JOB_RATE > 0)); then ui_rate "$JOB_RATE"; right=$REPLY; fi
		if ((JOB_ETA >= 0 && JOB_PCT >= 0 && JOB_PCT < 1000)); then
			human_duration "$JOB_ETA"
			right+="${right:+  $G_SEP  }-$REPLY"
		fi
	else
		left=$TUI_STATUS
	fi
	ui_width "$right"
	rwid=$REPLY
	lwid=$((w - 2 - rwid - (rwid > 0 ? 2 : 0)))
	ui_pad "$left" "$lwid"
	left=$REPLY
	case $TUI_STATE:$TUI_STATUS_KIND in
		running:*) v=$C_FOCUS ;;
		*:error) v=$C_ERR ;;
		*:warn) v=$C_WARN ;;
		*:info) v=$C_MUTED ;;
		*) v=$C_OK$S_BOLD ;;
	esac
	if ((rwid > 0)); then
		ui_frame_add "${_TUI_PAD} ${v}${left}${S_RESET}  ${C_MUTED}${right}${S_RESET}"
	else
		ui_frame_add "${_TUI_PAD} ${v}${left}${S_RESET}"
	fi
	((spaced)) && _tui_blank

	# Buttons.
	local b1 b2 focused=0
	[[ ${TUI_ROW[TUI_FOCUS]:-} == start && $TUI_STATE != running ]] && focused=1
	if [[ $TUI_STATE == running ]]; then
		t tui.b.cancel
		b1="  $REPLY  "
		b2=''
		v=" ${C_SEL}${S_BOLD}${b1}${S_RESET}"
	else
		t tui.b.start
		b1="  $REPLY  "
		t tui.b.close
		b2="  $REPLY  "
		if ((focused)); then
			v=" ${C_SEL}${S_BOLD}${C_ACCENT}${G_POINTER}${b1}${S_RESET}   ${C_MUTED}${b2}${S_RESET}"
		elif ((${PLAN_READY:-0})); then
			v="  ${S_BOLD}${C_ACCENT}${b1}${S_RESET}   ${C_MUTED}${b2}${S_RESET}"
		else
			v="  ${C_SUBTLE}${b1}${S_RESET}   ${C_MUTED}${b2}${S_RESET}"
		fi
	fi
	ui_width " $G_POINTER$b1   $b2"
	fill=$((w - REPLY))
	((fill < 0)) && fill=0
	printf -v REPLY '%*s' "$fill" ''
	ui_frame_add "${_TUI_PAD}${REPLY}${v}"

	# Key legend and counters.
	_w_keys
	local k1 k2 k3 k4 k5 k6 legend plain info
	if [[ $TUI_STATE == running ]]; then
		t tui.k.cancel; k1=$REPLY
		t tui.k.log; k2=$REPLY
		_w_hint c "$k1" l "$k2"; legend=$REPLY
		_w_hint_plain c "$k1" l "$k2"; plain=$REPLY
		now_s
		human_duration $((REPLY - JOB_STARTED_S))
		t tui.elapsed "$REPLY"
		info=$REPLY
	else
		t tui.k.move; k1=$REPLY
		t tui.k.change; k2=$REPLY
		t tui.k.start; k3=$REPLY
		t tui.k.log; k4=$REPLY
		t tui.k.hash; k5=$REPLY
		t tui.k.quit; k6=$REPLY
		_w_hint "$K_UPDOWN" "$k1" Enter "$k2" s "$k3" l "$k4" '#' "$k5" q "$k6"; legend=$REPLY
		_w_hint_plain "$K_UPDOWN" "$k1" Enter "$k2" s "$k3" l "$k4" '#' "$k5" q "$k6"; plain=$REPLY
		if ((${#TUI_DEVS[@]} == 1)); then t tui.devices1 1; else t tui.devicesn "${#TUI_DEVS[@]}"; fi
		info=$REPLY
	fi
	ui_width "$plain"
	lwid=$REPLY
	ui_width "$info"
	rwid=$REPLY
	if ((lwid + rwid + 3 > w)); then
		# Not enough room for both: the legend matters more.
		info=''
		rwid=0
	fi
	fill=$((w - 1 - lwid - rwid))
	((fill < 0)) && fill=0
	printf -v REPLY '%*s' "$fill" ''
	ui_frame_add "${_TUI_PAD} ${legend}${REPLY}${C_SUBTLE}${info}${S_RESET}"
	ui_frame_flush
}

# Full repaint (used by widgets when they close or the window is resized).
_tui_redraw() {
	ui_frame_invalidate
	_tui_draw
}

# Row of the first field on screen, so that menus open near their field.
_tui_field_row() {
	local id=$1 i row=4
	((UI_ROWS >= ${#TUI_ROW[@]} + 15)) && row=6
	for ((i = 0; i < ${#TUI_ROW[@]}; i++)); do
		[[ ${TUI_ROW[i]} == "$id" ]] && break
	done
	REPLY=$((row + i))
}

# --- field editors ----------------------------------------------------------

_tui_edit_device() {
	local i idx title sel=0 n=0
	local -a map=()
	if ((${#TUI_DEVS[@]} == 0)); then
		t tui.no_device
		t tui.f.device
		local ttl=$REPLY
		t tui.no_device
		ui_message "$ttl" "$REPLY" info
		return 0
	fi
	ui_menu_reset
	for idx in "${TUI_DEVS[@]}"; do
		human_size "${DEV_SIZE[idx]}"
		if ((DEV_RO[idx])); then
			t cli.list.why.ro
			ui_menu_add "${DEV_DISPLAY[idx]}" "${DEV_PATH[idx]}" "$REPLY"
		else
			ui_menu_add "${DEV_DISPLAY[idx]}" "${DEV_PATH[idx]}"
		fi
		map+=("$idx")
		[[ ${DEV_NAME[idx]} == "$TUI_DEV_NAME" ]] && sel=$n
		n=$((n + 1))
	done
	t tui.f.device
	title=$REPLY
	if ui_menu "$title" "$sel"; then
		TGT_IS_IMAGE_FILE=0
		_tui_select_device "${map[REPLY]}"
		_tui_reset_below device
	fi
	return 0
}

# Image files lying around in the usual places -> _TUI_FOUND[] (newest first).
_tui_find_images() {
	local dir f home=${RC_INVOKER_HOME:-${HOME:-/}} dl=''
	local -a dirs=()
	_TUI_FOUND=()
	# The (possibly localized) download folder of the invoking user.
	if [[ -r $home/.config/user-dirs.dirs ]]; then
		while IFS= read -r f; do
			if [[ $f == XDG_DOWNLOAD_DIR=* ]]; then
				dl=${f#XDG_DOWNLOAD_DIR=}
				dl=${dl//\"/}
				dl=${dl//\$HOME/$home}
			fi
		done <"$home/.config/user-dirs.dirs"
	fi
	[[ -n $dl && -d $dl ]] && dirs+=("$dl")
	[[ -d $home/Downloads && $home/Downloads != "$dl" ]] && dirs+=("$home/Downloads")
	dirs+=("$PWD" "$home")
	while IFS= read -r -d '' f; do
		f=${f#*$'\t'}
		in_list "$f" "${_TUI_FOUND[@]}" || _TUI_FOUND+=("$f")
		((${#_TUI_FOUND[@]} >= 6)) && break
	done < <(
		for dir in "${dirs[@]}"; do
			find "$dir" -maxdepth 1 -type f \( -iname '*.iso' -o -iname '*.img' -o -iname '*.img.xz' -o -iname '*.img.gz' \
				-o -iname '*.img.zst' -o -iname '*.raw' \) -printf '%T@\t%p\0' 2>/dev/null
		done | LC_ALL=C sort -z -r -n 2>/dev/null
	)
	return 0
}
declare -a _TUI_FOUND=()

# Load an image file: scan it and make it the boot selection.
_tui_load_image() {
	local path=$1 rc=0
	[[ -n $path ]] || return 1
	t tui.scanning
	TUI_STATUS=$REPLY
	TUI_STATUS_KIND='info'
	_tui_draw
	_cli_disk_of_path "$path"
	DEV_EXTRA_PROTECTED=$REPLY
	img_analyze "$path" || rc=$?
	if ((rc != 0)); then
		t tui.scan_failed
		ui_message "$REPLY" "${ERR_MSG:-$path}" error
		return 1
	fi
	OPT_BOOT='image'
	OPT_IMAGE=$IMG_PATH
	_tui_reset_below image
	# The protected set may have changed (the image's own drive).
	_tui_scan
	return 0
}

_tui_edit_boot() {
	local title f sel=0 choice start
	local -a act=()
	_tui_find_images
	ui_menu_reset
	t tui.boot.select_file; ui_menu_add "$REPLY"; act+=(pick)
	for f in "${_TUI_FOUND[@]}"; do
		file_size "$f" || REPLY=0
		human_size "$REPLY"
		ui_menu_add "${f##*/}" "$REPLY"
		act+=("file:$f")
		[[ $OPT_BOOT == image && ${IMG_PATH:-} == "$f" ]] && sel=$((${#act[@]} - 1))
	done
	t plan.boot.none; ui_menu_add "$REPLY"; act+=(none)
	[[ $OPT_BOOT == none ]] && sel=$((${#act[@]} - 1))
	t plan.boot.freedos; ui_menu_add "$REPLY"; act+=(freedos)
	[[ $OPT_BOOT == freedos ]] && sel=$((${#act[@]} - 1))
	t tui.f.boot
	title=$REPLY
	_tui_field_row boot
	ui_menu "$title" "$sel" $((REPLY + 1)) || return 0
	choice=${act[REPLY]}
	case $choice in
		pick)
			start=${IMG_PATH:-}
			[[ -n $start ]] || start=${_TUI_FOUND[0]:-${RC_INVOKER_HOME:-$PWD}}
			UI_INPUT_HOME=${RC_INVOKER_HOME:-${HOME:-/}}
			t tui.boot.pick_title
			if ui_filepicker "$REPLY" "$start"; then
				_tui_load_image "$REPLY" || true
			fi
			;;
		file:*) _tui_load_image "${choice#file:}" || true ;;
		none)
			OPT_BOOT='none'
			_tui_reset_below image
			;;
		freedos)
			OPT_BOOT='freedos'
			_tui_reset_below image
			;;
	esac
	return 0
}

# Menu over a list of values.  _tui_pick TITLE FIELD CURRENT NAMEFN VALUES...
# -> REPLY: chosen value.
_tui_pick() {
	local title=$1 field=$2 current=$3 namefn=$4 v sel=0 n=0 row
	shift 4
	local -a vals=("$@")
	ui_menu_reset
	for v in "${vals[@]}"; do
		"$namefn" "$v"
		ui_menu_add "$REPLY"
		[[ $v == "$current" ]] && sel=$n
		n=$((n + 1))
	done
	# Open right below the field, like a drop-down list.
	_tui_field_row "$field"
	row=$((REPLY + 1))
	ui_menu "$title" "$sel" "$row" || return 1
	REPLY=${vals[REPLY]}
}

_tui_mode_name() {
	case $1 in
		iso)
			if ((${IMG_IS_WINDOWS:-0})); then t plan.mode.windows; else t plan.mode.iso; fi
			;;
		dd) t plan.mode.dd ;;
	esac
}

_tui_cluster_name() {
	plan_cluster_name "$1"
	if [[ $1 == "${PLAN_CLUSTER_DEFAULT:-0}" ]]; then
		t tui.default_mark "$REPLY"
	fi
}

_tui_fs_name() { plan_fs_name "$1"; }

_tui_activate() {
	local id=${TUI_ROW[TUI_FOCUS]:-} title cur
	case $id in
		device) _tui_edit_device ;;
		boot) _tui_edit_boot ;;
		mode)
			((${#PLAN_MODES[@]} > 1)) || return 0
			cur='iso'
			[[ ${PLAN_MODE:-} == dd ]] && cur='dd'
			t tui.f.mode
			if _tui_pick "$REPLY" mode "$cur" _tui_mode_name "${PLAN_MODES[@]}"; then
				OPT_MODE=$REPLY
				_tui_reset_below mode
			fi
			;;
		scheme)
			((${#PLAN_SCHEMES[@]} > 1)) || return 0
			t tui.f.scheme
			if _tui_pick "$REPLY" scheme "${PLAN_SCHEME:-}" plan_scheme_name "${PLAN_SCHEMES[@]}"; then
				OPT_SCHEME=$REPLY
				_tui_reset_below scheme
			fi
			;;
		target)
			((${#PLAN_TARGETS[@]} > 1)) || return 0
			t tui.f.target
			if _tui_pick "$REPLY" target "${PLAN_TARGET:-}" plan_target_name "${PLAN_TARGETS[@]}"; then
				OPT_TARGET=$REPLY
				_tui_reset_below target
			fi
			;;
		label)
			t tui.f.label
			title=$REPLY
			if ui_input "$title" '' "${PLAN_LABEL:-}" 32; then
				if [[ -n $REPLY ]]; then
					OPT_LABEL=$REPLY
					OPT_LABEL_SET=1
				else
					# An empty answer returns to the automatic label.
					OPT_LABEL=''
					OPT_LABEL_SET=0
				fi
			fi
			;;
		fs)
			((${#PLAN_FILESYSTEMS[@]} > 1)) || return 0
			t tui.f.fs
			if _tui_pick "$REPLY" fs "${PLAN_FS:-}" _tui_fs_name "${PLAN_FILESYSTEMS[@]}"; then
				OPT_FS=$REPLY
				_tui_reset_below fs
			fi
			;;
		cluster)
			((${#FMT_CLUSTERS[@]} > 1)) || return 0
			t tui.f.cluster
			if _tui_pick "$REPLY" cluster "${PLAN_CLUSTER:-0}" _tui_cluster_name "${FMT_CLUSTERS[@]}"; then
				OPT_CLUSTER=$REPLY
			fi
			;;
		quick) OPT_QUICK=$((1 - OPT_QUICK)) ;;
		extlabel) OPT_EXTLABEL=$((1 - OPT_EXTLABEL)) ;;
		oldbios) OPT_OLD_BIOS=$((1 - OPT_OLD_BIOS)) ;;
		verify) OPT_VERIFY=$((1 - OPT_VERIFY)) ;;
		badblocks)
			if ((OPT_BADBLOCKS > 0)); then
				OPT_BADBLOCKS=0
			else
				t tui.f.badblocks
				if _tui_pick "$REPLY" badblocks 1 _tui_passes_name 1 2 3 4 5; then
					OPT_BADBLOCKS=$REPLY
				fi
			fi
			;;
		listhdd)
			OPT_LIST_HDD=$((1 - OPT_LIST_HDD))
			_tui_scan
			;;
		start) _tui_start ;;
	esac
	if [[ $TUI_STATE != idle && $id != start ]]; then
		# Touching a setting after a finished job returns to "ready".
		TUI_STATE='idle'
	fi
	return 0
}

# --- running a job ----------------------------------------------------------

_tui_job_draw() {
	ui_tick
	if ui_check_resize; then :; fi
	_tui_draw
}

_tui_job_keys() {
	local wait=${1:-0} key title ok no
	[[ $wait == 0 ]] && wait=0.001
	ui_read_key "$wait" || return 0
	key=$REPLY
	case $key in
		c | esc | q | ctrl-c)
			((RC_CANCELLED)) && return 0
			t tui.cancel.title; title=$REPLY
			t ui.yes; ok=$REPLY
			t ui.no; no=$REPLY
			t tui.cancel.body
			if ui_confirm "$title" "$REPLY" "$ok" "$no" danger; then
				RC_CANCELLED=1
				t tui.cancelling
				JOB_NOTE=$REPLY
			fi
			;;
		l)
			t tui.log.title
			ui_textview "$REPLY" "$LOG_FILE"
			;;
		ctrl-l) ui_frame_invalidate ;;
	esac
	return 0
}

# Windows customization dialog (Rufus: "Windows User Experience").
# Returns 1 when the user cancelled the whole start.
_tui_wue_dialog() {
	local i n flags=0 title prompt label tip user
	win_wue_applicable || return 0
	win_wue_rows
	n=${#WUE_ROW_FLAG[@]}
	((n > 0)) || return 0
	user=${OPT_WUE_USER:-${RC_INVOKER:-}}
	[[ -z $user || $user == root ]] && user='User'
	ui_check_reset
	for ((i = 0; i < n; i++)); do
		t "${WUE_ROW_KEY[i]}"
		label=$REPLY
		if msg_known "${WUE_ROW_KEY[i]}.tip"; then t "${WUE_ROW_KEY[i]}.tip"; tip=$REPLY; else tip=''; fi
		if ((WUE_ROW_FLAG[i] == 0x40)); then
			ui_check_add "$label" "${WUE_ROW_DEFAULT[i]}" "$tip" "$user"
		else
			ui_check_add "$label" "${WUE_ROW_DEFAULT[i]}" "$tip"
		fi
	done
	t tui.wue.title; title=$REPLY
	t tui.wue.prompt; prompt=$REPLY
	ui_checklist "$title" "$prompt" || return 1
	for ((i = 0; i < n; i++)); do
		if ((UI_CHECK_STATE[i])); then
			flags=$((flags | WUE_ROW_FLAG[i]))
			if ((WUE_ROW_FLAG[i] == 0x40)); then
				OPT_WUE_USER=${UI_CHECK_VALUE[i]}
			fi
		fi
	done
	OPT_WUE_FLAGS=$flags
	return 0
}

# Offer to install what the plan needs.  Returns 1 when the job cannot go on.
_tui_deps() {
	local rc=0 c title body ok
	local -a missing=() optional=() wanted=() installable=()
	deps_check "${PLAN_CMDS[@]}" || missing=("${DEPS_MISSING[@]}")
	deps_check "${PLAN_CMDS_OPTIONAL[@]}" || optional=("${DEPS_MISSING[@]}")
	((${#missing[@]} == 0 && ${#optional[@]} == 0)) && return 0
	wanted=("${missing[@]}" "${optional[@]}")
	deps_resolve "${wanted[@]}"
	t tui.deps.title
	title=$REPLY
	for c in "${missing[@]}"; do
		if in_list "$c" "${DEPS_UNAVAILABLE[@]}"; then
			t deps.unavailable "$c" "$DEPS_PRETTY"
			ui_message "$title" "$REPLY" error
			return 1
		fi
	done
	for c in "${wanted[@]}"; do
		in_list "$c" "${DEPS_UNAVAILABLE[@]}" || installable+=("$c")
	done
	((${#DEPS_PKGS[@]} > 0)) || return 0
	t tui.deps.body "${DEPS_PKGS[*]}"
	body=$REPLY
	if ((DEPS_EPEL)); then
		t tui.deps.epel
		body+=$'\n\n'"$REPLY"
	fi
	t tui.deps.install
	ok=$REPLY
	if ! ui_confirm "$title" "$body" "$ok" ''; then
		# Declining is fine as long as only optional tools are missing.
		((${#missing[@]} == 0))
		return
	fi
	TUI_STATE='running'
	RC_JOB_ACTIVE=1
	RC_CANCELLED=0
	job_reset
	JOB_UI_HOOK=_tui_job_draw
	JOB_KEY_HOOK=_tui_job_keys
	t deps.installing "${DEPS_PKGS[*]}"
	job_phase "$REPLY"
	deps_install "${installable[@]}" || rc=$?
	JOB_UI_HOOK=''
	JOB_KEY_HOOK=''
	RC_JOB_ACTIVE=0
	RC_CANCELLED=0
	TUI_STATE='idle'
	if ! deps_check "${missing[@]}"; then
		((rc == 130)) && return 1
		ui_message "$title" "${ERR_MSG:-}" error
		return 1
	fi
	return 0
}

# The warnings Rufus shows before it touches the drive.
_tui_confirm() {
	local title body ok w name=${TGT_NAME:-}
	t tui.warn.title; title=$REPLY
	t tui.warn.destroy "${TGT_DISPLAY:-$TGT_PATH}"
	body=$REPLY
	for w in "${PLAN_WARNINGS[@]}"; do
		body+=$'\n\n'"$w"
	done
	t ui.ok; ok=$REPLY
	ui_confirm "$title" "$body" "$ok" '' danger || return 1
	if ((${TGT_PARTS:-0} > 1)); then
		t tui.warn.multipart_title; title=$REPLY
		t tui.warn.multipart
		ui_confirm "$title" "$REPLY" "$ok" '' danger || return 1
	fi
	case ${TGT_KIND:-} in
		hdd | fixed)
			_cli_kind_name "$TGT_KIND"
			t tui.warn.type_name "$REPLY" "$name"
			body=$REPLY
			t tui.warn.title
			ui_input "$REPLY" "$body" '' 32 || return 1
			[[ $REPLY == "$name" || $REPLY == "/dev/$name" ]] || return 1
			;;
	esac
	return 0
}

_tui_start() {
	local rc=0
	TUI_STATE='idle'
	_tui_replan
	if ((!PLAN_READY)); then
		t tui.error
		ui_message "$REPLY" "$PLAN_ERROR" error
		return 0
	fi
	if [[ $PLAN_MODE == windows ]]; then
		_tui_wue_dialog || return 0
		_tui_replan
		((PLAN_READY)) || return 0
	fi
	_tui_deps || {
		_tui_replan
		return 0
	}
	_tui_replan
	_tui_confirm || return 0

	TUI_STATE='running'
	ui_flush_input
	JOB_UI_HOOK=_tui_job_draw
	JOB_KEY_HOOK=_tui_job_keys
	pipeline_run || rc=$?
	JOB_UI_HOOK=''
	JOB_KEY_HOOK=''
	ui_flush_input
	case $PIPE_RESULT in
		ok)
			TUI_STATE='done'
			human_duration "$PIPE_ELAPSED"
			t tui.done "$REPLY"
			TUI_STATUS=$REPLY
			TUI_STATUS_KIND='ok'
			;;
		cancelled)
			TUI_STATE='cancelled'
			t tui.cancelled
			TUI_STATUS=$REPLY
			TUI_STATUS_KIND='warn'
			;;
		*)
			TUI_STATE='failed'
			t tui.failed "$ERR_MSG"
			TUI_STATUS=$REPLY
			TUI_STATUS_KIND='error'
			;;
	esac
	# An audible cue, like the sound Rufus plays when it is done.
	printf '\a' >&"$UI_FD"
	if ((!${TGT_IS_IMAGE_FILE:-0})); then
		_tui_scan
	fi
	plan_resolve || true
	_tui_rows
	return 0
}

_tui_hash() {
	local title body a rc=0
	[[ $OPT_BOOT == image && -n ${IMG_PATH:-} ]] || return 0
	t tui.hash.title
	title=$REPLY
	TUI_STATE='running'
	RC_JOB_ACTIVE=1
	RC_CANCELLED=0
	job_reset
	JOB_UI_HOOK=_tui_job_draw
	JOB_KEY_HOOK=_tui_job_keys
	t tui.hash.computing
	job_phase "$REPLY"
	job_step 0 1000
	hash_file "$IMG_PATH" md5 sha1 sha256 || rc=$?
	JOB_UI_HOOK=''
	JOB_KEY_HOOK=''
	RC_JOB_ACTIVE=0
	RC_CANCELLED=0
	TUI_STATE='idle'
	_tui_replan
	if ((rc != 0)); then
		((rc == 130)) || ui_message "$title" "${ERR_MSG:-}" error
		return 0
	fi
	body="${IMG_NAME:-}"$'\n'
	for a in md5 sha1 sha256; do
		body+=$'\n'"${a^^}"$'\n'"${HASH_RESULT[$a]:-}"$'\n'
	done
	ui_message "$title" "$body" info
	return 0
}

# --- main loop --------------------------------------------------------------

tui_main() {
	local key rc n
	UI_INPUT_HOME=${RC_INVOKER_HOME:-${HOME:-/}}
	if ! ui_screen_enter; then
		fail "the interactive interface needs a terminal"
		_cli_error
		return 1
	fi
	UI_BASE_REDRAW=_tui_redraw
	TUI_STATE='idle'
	TUI_QUIT=0
	t tui.ready
	TUI_STATUS=$REPLY
	TUI_STATUS_KIND='ok'
	_tui_scan
	if [[ -n ${OPT_IMAGE:-} ]]; then
		_tui_load_image "$OPT_IMAGE" || OPT_IMAGE=''
	fi
	[[ -n $OPT_BOOT ]] || OPT_BOOT='image'
	_tui_replan
	# Start on the first thing that still needs an answer.
	if [[ -n $TUI_DEV_NAME && $OPT_BOOT == image && -z ${IMG_PATH:-} ]]; then
		TUI_FOCUS=1
	fi

	while ((!TUI_QUIT)); do
		ui_check_resize || true
		_tui_draw
		rc=0
		ui_read_key 1 || rc=$?
		if ((rc == 2)); then
			break
		elif ((rc != 0)); then
			# Idle: notice drives being plugged in or removed.
			_tui_fingerprint
			if [[ $REPLY != "$TUI_DEV_FINGERPRINT" ]]; then
				_tui_scan
				_tui_replan
			fi
			if [[ $OPT_BOOT == image && -n ${IMG_PATH:-} && ! -r $IMG_PATH ]]; then
				t tui.image_removed
				TUI_STATUS=$REPLY
				TUI_STATUS_KIND='warn'
			fi
			continue
		fi
		key=$REPLY
		n=${#TUI_ROW[@]}
		case $key in
			up | k | backtab) TUI_FOCUS=$(((TUI_FOCUS - 1 + n) % n)) ;;
			down | j | tab) TUI_FOCUS=$(((TUI_FOCUS + 1) % n)) ;;
			home) TUI_FOCUS=0 ;;
			end) TUI_FOCUS=$((n - 1)) ;;
			enter | space | right)
				_tui_activate
				_tui_replan
				;;
			s | S | f5)
				_tui_start
				;;
			l)
				t tui.log.title
				ui_textview "$REPLY" "$LOG_FILE"
				;;
			'#' | h)
				_tui_hash
				;;
			r)
				_tui_scan
				_tui_replan
				;;
			ctrl-l) ui_frame_invalidate ;;
			q | Q | esc | ctrl-c) TUI_QUIT=1 ;;
		esac
	done
	ui_screen_leave
	if ((${TGT_IS_IMAGE_FILE:-0})); then
		dev_detach_image || true
	fi
	return 0
}

# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# rufus-cli - the job pipeline: executes a resolved plan (plan.sh) step by
# step, in the order of Rufus' FormatThread (src/format.c):
#
#   close volumes -> clear MBR/GPT -> [bad blocks] -> partition -> format ->
#   boot records -> copy files -> [customize] -> finalize
#
# or, for raw images: [bad blocks] -> write image -> [verify] -> finalize.
#
# The list of steps is built up front so that an interface can show what is
# coming; PIPE_HOOK (if set) is called whenever a step changes state.

[[ -n ${_RC_PIPELINE_LOADED:-} ]] && return 0
_RC_PIPELINE_LOADED=1

# Status texts (official Rufus wording where one exists).
msg_def pipe.prepare 'Closing existing volume...' 'ボリュームを閉じています...'
msg_def pipe.wipe 'Clearing MBR/PBR/GPT structures...' 'MBR/PBR/GPT 構造のクリーニング中...'
msg_def pipe.badblocks 'Checking the device for bad blocks...' '不良ブロックを検出中...'
msg_def pipe.partition 'Partitioning (%s)...' 'パーティション分割中 (%s)...'
msg_def pipe.format 'Formatting (%s)...' 'フォーマット中 (%s)...'
msg_def pipe.bootrec 'Writing boot records...' 'ブート レコードを書き込んでいます...'
msg_def pipe.dosfiles 'Copying DOS files...' 'DOS ファイルをコピー中...'
msg_def pipe.copy 'Copying ISO files' 'ISO ファイルをコピー中'
msg_def pipe.split 'Splitting install.wim' 'install.wim を分割中'
msg_def pipe.patch 'Setting up boot files...' 'ブート用ファイルを設定中...'
msg_def pipe.customize 'Applying Windows customization' 'Windows カスタムを適応中'
msg_def pipe.extlabel 'Creating extended label and icon files...' '拡張ラベルとアイコン ファイルを作成中...'
msg_def pipe.write 'Writing image' 'イメージを書き込み中'
msg_def pipe.verify 'Verifying written data' '書き込んだデータを検証中'
msg_def pipe.finalize 'Finalizing, please wait...' '最終処理中です。もう間もなく終わります...'
msg_def pipe.flushing 'Flushing buffers...' 'バッファを書き出し中...'

msg_def pipe.err.badblocks 'Check completed: %d bad block(s) found. The device should not be used.' \
	'検出完了: 不良ブロックが %d 個見つかりました。このデバイスは使用しないでください。'
msg_def pipe.err.partition 'Could not partition drive.' 'ドライブのパーティション設定中にエラーが発生しました。'
msg_def pipe.err.copy 'Could not copy files to target drive.' 'ファイルをターゲット ドライブへコピーできませんでした。'
msg_def pipe.err.patch 'Unable to patch/setup files for boot.' 'ファイルへブート用パッチを当てられません。'
msg_def pipe.err.no_efi 'No UEFI boot loader could be placed on the media' 'UEFI ブートローダーをメディアに配置できませんでした。'
msg_def pipe.err.generic 'Undetermined error while formatting.' 'フォーマット中に判別できないエラーが起きました。'
msg_def pipe.cancelled 'Cancelled by user.' 'ユーザーによってキャンセルされました。'

declare -a PIPE_ID=() PIPE_TITLE=() PIPE_WEIGHT=() PIPE_STATE=() PIPE_SECONDS=()
PIPE_HOOK=''		# function: PIPE_HOOK <index> <state>
PIPE_RESULT=''		# ok | cancelled | failed
PIPE_ELAPSED=0
PIPE_MAIN_NODE=''	# node of the main partition (or the disk itself for sfd)
PIPE_MAIN_START=0	# first sector of the main partition
PIPE_MNT=''		# where the new file system is mounted, when it is
PIPE_USB_LABEL=''	# label actually found on the new file system

_pipe_add() {
	PIPE_ID+=("$1")
	PIPE_WEIGHT+=("$2")
	PIPE_TITLE+=("$3")
	PIPE_STATE+=('pending')
	PIPE_SECONDS+=(0)
}

# pipeline_build   list the steps of the current plan.
pipeline_build() {
	local fsname schemename
	PIPE_ID=()
	PIPE_TITLE=()
	PIPE_WEIGHT=()
	PIPE_STATE=()
	PIPE_SECONDS=()
	plan_fs_name "${PLAN_FS:-}"
	fsname=$REPLY
	schemename=${PLAN_SCHEME^^}

	t pipe.prepare
	_pipe_add prepare 5 "$REPLY"
	if [[ $PLAN_MODE == dd ]]; then
		if ((OPT_BADBLOCKS > 0)); then t pipe.badblocks; _pipe_add badblocks 600 "$REPLY"; fi
		t pipe.write
		_pipe_add write 900 "$REPLY"
		if ((OPT_VERIFY)); then t pipe.verify; _pipe_add verify 300 "$REPLY"; fi
		t pipe.finalize
		_pipe_add finalize 15 "$REPLY"
		return 0
	fi

	t pipe.wipe
	_pipe_add wipe 5 "$REPLY"
	if ((OPT_BADBLOCKS > 0)); then t pipe.badblocks; _pipe_add badblocks 2000 "$REPLY"; fi
	t pipe.partition "$schemename"
	_pipe_add partition 10 "$REPLY"
	t pipe.format "$fsname"
	if ((OPT_QUICK)); then _pipe_add format 40 "$REPLY"; else _pipe_add format 900 "$REPLY"; fi
	if [[ $PLAN_MBR_KIND != none || $PLAN_PBR_KIND != none ]]; then
		t pipe.bootrec
		_pipe_add bootrec 5 "$REPLY"
	fi
	case $PLAN_MODE in
		freedos)
			t pipe.dosfiles
			_pipe_add dosfiles 20 "$REPLY"
			;;
		windows)
			t pipe.copy
			_pipe_add copy 900 "$REPLY"
			if ((PLAN_SPLIT_WIM)); then t pipe.split; _pipe_add split 700 "$REPLY"; fi
			t pipe.customize
			if ((PLAN_WUE_FLAGS != 0)); then _pipe_add customize 80 "$REPLY"; else t pipe.patch; _pipe_add customize 5 "$REPLY"; fi
			;;
		isocopy)
			t pipe.copy
			_pipe_add copy 900 "$REPLY"
			t pipe.patch
			_pipe_add patch 10 "$REPLY"
			;;
	esac
	if ((PLAN_EXTLABEL)); then
		t pipe.extlabel
		_pipe_add extlabel 3 "$REPLY"
	fi
	t pipe.finalize
	_pipe_add finalize 30 "$REPLY"
	return 0
}

# --- step implementations ---------------------------------------------------

_pipe_do_prepare() {
	dev_unmount_all "$TGT_PATH" || return $?
	dev_check_idle "$TGT_PATH" || return $?
	dev_lock "$TGT_PATH" || true
	if [[ $PLAN_MODE == windows || $PLAN_MODE == isocopy ]]; then
		img_mount || return $?
	fi
	return 0
}

_pipe_do_wipe() {
	part_wipe_disk "$TGT_PATH"
}

_pipe_do_badblocks() {
	local rc=0 bad
	extra_badblocks "$TGT_PATH" "$OPT_BADBLOCKS" || rc=$?
	bad=${REPLY:-0}
	((rc != 0)) && return "$rc"
	if is_uint "$bad" && ((bad > 0)); then
		fail_t pipe.err.badblocks "$bad"
		return 1
	fi
	# "Especially after destructive badblocks test, you must zero the MBR/GPT
	# completely" (format.c).  Raw images bring their own structures.
	if [[ $PLAN_MODE != dd ]]; then
		part_wipe_disk "$TGT_PATH" || return $?
	fi
	return 0
}

# Compute the partition table of the current plan -> PART_* (layout.sh).
_pipe_layout() {
	LAYOUT_DISK_BYTES=$TGT_SIZE
	LAYOUT_SECTOR=$TGT_SECTOR
	LAYOUT_SCHEME=$PLAN_SCHEME
	LAYOUT_FS=$PLAN_FS
	LAYOUT_CLUSTER=$PLAN_CLUSTER
	LAYOUT_BOOTABLE=$PLAN_BOOTABLE
	LAYOUT_UEFI_NTFS=$PLAN_UEFI_NTFS
	LAYOUT_OLD_BIOS=0
	if ((OPT_OLD_BIOS)) && [[ $PLAN_SCHEME == mbr && $PLAN_TARGET == bios ]]; then
		LAYOUT_OLD_BIOS=1
	fi
	layout_compute
}

# pipeline_layout_preview   -> REPLY: description of the table that would be
# written for the current plan (used by --dry-run).
pipeline_layout_preview() {
	_pipe_layout || return 1
	layout_describe
}

_pipe_do_partition() {
	local rc=0
	_pipe_layout || return $?
	layout_describe
	log "partition layout:"$'\n'"$REPLY"
	if [[ $PLAN_SCHEME == sfd ]]; then
		PIPE_MAIN_NODE=$TGT_PATH
		PIPE_MAIN_START=0
		return 0
	fi
	part_write_table "$TGT_PATH" || rc=$?
	if ((rc != 0)); then
		((rc == 130)) && return 130
		[[ -n $ERR_MSG ]] || fail_t pipe.err.partition
		return 1
	fi
	if ((PLAN_UEFI_NTFS)); then
		part_write_uefi_ntfs "$TGT_PATH" || return $?
	fi
	dev_flush "$TGT_PATH" || true
	dev_reread "$TGT_PATH" || return $?
	dev_wait_part "$TGT_PATH" $((PART_MAIN + 1)) || return $?
	PIPE_MAIN_NODE=$REPLY
	PIPE_MAIN_START=${PART_START[PART_MAIN]}
	log "main partition: $PIPE_MAIN_NODE (start sector $PIPE_MAIN_START)"
	return 0
}

_pipe_do_format() {
	fmt_make "$PLAN_FS" "$PIPE_MAIN_NODE" "$PLAN_FS_LABEL" "$PLAN_CLUSTER" "$PIPE_MAIN_START" "$OPT_QUICK" "$TGT_SIZE"
}

_pipe_do_bootrec() {
	case $PLAN_MBR_KIND in
		rufus | win7 | zero | gpt_msg)
			[[ $PLAN_SCHEME != sfd ]] && { boot_write_mbr "$TGT_PATH" "$PLAN_MBR_KIND" || return $?; }
			;;
	esac
	case $PLAN_PBR_KIND in
		bootmgr | freedos)
			# Before the first mount, so that the kernel never sees (or
			# rewrites) a half-updated boot sector.
			boot_write_pbr "$PIPE_MAIN_NODE" "$PLAN_FS" "$PLAN_PBR_KIND" || return $?
			;;
	esac
	return 0
}

_pipe_mount_media() {
	[[ -n $PIPE_MNT ]] && return 0
	core_mktemp_dir media || return 1
	local mnt=$REPLY
	fmt_mount "$PLAN_FS" "$PIPE_MAIN_NODE" "$mnt" || return $?
	PIPE_MNT=$mnt
	return 0
}

# Runs in a background subshell under job_track_write: copy, then push the
# data out to the drive, so that the progress bar covers the flush as well.
_pipe_copy_job() {
	local dst=$2 rc=0
	copy_tree "$@" || rc=$?
	((rc != 0)) && return "$rc"
	t pipe.flushing
	job_note "$REPLY"
	sync -f "$dst" 2>/dev/null || sync
	return 0
}

_pipe_do_copy() {
	local total rc=0
	local -a excl=()
	_pipe_mount_media || return $?
	if ((PLAN_SPLIT_WIM)) && [[ -n ${IMG_WININST_PATH:-} ]]; then
		excl=("$IMG_WININST_PATH")
	fi
	copy_total_bytes "$IMG_MOUNT" "${excl[@]}" || return $?
	total=$REPLY
	job_track_write "$total" _pipe_copy_job "$IMG_MOUNT" "$PIPE_MNT" "$PLAN_FS" "${excl[@]}" || rc=$?
	if ((rc != 0)); then
		((rc == 130)) && return 130
		[[ -n $ERR_MSG ]] || fail_t pipe.err.copy
		return 1
	fi
	return 0
}

_pipe_do_split() {
	local dir rel rc=0
	rel=${IMG_WININST_PATH%/*}
	[[ $rel == "$IMG_WININST_PATH" ]] && rel=''
	if [[ -n $rel ]]; then
		img_find_ci "$PIPE_MNT" "$rel" || {
			fail_t pipe.err.copy
			return 1
		}
		dir=$REPLY
	else
		dir=$PIPE_MNT
	fi
	win_split_wim "$IMG_MOUNT/$IMG_WININST_PATH" "$dir" || rc=$?
	((rc != 0)) && return "$rc"
	sync -f "$dir" 2>/dev/null || true
	return 0
}

_pipe_do_customize() {
	local rc=0
	WIN_MODIFIED=()
	if ((${IMG_HAS_WIN7_EFI:-0})) && [[ $PLAN_TARGET != bios ]]; then
		win_win7_efi_fix "$IMG_MOUNT" "$PIPE_MNT" || rc=$?
		((rc == 130)) && return 130
		rc=0
	fi
	if ((PLAN_WUE_FLAGS != 0)); then
		win_apply_customization "$PIPE_MNT" "$PLAN_WUE_FLAGS" || rc=$?
		if ((rc != 0)); then
			((rc == 130)) && return 130
			[[ -n $ERR_MSG ]] || fail_t pipe.err.patch
			return 1
		fi
	fi
	if [[ -n ${IMG_MD5SUM_FILE:-} ]] && ((${#WIN_MODIFIED[@]} > 0)); then
		copy_update_md5sums "$PIPE_MNT" "$IMG_MD5SUM_FILE" "${WIN_MODIFIED[@]}" || true
	fi
	return 0
}

# File-copy mode for non-Windows images: make sure a UEFI loader is in place
# and adapt boot configurations to the label the file system really got.
_pipe_do_patch() {
	local rc=0 efidir found=0 f
	COPY_MODIFIED=()
	if img_find_ci "$PIPE_MNT" 'efi/boot'; then
		efidir=$REPLY
		for f in "$efidir"/*; do
			case ${f,,} in
				*/boot*.efi | */grub*.efi)
					found=1
					break
					;;
			esac
		done
	fi
	if ((!found)); then
		# Some images only carry their UEFI loader inside a FAT image.
		if [[ -n ${IMG_EFI_IMG_PATH:-} ]]; then
			copy_efi_img_merge "$IMG_MOUNT/$IMG_EFI_IMG_PATH" "$PIPE_MNT" || rc=$?
			((rc == 130)) && return 130
		else
			rc=1
		fi
		if ((rc != 0)); then
			fail_t pipe.err.no_efi
			return 1
		fi
	fi
	fmt_read_label "$PLAN_FS" "$PIPE_MAIN_NODE" || REPLY=$PLAN_FS_LABEL
	PIPE_USB_LABEL=${REPLY:-$PLAN_FS_LABEL}
	if [[ -n ${IMG_LABEL:-} && $IMG_LABEL != "$PIPE_USB_LABEL" ]]; then
		copy_patch_configs "$PIPE_MNT" "$IMG_LABEL" "$PIPE_USB_LABEL" || rc=$?
		if ((rc != 0)); then
			((rc == 130)) && return 130
			[[ -n $ERR_MSG ]] || fail_t pipe.err.patch
			return 1
		fi
	fi
	if [[ -n ${IMG_MD5SUM_FILE:-} ]] && ((${#COPY_MODIFIED[@]} > 0)); then
		copy_update_md5sums "$PIPE_MNT" "$IMG_MD5SUM_FILE" "${COPY_MODIFIED[@]}" || true
	fi
	return 0
}

_pipe_do_dosfiles() {
	_pipe_mount_media || return $?
	dos_install "$PIPE_MNT"
}

_pipe_do_extlabel() {
	_pipe_mount_media || return $?
	# Cosmetic: a failure here must not ruin an otherwise good drive.
	extra_write_autorun "$PIPE_MNT" "$PLAN_LABEL" || log "could not write autorun.inf"
	return 0
}

_pipe_do_write() {
	dd_plan_image || return $?
	dd_check_fits || return $?
	dd_write_image "$TGT_PATH"
}

_pipe_do_verify() {
	dd_verify_image "$TGT_PATH"
}

_pipe_flush_job() {
	sync -f "$1" 2>/dev/null || sync
}

# Unmount what the job mounted.  Runs in every outcome.
_pipe_release_media() {
	local rc=0
	if [[ -n $PIPE_MNT ]]; then
		# The unmount can take as long as the remaining write-back, so keep
		# the interface alive while it runs; then let the format module do
		# its own bookkeeping in this shell (nothing is mounted any more).
		job_spin fmt_unmount "$PIPE_MNT" || rc=$?
		if core_is_mountpoint "$PIPE_MNT"; then
			rc=0
			fmt_unmount "$PIPE_MNT" || rc=$?
		fi
		PIPE_MNT=''
	fi
	return "$rc"
}

_pipe_do_finalize() {
	local rc=0
	if [[ -n $PIPE_MNT ]]; then
		t pipe.flushing
		job_note "$REPLY"
		job_spin _pipe_flush_job "$PIPE_MNT" || rc=$?
		((rc == 130)) && return 130
		_pipe_release_media || return $?
	fi
	if [[ $PLAN_MODE != dd && $PLAN_FS == fat32 && $PLAN_PBR_KIND != none ]]; then
		boot_fix_fsinfo "$PIPE_MAIN_NODE" || true
	fi
	job_spin dev_flush "$TGT_PATH" || rc=$?
	((rc == 130)) && return 130
	if [[ $PLAN_MODE != dd && $PLAN_MODE != format && $PLAN_MODE != freedos ]]; then
		img_unmount || true
	fi
	dev_unlock || true
	# Let the kernel (and udev) discover what is on the drive now.
	dev_reread "$TGT_PATH" || true
	return 0
}

# Values the unattend generator needs: taken from this machine, then
# overridden by what the user asked for explicitly.
_pipe_setup_wue() {
	win_host_locale_defaults || true
	if [[ -n ${OPT_WUE_USER:-} ]]; then WUE_USERNAME=$OPT_WUE_USER; fi
	if [[ -n ${OPT_WUE_LOCALE:-} ]]; then
		WUE_SYSTEM_LOCALE=$OPT_WUE_LOCALE
		WUE_USER_LOCALE=$OPT_WUE_LOCALE
		WUE_UI_LANGUAGE=$OPT_WUE_LOCALE
	fi
	if [[ -n ${OPT_WUE_TIMEZONE:-} ]]; then WUE_TIMEZONE=$OPT_WUE_TIMEZONE; fi
	if [[ -n ${OPT_WUE_KEYBOARD:-} ]]; then WUE_INPUT_LOCALE=$OPT_WUE_KEYBOARD; fi
	return 0
}

# --- runner -----------------------------------------------------------------

_pipe_set_state() {
	PIPE_STATE[$1]=$2
	if [[ -n $PIPE_HOOK ]]; then
		"$PIPE_HOOK" "$1" "$2"
	fi
	return 0
}

# Best-effort release of everything after a failure or a cancellation.
_pipe_abort_cleanup() {
	local was_cancelled=$RC_CANCELLED
	# The cleanup itself must not be refused by the runners.
	RC_CANCELLED=0
	t pipe.finalize
	job_phase "$REPLY"
	_pipe_release_media || true
	img_unmount 2>/dev/null || true
	dev_flush "$TGT_PATH" || true
	dev_unlock || true
	RC_CANCELLED=$was_cancelled
	return 0
}

# pipeline_run   execute the plan.  Returns 0 (done), 130 (cancelled) or 1
# (failed, ERR_MSG says why).  PIPE_RESULT / PIPE_ELAPSED are set either way.
pipeline_run() {
	local i n total=0 base=0 span rc=0 t0 t1
	PIPE_RESULT=''
	PIPE_MAIN_NODE=''
	PIPE_MAIN_START=0
	PIPE_MNT=''
	PIPE_USB_LABEL=''
	ERR_MSG=''
	RC_CANCELLED=0
	RC_JOB_ACTIVE=1
	job_reset
	pipeline_build
	if ((${PLAN_WUE_FLAGS:-0} != 0)); then
		_pipe_setup_wue
	fi
	n=${#PIPE_ID[@]}
	for ((i = 0; i < n; i++)); do
		total=$((total + PIPE_WEIGHT[i]))
	done
	((total > 0)) || total=1
	log "plan: mode=$PLAN_MODE scheme=${PLAN_SCHEME:-} target=${PLAN_TARGET:-} fs=${PLAN_FS:-} cluster=${PLAN_CLUSTER:-0} label='${PLAN_FS_LABEL:-}' device=$TGT_PATH"

	for ((i = 0; i < n; i++)); do
		if ((RC_CANCELLED)); then
			rc=130
			break
		fi
		span=$((PIPE_WEIGHT[i] * 1000 / total))
		job_step $((base * 1000 / total)) "$span"
		now_s
		t0=$REPLY
		_pipe_set_state "$i" running
		job_phase "${PIPE_TITLE[i]}"
		rc=0
		"_pipe_do_${PIPE_ID[i]}" || rc=$?
		now_s
		t1=$REPLY
		PIPE_SECONDS[i]=$((t1 - t0))
		if ((rc == 0)); then
			_pipe_set_state "$i" 'done'
		elif ((rc == 130)) || ((RC_CANCELLED)); then
			rc=130
			_pipe_set_state "$i" cancelled
			break
		else
			rc=1
			_pipe_set_state "$i" failed
			break
		fi
		base=$((base + PIPE_WEIGHT[i]))
	done

	if ((rc == 0)); then
		JOB_OVERALL=1000
		JOB_PCT=1000
		PIPE_RESULT='ok'
	else
		local saved=$ERR_MSG
		_pipe_abort_cleanup
		ERR_MSG=$saved
		if ((rc == 130)); then
			PIPE_RESULT='cancelled'
			t pipe.cancelled
			ERR_MSG=$REPLY
		else
			PIPE_RESULT='failed'
			if [[ -z $ERR_MSG ]]; then
				t pipe.err.generic
				ERR_MSG=$REPLY
			fi
		fi
	fi
	now_s
	PIPE_ELAPSED=$((REPLY - JOB_STARTED_S))
	RC_JOB_ACTIVE=0
	log "result: $PIPE_RESULT after ${PIPE_ELAPSED}s${ERR_MSG:+ - $ERR_MSG}"
	job_refresh
	return "$rc"
}

# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# rufus-cli - the decision logic: turns what the user asked for (OPT_*), the
# selected drive (TGT_*) and the scanned image (IMG_*) into one concrete,
# validated plan (PLAN_*), applying the same defaults and restrictions as the
# Rufus dialog (src/rufus.c: SetPartitionSchemeAndTargetSystem, SetFSFromISO,
# SetFileSystemAndClusterSize, BootCheckThread).
#
# Deliberate differences from upstream:
#  * ISOHybrid images default to DD mode.  File-copy mode exists for UEFI
#    targets only, because this port does not install Syslinux/GRUB for BIOS.
#  * A Windows image whose install.wim exceeds 4 GiB may be written to FAT32
#    on request (the WIM is then split); upstream hides that behind Alt-E.
#  * "BIOS or UEFI" for Windows media (upstream's Alt-E dual mode) is a
#    regular choice of the target system.

[[ -n ${_RC_PLAN_LOADED:-} ]] && return 0
_RC_PLAN_LOADED=1

# Labels (official Rufus wording where one exists).
msg_def plan.boot.none 'Non bootable' '非ブート用'
msg_def plan.boot.image 'Disk or ISO image' 'ディスクまたは ISO イメージ'
msg_def plan.boot.image_select 'Disk or ISO image (Please select)' 'ディスクまたは ISO イメージ (選択してください)'
msg_def plan.boot.freedos 'FreeDOS' 'FreeDOS'
msg_def plan.scheme.mbr 'MBR' 'MBR'
msg_def plan.scheme.gpt 'GPT' 'GPT'
msg_def plan.scheme.sfd 'Super Floppy Disk' 'スーパー フロッピー ディスク'
msg_def plan.target.bios 'BIOS (or UEFI-CSM)' 'BIOS (または UEFI-CSM)'
msg_def plan.target.uefi 'UEFI (non CSM)' 'UEFI (CSM 無効)'
msg_def plan.target.dual 'BIOS or UEFI' 'BIOS または UEFI'
msg_def plan.target.none 'BIOS or UEFI' 'BIOS または UEFI'
msg_def plan.mode.iso 'ISO Image mode (file copy)' 'ISO イメージ モード (ファイル コピー)'
msg_def plan.mode.dd 'DD Image mode (raw write)' 'DD イメージ モード (そのまま書き込み)'
msg_def plan.mode.windows 'Standard Windows installation' '標準の Windows インストール'
msg_def plan.default_suffix '%s (Default)' '%s (既定)'
msg_def plan.cluster.default 'Default' '既定'
msg_def plan.cluster.bytes '%d bytes' '%d バイト'
msg_def plan.cluster.kb '%d kilobytes' '%d キロバイト'
msg_def plan.cluster.mb '%d megabytes' '%d メガバイト'
msg_def plan.fs.split_note 'install.wim will be split' 'install.wim を分割します'
msg_def plan.fs.uefi_ntfs_note 'with UEFI:NTFS' 'UEFI:NTFS を使用'

# Errors.
msg_def plan.no_device 'No device selected' 'デバイスが選択されていません。'
msg_def plan.no_image 'No image selected' 'イメージが選択されていません。'
msg_def plan.no_boot 'Nothing to do: choose an image (--image), FreeDOS (--boot freedos) or a plain format (--boot none)' \
	'実行内容が指定されていません。イメージ (--image)、FreeDOS (--boot freedos)、フォーマットのみ (--boot none) のいずれかを指定してください。'
msg_def plan.bare_wim 'Bare .wim/.esd images are not supported; please use a Windows ISO' \
	'.wim/.esd ファイル単体には対応していません。Windows の ISO を使用してください。'
msg_def plan.not_bootable 'This image is either non-bootable, or it uses a boot or compression method that is not supported. Use DD mode (--mode dd) to write it as is.' \
	'このイメージはブート非対応、あるいはサポートされていないブート方式・圧縮方式を使用しています。そのまま書き込む場合は DD モード (--mode dd) を指定してください。'
msg_def plan.not_hybrid 'This ISO is not an ISOHybrid image: it cannot be written in DD mode' \
	'この ISO はハイブリッド ISO ではないため、DD モードでは書き込めません。'
msg_def plan.force_dd 'This image was not made compatible with ISO/File copy mode by its creators: DD image mode must be used' \
	'このイメージは ISO (ファイル コピー) モードに対応していないため、DD イメージ モードで書き込む必要があります。'
msg_def plan.bios_iso_unsupported 'This ISO can only boot in BIOS mode from a file copy, which rufus-cli does not support. It cannot be written.' \
	'この ISO はファイル コピーでは BIOS モードでしか起動できず、rufus-cli では対応していません。'
msg_def plan.iso_needs_uefi 'ISO Image (file copy) mode only supports UEFI targets for this image. Use DD mode for BIOS boot.' \
	'このイメージの ISO (ファイル コピー) モードは UEFI ターゲットのみ対応です。BIOS で起動する場合は DD モードを使用してください。'
msg_def plan.need_efi 'When using UEFI Target Type, only EFI bootable ISO images are supported. Please select an EFI bootable ISO or set the Target Type to BIOS.' \
	'UEFI ターゲット タイプを使用する場合、EFI でブート可能な ISO だけがサポートされています。EFI でブート可能な ISO を選択するか、ターゲット タイプを BIOS に設定し直してください。'
msg_def plan.need_bootmgr 'This image cannot boot in BIOS mode (no BIOS bootmgr): use the UEFI target' \
	'このイメージは BIOS モードで起動できません (BIOS 用 bootmgr がありません)。UEFI ターゲットを使用してください。'
msg_def plan.bad_combo 'The combination "%s" + "%s" is not possible for this boot selection' \
	'このブートの種類では "%s" と "%s" の組み合わせは使用できません。'
msg_def plan.bad_scheme 'Partition scheme "%s" is not available for this boot selection' \
	'このブートの種類ではパーティション構成 "%s" は使用できません。'
msg_def plan.bad_fs 'The file system currently selected can not be used with this type of ISO. Please select a different file system or use a different ISO.' \
	'現在選択されているファイル システムではこの ISO を使用することができません。別のファイル システムか別の ISO を使用してください。'
msg_def plan.fs_unsupported 'Cannot use the selected file system for this media.' '選択したファイル システムはこのメディアに使えません。'
msg_def plan.fs_win_bios 'Windows media for a BIOS target must use NTFS (choose the "BIOS or UEFI" target to use FAT32)' \
	'BIOS ターゲット用の Windows メディアは NTFS である必要があります (FAT32 を使う場合はターゲットに「BIOS または UEFI」を選択してください)。'
msg_def plan.file_4gb 'This ISO image contains a file larger than 4 GB, which is more than the maximum size allowed for a FAT or FAT32 file system.' \
	'ISO イメージに 4 GB より大きなファイルがあります。FAT、FAT32 ファイル システムで使用可能な最大のサイズを超えています。'
msg_def plan.split_unavailable 'install.wim is larger than 4 GB and splitting it for FAT32 requires wimlib-imagex, which is not available for this distribution. Use NTFS instead.' \
	'install.wim が 4 GB を超えています。FAT32 用に分割するには wimlib-imagex が必要ですが、このディストリビューションでは利用できません。NTFS を使用してください。'
msg_def plan.too_big 'The image is too big for the selected target.' 'イメージが選択したターゲットには大きすぎます。'
msg_def plan.too_small 'The device is too small (8 MB minimum)' 'デバイスが小さすぎます (最小 8 MB)。'
msg_def plan.bad_cluster 'The selected cluster size is not valid for this device.' '選択されたクラスター サイズはこのデバイスには無効です。'
msg_def plan.freedos_scheme 'FreeDOS requires the MBR partition scheme and a BIOS target' \
	'FreeDOS には MBR パーティション構成と BIOS ターゲットが必要です。'
msg_def plan.freedos_fs 'FreeDOS requires FAT or FAT32' 'FreeDOS には FAT または FAT32 が必要です。'
msg_def plan.image_on_target 'The image is located on the target drive' 'イメージ ファイルが書き込み先のドライブ上にあります。'
msg_def plan.sector_bios 'BIOS boot code requires a drive with 512-byte sectors (this one uses %d)' \
	'BIOS 用ブート コードには 512 バイト セクターのドライブが必要です (このドライブは %d バイト)。'

# Warnings / notes.
msg_def plan.warn.mbr_2tb 'Because MBR has been selected for the partition scheme, only a partition up to 2 TB can be created on this media, which will leave %s of disk space unavailable.' \
	'パーティション構成に MBR が選択されているため、このメディア上には最大 2 TB のパーティションしか作成できません。%s のディスク容量が使用できなくなります。'
msg_def plan.warn.sector 'This drive uses a nonstandard sector size (%d bytes). In many cases you will NOT be able to boot from it.' \
	'このドライブは標準以外のセクター サイズ (%d バイト) を使用しています。多くの場合、このドライブからは起動できません。'
msg_def plan.warn.wue_ignored 'Windows customization options do not apply to this image and were ignored' \
	'Windows のカスタマイズ オプションはこのイメージには適用できないため無視されました。'
msg_def plan.warn.no_bootmark 'The image has no boot marker; it is written as is' \
	'イメージにブート マーカーがありません。そのまま書き込みます。'
msg_def plan.warn.unscanned 'The image could not be scanned without root privileges; settings are provisional' \
	'root 権限がないためイメージをスキャンできませんでした。設定は暫定的なものです。'
msg_def plan.warn.uefi_ntfs_sb 'This media uses the UEFI:NTFS bootloader. On some PCs it only starts once the "Microsoft 3rd party UEFI CA" is trusted in the Secure Boot settings.' \
	'このメディアは UEFI:NTFS ブートローダーを使用します。一部の PC ではセキュア ブート設定で「Microsoft 3rd party UEFI CA」を信頼する必要があります。'

# Summary labels.
msg_def plan.sum.device 'Device' 'デバイス'
msg_def plan.sum.boot 'Boot selection' 'ブートの種類'
msg_def plan.sum.mode 'Image option' 'イメージ オプション'
msg_def plan.sum.scheme 'Partition scheme' 'パーティション構成'
msg_def plan.sum.target 'Target system' 'ターゲット システム'
msg_def plan.sum.label 'Volume label' 'ボリューム ラベル'
msg_def plan.sum.fs 'File system' 'ファイル システム'
msg_def plan.sum.cluster 'Cluster size' 'クラスター サイズ'
msg_def plan.sum.options 'Options' 'オプション'
msg_def plan.sum.wue 'Customization' 'カスタマイズ'
msg_def plan.opt.quick 'quick format' 'クイック フォーマット'
msg_def plan.opt.full 'full format' '完全フォーマット'
msg_def plan.opt.extlabel 'extended label and icon' '拡張ラベルとアイコン'
msg_def plan.opt.badblocks 'bad blocks check' '不良ブロック検出'
msg_def plan.opt.verify 'verify after writing' '書き込み後に検証'
msg_def plan.opt.oldbios 'old BIOS fixes' '古い BIOS 向けの修正'

# --- options ----------------------------------------------------------------

plan_defaults() {
	OPT_DEVICE=''		# device path or image file given on the command line
	OPT_SIZE=''		# size for a newly created image-file target
	OPT_BOOT=''		# none | image | freedos ('' = not chosen yet)
	OPT_IMAGE=''
	OPT_MODE='auto'		# auto | iso | dd
	OPT_SCHEME='auto'	# auto | mbr | gpt | sfd
	OPT_TARGET='auto'	# auto | bios | uefi | dual
	OPT_FS='auto'		# auto | fat16 | fat32 | ntfs | exfat | udf | ext2 | ext3 | ext4
	OPT_CLUSTER=0		# bytes, 0 = default
	OPT_LABEL=''
	OPT_LABEL_SET=0		# 1 when the user chose a label (possibly an empty one)
	OPT_QUICK=1
	OPT_BADBLOCKS=0		# 0 off, 1..5 = 1 pass, 2 passes, 4 passes SLC/MLC/TLC
	OPT_EXTLABEL=1
	OPT_OLD_BIOS=0
	OPT_VERIFY=0
	OPT_LIST_HDD=0
	OPT_ALLOW_FIXED=0
	OPT_WUE_FLAGS=0
	OPT_WUE_USER=''
	OPT_WUE_LOCALE=''
	OPT_WUE_TIMEZONE=''
	OPT_WUE_KEYBOARD=''
	OPT_YES=0
	OPT_DRY_RUN=0
	OPT_INSTALL_DEPS=0
	OPT_LANG=${OPT_LANG:-}
	plan_clear
}

plan_clear() {
	PLAN_READY=0		# 1 when the plan is complete and valid
	PLAN_ERROR=''		# why it is not (localized)
	PLAN_ERROR_KEY=''	# catalogue key of that reason
	PLAN_MODE=''		# format | freedos | windows | isocopy | dd
	PLAN_SCHEME=''		# mbr | gpt | sfd | ''
	PLAN_TARGET=''		# bios | uefi | dual | none | ''
	PLAN_FS=''
	PLAN_CLUSTER=0
	PLAN_CLUSTER_DEFAULT=0
	PLAN_LABEL=''
	PLAN_FS_LABEL=''
	PLAN_UEFI_NTFS=0
	PLAN_SPLIT_WIM=0
	PLAN_BOOTABLE=0
	PLAN_MBR_KIND='none'	# rufus | zero | gpt_msg | none
	PLAN_PBR_KIND='none'	# bootmgr | freedos | none
	PLAN_WUE_FLAGS=0
	PLAN_EXTLABEL=0
	PLAN_WARNINGS=()
	PLAN_SCHEMES=()		# values the scheme field may take
	PLAN_TARGETS=()
	PLAN_FILESYSTEMS=()
	PLAN_MODES=()
	PLAN_CMDS=()
	PLAN_CMDS_OPTIONAL=()
}

declare -a PLAN_WARNINGS=() PLAN_SCHEMES=() PLAN_TARGETS=() PLAN_FILESYSTEMS=() PLAN_MODES=()
declare -a PLAN_CMDS=() PLAN_CMDS_OPTIONAL=() PLAN_SUM_LABEL=() PLAN_SUM_VALUE=() FMT_CLUSTERS=()

_plan_fail() {
	PLAN_ERROR_KEY=$1
	t "$@"
	PLAN_ERROR=$REPLY
	PLAN_READY=0
	return 1
}

_plan_warn() {
	t "$@"
	PLAN_WARNINGS+=("$REPLY")
}

# --- display names ----------------------------------------------------------

# plan_fs_name FS   -> REPLY (the name Rufus shows)
plan_fs_name() {
	case $1 in
		fat16) REPLY='FAT' ;;
		fat32) REPLY='FAT32' ;;
		ntfs) REPLY='NTFS' ;;
		exfat) REPLY='exFAT' ;;
		udf) REPLY='UDF' ;;
		ext2 | ext3 | ext4) REPLY=$1 ;;
		*) REPLY=$1 ;;
	esac
}

# plan_cluster_name BYTES   -> REPLY ("4096 bytes", "16 kilobytes", "Default")
plan_cluster_name() {
	local b=$1
	if ((b <= 0)); then
		t plan.cluster.default
	elif ((b < 16384)); then
		t plan.cluster.bytes "$b"
	elif ((b < 16777216)); then
		t plan.cluster.kb $((b / 1024))
	else
		t plan.cluster.mb $((b / 1048576))
	fi
}

plan_scheme_name() { t "plan.scheme.$1"; }
plan_target_name() { t "plan.target.$1"; }

# --- mode -------------------------------------------------------------------

# Decide what kind of job this is.  Sets PLAN_MODE and PLAN_MODES.
_plan_mode() {
	PLAN_MODES=()
	case $OPT_BOOT in
		none)
			PLAN_MODE='format'
			return 0
			;;
		freedos)
			PLAN_MODE='freedos'
			return 0
			;;
		image) ;;
		*)
			_plan_fail plan.no_boot
			return 1
			;;
	esac
	if [[ -z ${IMG_PATH:-} ]]; then
		_plan_fail plan.no_image
		return 1
	fi
	if ((${IMG_IS_WIM:-0})); then
		_plan_fail plan.bare_wim
		return 1
	fi
	if ((!${IMG_IS_ISO:-0})); then
		# A disk image: raw write is the only possibility.
		PLAN_MODES=(dd)
		if ((!${IMG_IS_BOOTABLE_DISK:-0})); then
			if [[ $OPT_MODE != dd ]]; then
				_plan_fail plan.not_bootable
				return 1
			fi
			_plan_warn plan.warn.no_bootmark
		fi
		if [[ $OPT_MODE == iso ]]; then
			_plan_fail plan.not_bootable
			return 1
		fi
		PLAN_MODE='dd'
		return 0
	fi
	# An ISO.
	local hybrid=${IMG_IS_BOOTABLE_DISK:-0} is_win=${IMG_IS_WINDOWS:-0} has_efi=${IMG_HAS_EFI:-0}
	local can_copy=0 can_dd=$hybrid
	if ((is_win)); then
		can_copy=1
	elif ((has_efi)) && ((!${IMG_FORCE_DD:-0})); then
		can_copy=1
	fi
	if ((!${IMG_SCANNED:-0})); then
		# Without a directory scan we only know what the headers say.
		can_copy=0
	fi
	((can_copy)) && PLAN_MODES+=(iso)
	((can_dd)) && PLAN_MODES+=(dd)
	case $OPT_MODE in
		dd)
			if ((!can_dd)); then
				_plan_fail plan.not_hybrid
				return 1
			fi
			PLAN_MODE='dd'
			;;
		iso)
			if ((!can_copy)); then
				if ((${IMG_FORCE_DD:-0})); then
					_plan_fail plan.force_dd
				elif ((!${IMG_SCANNED:-0})); then
					_plan_fail plan.warn.unscanned
				else
					_plan_fail plan.bios_iso_unsupported
				fi
				return 1
			fi
			if ((is_win)); then PLAN_MODE='windows'; else PLAN_MODE='isocopy'; fi
			;;
		*)
			if ((is_win && can_copy)); then
				PLAN_MODE='windows'
			elif ((can_dd)); then
				PLAN_MODE='dd'
			elif ((can_copy)); then
				PLAN_MODE='isocopy'
			elif ((!${IMG_SCANNED:-0})); then
				_plan_fail plan.warn.unscanned
				return 1
			else
				_plan_fail plan.bios_iso_unsupported
				return 1
			fi
			;;
	esac
	return 0
}

# --- scheme and target ------------------------------------------------------

# Candidate (scheme, target) pairs for the mode, best first -> _PLAN_PAIRS[]
_plan_pairs() {
	_PLAN_PAIRS=()
	local efi=${IMG_HAS_EFI:-0} bootmgr=${IMG_HAS_BOOTMGR:-0}
	case $PLAN_MODE in
		format)
			# Rufus: MBR by default, GPT beyond 2 TB.
			if ((${TGT_SIZE:-0} > 2199023255552)); then
				_PLAN_PAIRS=(gpt:none mbr:none sfd:none)
			else
				_PLAN_PAIRS=(mbr:none gpt:none sfd:none)
			fi
			;;
		freedos) _PLAN_PAIRS=(mbr:bios) ;;
		windows)
			((efi)) && _PLAN_PAIRS+=(gpt:uefi)
			((bootmgr)) && _PLAN_PAIRS+=(mbr:bios)
			((efi && bootmgr)) && _PLAN_PAIRS+=(mbr:dual)
			((efi && !bootmgr)) && _PLAN_PAIRS+=(mbr:uefi)
			;;
		isocopy) _PLAN_PAIRS=(gpt:uefi mbr:uefi) ;;
	esac
	return 0
}

_plan_scheme_target() {
	local pair s tg found=0
	local -a _PLAN_PAIRS=()
	PLAN_SCHEMES=()
	PLAN_TARGETS=()
	_plan_pairs
	if ((${#_PLAN_PAIRS[@]} == 0)); then
		_plan_fail plan.need_efi
		return 1
	fi
	# What the scheme field may show.
	for pair in "${_PLAN_PAIRS[@]}"; do
		s=${pair%%:*}
		in_list "$s" "${PLAN_SCHEMES[@]}" || PLAN_SCHEMES+=("$s")
	done
	# First pair compatible with what was explicitly requested.
	for pair in "${_PLAN_PAIRS[@]}"; do
		s=${pair%%:*}
		tg=${pair##*:}
		[[ $OPT_SCHEME == auto || $OPT_SCHEME == "$s" ]] || continue
		[[ $OPT_TARGET == auto || $OPT_TARGET == "$tg" || $tg == none ]] || continue
		PLAN_SCHEME=$s
		PLAN_TARGET=$tg
		found=1
		break
	done
	if ((!found)); then
		if [[ $OPT_SCHEME != auto ]] && ! in_list "$OPT_SCHEME" "${PLAN_SCHEMES[@]}"; then
			if [[ $PLAN_MODE == freedos ]]; then
				_plan_fail plan.freedos_scheme
			else
				plan_scheme_name "$OPT_SCHEME"
				_plan_fail plan.bad_scheme "$REPLY"
			fi
		elif [[ $PLAN_MODE == freedos ]]; then
			_plan_fail plan.freedos_scheme
		elif [[ $PLAN_MODE == isocopy ]]; then
			_plan_fail plan.iso_needs_uefi
		elif [[ $OPT_TARGET == uefi ]] && ((!${IMG_HAS_EFI:-0})); then
			_plan_fail plan.need_efi
		elif [[ $OPT_TARGET == bios || $OPT_TARGET == dual ]] && ((!${IMG_HAS_BOOTMGR:-0})); then
			_plan_fail plan.need_bootmgr
		else
			local sn tn
			if [[ $OPT_SCHEME == auto ]]; then sn='auto'; else plan_scheme_name "$OPT_SCHEME"; sn=$REPLY; fi
			if [[ $OPT_TARGET == auto ]]; then tn='auto'; else plan_target_name "$OPT_TARGET"; tn=$REPLY; fi
			_plan_fail plan.bad_combo "$sn" "$tn"
		fi
		return 1
	fi
	# Targets available for the chosen scheme.
	for pair in "${_PLAN_PAIRS[@]}"; do
		[[ ${pair%%:*} == "$PLAN_SCHEME" ]] && PLAN_TARGETS+=("${pair##*:}")
	done
	return 0
}

# --- file system ------------------------------------------------------------

_plan_filesystems() {
	local fs size=${TGT_SIZE:-0} big=${IMG_4GB_FILES:-0}
	local -a cand=()
	PLAN_FILESYSTEMS=()
	case $PLAN_MODE in
		format) cand=(fat16 fat32 ntfs udf exfat ext2 ext3 ext4) ;;
		freedos) cand=(fat16 fat32) ;;
		windows)
			case $PLAN_TARGET in
				bios) cand=(ntfs) ;;
				*) cand=(fat32 ntfs) ;;
			esac
			;;
		isocopy) cand=(fat32) ;;
	esac
	for fs in "${cand[@]}"; do
		if ((size > 0)) && ! fmt_fs_supported "$fs" "$size"; then
			continue
		fi
		PLAN_FILESYSTEMS+=("$fs")
	done
	if ((${#PLAN_FILESYSTEMS[@]} == 0)); then
		_plan_fail plan.fs_unsupported
		return 1
	fi

	if [[ $OPT_FS != auto ]]; then
		if ! in_list "$OPT_FS" "${PLAN_FILESYSTEMS[@]}"; then
			case $PLAN_MODE in
				windows)
					if [[ $PLAN_TARGET == bios && ($OPT_FS == fat32 || $OPT_FS == fat16) ]]; then
						_plan_fail plan.fs_win_bios
					else
						_plan_fail plan.bad_fs
					fi
					;;
				freedos) _plan_fail plan.freedos_fs ;;
				isocopy) _plan_fail plan.bad_fs ;;
				*) _plan_fail plan.fs_unsupported ;;
			esac
			return 1
		fi
		PLAN_FS=$OPT_FS
	else
		case $PLAN_MODE in
			windows)
				# Rufus: FAT32 unless a file is too large for it, then NTFS.
				if ((big == 0)) && in_list fat32 "${PLAN_FILESYSTEMS[@]}"; then
					PLAN_FS='fat32'
				elif in_list ntfs "${PLAN_FILESYSTEMS[@]}"; then
					PLAN_FS='ntfs'
				else
					PLAN_FS=${PLAN_FILESYSTEMS[0]}
				fi
				;;
			*)
				# First available file system: FAT below 4 GB, FAT32 up to
				# 2 TB, NTFS beyond - the order of the candidate list.
				PLAN_FS=${PLAN_FILESYSTEMS[0]}
				;;
		esac
	fi

	# Files of 4 GiB and more cannot live on FAT.
	if [[ $PLAN_FS == fat32 || $PLAN_FS == fat16 ]] && ((big > 0)) && [[ $PLAN_MODE == windows || $PLAN_MODE == isocopy ]]; then
		if [[ $PLAN_MODE == windows ]] && ((${IMG_4GB_ONLY_WIM:-0})); then
			deps_pkg_for wimlib-imagex
			if ! have wimlib-imagex && [[ -z $REPLY ]]; then
				_plan_fail plan.split_unavailable
				return 1
			fi
			PLAN_SPLIT_WIM=1
		else
			_plan_fail plan.file_4gb
			return 1
		fi
	fi
	return 0
}

_plan_cluster() {
	local size=${TGT_SIZE:-0} sector=${TGT_SECTOR:-512}
	FMT_CLUSTERS=()
	PLAN_CLUSTER_DEFAULT=0
	if ((size > 0)); then
		fmt_cluster_choices "$PLAN_FS" "$size" "$sector" || true
		PLAN_CLUSTER_DEFAULT=${REPLY:-0}
		is_uint "$PLAN_CLUSTER_DEFAULT" || PLAN_CLUSTER_DEFAULT=0
	fi
	if ((OPT_CLUSTER > 0)); then
		if ((${#FMT_CLUSTERS[@]} > 0)) && ! in_list "$OPT_CLUSTER" "${FMT_CLUSTERS[@]}"; then
			_plan_fail plan.bad_cluster
			return 1
		fi
		PLAN_CLUSTER=$OPT_CLUSTER
	else
		PLAN_CLUSTER=$PLAN_CLUSTER_DEFAULT
	fi
	return 0
}

_plan_label() {
	local label=''
	if ((OPT_LABEL_SET)); then
		label=$OPT_LABEL
	else
		case $PLAN_MODE in
			windows | isocopy) label=${IMG_LABEL:-} ;;
			*)
				label=${TGT_LABEL:-}
				if [[ -z $label ]] && ((${TGT_SIZE:-0} > 0)); then
					fmt_size_label "$TGT_SIZE"
					label=$REPLY
				fi
				;;
		esac
	fi
	PLAN_LABEL=$label
	fmt_label_sanitize "$PLAN_FS" "$label" "${TGT_SIZE:-0}"
	PLAN_FS_LABEL=$REPLY
	return 0
}

# --- the resolver -----------------------------------------------------------

# plan_resolve   compute PLAN_* from OPT_*, TGT_* and IMG_*.
# Returns 0 when the plan is complete (PLAN_READY=1), else 1 with PLAN_ERROR.
# Everything that could be determined is set either way, so that the
# interface can show partial settings.
plan_resolve() {
	local size=${TGT_SIZE:-0} sector=${TGT_SECTOR:-512} limit
	plan_clear
	_plan_mode || return 1

	if [[ $PLAN_MODE == dd ]]; then
		if ((size > 0)); then
			limit=${IMG_UNCOMPRESSED_SIZE:-0}
			if [[ ${IMG_COMPRESSION:-none} == none ]]; then
				limit=${IMG_SIZE:-0}
			fi
			# Rufus tolerates a few KB of excess.
			if ((limit > size + 4096)); then
				_plan_fail plan.too_big
				return 1
			fi
		fi
	else
		_plan_scheme_target || return 1
		_plan_filesystems || return 1
		_plan_cluster || return 1
		_plan_label

		case $PLAN_MODE in
			format)
				PLAN_BOOTABLE=0
				[[ $PLAN_SCHEME == mbr ]] && PLAN_MBR_KIND='zero'
				;;
			freedos)
				PLAN_BOOTABLE=1
				PLAN_MBR_KIND='rufus'
				PLAN_PBR_KIND='freedos'
				;;
			windows)
				PLAN_BOOTABLE=1
				case $PLAN_SCHEME:$PLAN_TARGET in
					gpt:*) PLAN_MBR_KIND='gpt_msg' ;;
					mbr:uefi) PLAN_MBR_KIND='zero' ;;
					mbr:*)
						PLAN_MBR_KIND='rufus'
						PLAN_PBR_KIND='bootmgr'
						;;
				esac
				# NTFS needs the UEFI:NTFS helper partition to start under UEFI.
				if [[ $PLAN_FS == ntfs && $PLAN_TARGET != bios ]]; then
					PLAN_UEFI_NTFS=1
					_plan_warn plan.warn.uefi_ntfs_sb
				fi
				if ((OPT_WUE_FLAGS != 0)); then
					if win_wue_applicable; then
						PLAN_WUE_FLAGS=$OPT_WUE_FLAGS
					else
						_plan_warn plan.warn.wue_ignored
					fi
				fi
				;;
			isocopy)
				PLAN_BOOTABLE=1
				if [[ $PLAN_SCHEME == gpt ]]; then PLAN_MBR_KIND='gpt_msg'; else PLAN_MBR_KIND='zero'; fi
				;;
		esac

		if ((size > 0)); then
			if [[ $PLAN_MODE == windows || $PLAN_MODE == isocopy ]]; then
				if ((${IMG_PROJECTED_SIZE:-0} > size + 4096)); then
					_plan_fail plan.too_big
					return 1
				fi
			fi
			if [[ $PLAN_SCHEME == mbr ]] && ((size > 2199023255552)); then
				human_size $((size - 2199023255552))
				_plan_warn plan.warn.mbr_2tb "$REPLY"
			fi
			if ((sector != 512)) && ((PLAN_BOOTABLE)); then
				if [[ $PLAN_MBR_KIND == rufus ]]; then
					_plan_fail plan.sector_bios "$sector"
					return 1
				fi
				_plan_warn plan.warn.sector "$sector"
			fi
		fi

		# Extended label and icon: not for ext file systems, and never on top
		# of an autorun.inf that the image brings along.
		PLAN_EXTLABEL=$OPT_EXTLABEL
		case $PLAN_FS in ext*) PLAN_EXTLABEL=0 ;; esac
		((${IMG_HAS_AUTORUN:-0})) && [[ $PLAN_MODE == windows || $PLAN_MODE == isocopy ]] && PLAN_EXTLABEL=0
	fi

	if ((size == 0)); then
		_plan_fail plan.no_device
		return 1
	fi
	if ((size < 8388608)); then
		_plan_fail plan.too_small
		return 1
	fi
	_plan_commands
	PLAN_READY=1
	return 0
}

# Commands the plan needs (PLAN_CMDS) or would benefit from (PLAN_CMDS_OPTIONAL).
_plan_commands() {
	PLAN_CMDS=()
	PLAN_CMDS_OPTIONAL=()
	case $PLAN_MODE in
		dd)
			case ${IMG_COMPRESSION:-none} in
				gz) PLAN_CMDS+=(gzip) ;;
				xz | lzma) PLAN_CMDS+=(xz) ;;
				bz2) PLAN_CMDS+=(bzip2) ;;
				zst) PLAN_CMDS+=(zstd) ;;
				zip) PLAN_CMDS+=(unzip) ;;
				Z) PLAN_CMDS+=(gzip) ;;
			esac
			;;
		*)
			[[ $PLAN_SCHEME == gpt ]] && PLAN_CMDS+=(sfdisk)
			case $PLAN_FS in
				fat16 | fat32) PLAN_CMDS+=(mkfs.fat) ;;
				ntfs)
					PLAN_CMDS+=(mkntfs)
					# Writing files needs a driver: the kernel one if present,
					# otherwise ntfs-3g.
					if [[ $PLAN_MODE != format ]] || ((PLAN_EXTLABEL)); then
						_plan_has_fs ntfs3 || PLAN_CMDS+=(ntfs-3g)
					fi
					;;
				exfat) PLAN_CMDS+=(mkfs.exfat) ;;
				udf) PLAN_CMDS+=(mkudffs) ;;
				ext2 | ext3 | ext4) PLAN_CMDS+=(mke2fs) ;;
			esac
			((PLAN_SPLIT_WIM)) && PLAN_CMDS+=(wimlib-imagex)
			if ((PLAN_WUE_FLAGS != 0)); then
				PLAN_CMDS_OPTIONAL+=(wimlib-imagex hivexsh)
			fi
			[[ $PLAN_MODE == isocopy && -n ${IMG_EFI_IMG_PATH:-} ]] && PLAN_CMDS_OPTIONAL+=(mcopy)
			;;
	esac
	((OPT_BADBLOCKS > 0)) && PLAN_CMDS+=(badblocks)
	return 0
}

# _plan_has_fs NAME   true when the kernel already knows the file system type.
_plan_has_fs() {
	local first name
	[[ -r ${RC_PROCFS:-/proc}/filesystems ]] || return 1
	while read -r first name; do
		# Lines are "nodev<TAB>name" or "<TAB>name".
		[[ -z $name ]] && name=$first
		[[ $name == "$1" ]] && return 0
	done <"${RC_PROCFS:-/proc}/filesystems"
	return 1
}

# plan_summary   -> PLAN_SUM_LABEL[] / PLAN_SUM_VALUE[]: what will be done,
# for the confirmation prompt and --dry-run.
plan_summary() {
	local v opts=''
	PLAN_SUM_LABEL=()
	PLAN_SUM_VALUE=()
	_plan_sum() {
		t "$1"
		PLAN_SUM_LABEL+=("$REPLY")
		PLAN_SUM_VALUE+=("$2")
	}
	_plan_sum plan.sum.device "${TGT_DISPLAY:-}"
	case $PLAN_MODE in
		format) t plan.boot.none; _plan_sum plan.sum.boot "$REPLY" ;;
		freedos) _plan_sum plan.sum.boot 'FreeDOS' ;;
		*)
			v=${IMG_NAME:-}
			[[ -n ${IMG_DESC:-} ]] && v+=" - $IMG_DESC"
			_plan_sum plan.sum.boot "$v"
			;;
	esac
	case $PLAN_MODE in
		dd) t plan.mode.dd; _plan_sum plan.sum.mode "$REPLY" ;;
		isocopy) t plan.mode.iso; _plan_sum plan.sum.mode "$REPLY" ;;
		windows) t plan.mode.windows; _plan_sum plan.sum.mode "$REPLY" ;;
	esac
	if [[ $PLAN_MODE != dd ]]; then
		plan_scheme_name "$PLAN_SCHEME"
		_plan_sum plan.sum.scheme "$REPLY"
		plan_target_name "$PLAN_TARGET"
		_plan_sum plan.sum.target "$REPLY"
		_plan_sum plan.sum.label "$PLAN_FS_LABEL"
		plan_fs_name "$PLAN_FS"
		v=$REPLY
		if ((PLAN_UEFI_NTFS)); then t plan.fs.uefi_ntfs_note; v+=" ($REPLY)"; fi
		if ((PLAN_SPLIT_WIM)); then t plan.fs.split_note; v+=" ($REPLY)"; fi
		_plan_sum plan.sum.fs "$v"
		plan_cluster_name "$PLAN_CLUSTER"
		_plan_sum plan.sum.cluster "$REPLY"
		if ((OPT_QUICK)); then t plan.opt.quick; else t plan.opt.full; fi
		opts=$REPLY
		if ((PLAN_EXTLABEL)); then t plan.opt.extlabel; opts+=", $REPLY"; fi
		if ((OPT_OLD_BIOS)) && [[ $PLAN_SCHEME == mbr && $PLAN_TARGET == bios ]]; then
			t plan.opt.oldbios
			opts+=", $REPLY"
		fi
	fi
	if ((OPT_BADBLOCKS > 0)); then t plan.opt.badblocks; opts+="${opts:+, }$REPLY"; fi
	if ((OPT_VERIFY)) && [[ $PLAN_MODE == dd ]]; then t plan.opt.verify; opts+="${opts:+, }$REPLY"; fi
	[[ -n $opts ]] && _plan_sum plan.sum.options "$opts"
	if ((PLAN_WUE_FLAGS != 0)); then
		win_describe_flags "$PLAN_WUE_FLAGS"
		v=''
		local line
		for line in "${WIN_FLAG_LINES[@]}"; do
			v+="${v:+; }$line"
		done
		_plan_sum plan.sum.wue "$v"
	fi
	unset -f _plan_sum
	return 0
}

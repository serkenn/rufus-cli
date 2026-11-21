# shellcheck shell=bash disable=SC2153
# SPDX-License-Identifier: GPL-3.0-or-later
#
# rufus-cli - command line front end: option parsing, the informational
# sub-commands (list, info, hash, doctor) and the one-shot, scriptable way of
# running a job with a line-oriented progress display.

[[ -n ${_RC_CLI_LOADED:-} ]] && return 0
_RC_CLI_LOADED=1

msg_def cli.tagline 'Create bootable USB drives the easy way' '起動可能な USB ドライブを簡単に作成'
msg_def cli.based_on 'based on Rufus %s' 'Rufus %s ベース'
msg_def cli.err.unknown_option 'Unknown option: %s (see --help)' '不明なオプションです: %s (--help を参照)'
msg_def cli.err.missing_value 'Option %s requires a value' 'オプション %s には値が必要です'
msg_def cli.err.bad_value 'Invalid value for %s: %s' '%s の値が正しくありません: %s'
msg_def cli.err.unexpected 'Unexpected argument: %s' '予期しない引数です: %s'
msg_def cli.err.no_device 'No target device given (-d). Run without arguments for the interactive interface.' \
	'書き込み先のデバイスが指定されていません (-d)。引数なしで実行すると対話画面が開きます。'
msg_def cli.err.no_tty 'This operation erases the target: pass --yes to confirm when not running in a terminal' \
	'この操作は書き込み先のデータを消去します。端末以外から実行する場合は --yes を指定してください。'
msg_def cli.err.image_missing 'Cannot read image file: %s' 'イメージ ファイルを読み取れません: %s'
msg_def cli.err.size_needed 'The image file "%s" does not exist: give its size with --size (e.g. --size 8G)' \
	'イメージ ファイル "%s" は存在しません。--size でサイズを指定してください (例: --size 8G)。'
msg_def cli.err.aborted 'Aborted.' '中止しました。'
msg_def cli.err.missing_cmds 'Required tools are missing: %s' '必要なツールがありません: %s'
msg_def cli.need_root 'rufus-cli needs administrator privileges to access drives.' \
	'rufus-cli がドライブにアクセスするには管理者権限が必要です。'
msg_def cli.warn.destroy "WARNING: ALL DATA ON DEVICE '%s' WILL BE DESTROYED." \
	'警告: デバイス “%s” のデータはすべて消去されます。'
msg_def cli.warn.multipart 'IMPORTANT: THIS DRIVE CONTAINS MULTIPLE PARTITIONS!!' \
	'重要: このドライブは複数のパーティションを含んでいます!!'
msg_def cli.warn.not_removable 'This is not a removable flash drive (%s).' 'これはリムーバブルのフラッシュ ドライブではありません (%s)。'
msg_def cli.ask.continue 'Continue? [y/N] ' '続行しますか? [y/N] '
msg_def cli.ask.type_name 'Type the device name (%s) to continue: ' '続行するにはデバイス名 (%s) を入力してください: '
msg_def cli.ask.install 'Install them now? [Y/n] ' '今すぐインストールしますか? [Y/n] '
msg_def cli.pkgs_needed 'Packages to install: %s' 'インストールするパッケージ: %s'
msg_def cli.pkgs_hint 'Install them with: %s' '次のコマンドでインストールできます: %s'
msg_def cli.optional_missing 'Optional tools not installed (%s): a simpler method will be used' \
	'オプションのツールが未インストールです (%s)。簡易的な方法を使用します。'
msg_def cli.dry_run 'Dry run: nothing was written.' 'ドライ ラン: 何も書き込んでいません。'
msg_def cli.done 'READY' '準備完了'
msg_def cli.done_detail 'Completed in %s. The drive can be removed.' '%s で完了しました。ドライブを取り外せます。'
msg_def cli.failed 'Failed' '失敗しました'
msg_def cli.cancelled 'Cancelled' 'キャンセルされました'
msg_def cli.cancel_note 'The device may be left in an unusable state.' 'デバイスが使用できない状態になっている可能性があります。'
msg_def cli.log_at 'Log: %s' 'ログ: %s'
msg_def cli.cancelling 'Cancelling - Please wait...' 'キャンセル中 - お待ちください...'
msg_def cli.list.none 'No suitable drive found. Plug in a USB drive (see "rufus-cli list --all" for everything else).' \
	'使用できるドライブが見つかりません。USB ドライブを接続してください (他のドライブは "rufus-cli list --all" で確認できます)。'
msg_def cli.list.count1 '%d device found' '%d 個のデバイスを検出しました。'
msg_def cli.list.countn '%d devices found' '%d 個のデバイスを検出しました。'
msg_def cli.list.h.device 'DEVICE' 'デバイス'
msg_def cli.list.h.size 'SIZE' 'サイズ'
msg_def cli.list.h.type 'TYPE' '種類'
msg_def cli.list.h.name 'NAME' '名前'
msg_def cli.list.why.hdd 'USB hard drive: use --list-hdd' 'USB ハードドライブ: --list-hdd が必要'
msg_def cli.list.why.fixed 'internal disk: use --allow-fixed' '内蔵ディスク: --allow-fixed が必要'
msg_def cli.list.why.protected 'protected: %s' '保護対象: %s'
msg_def cli.list.why.ro 'read-only' '読み取り専用'
msg_def cli.list.why.other 'not usable' '使用不可'
msg_def cli.kind.ufd 'USB' 'USB'
msg_def cli.kind.hdd 'USB HDD' 'USB HDD'
msg_def cli.kind.card 'Card' 'カード'
msg_def cli.kind.fixed 'Disk' 'ディスク'
msg_def cli.kind.loop 'Image' 'イメージ'
msg_def cli.info.file 'File' 'ファイル'
msg_def cli.info.size 'Size' 'サイズ'
msg_def cli.info.type 'Type' '種類'
msg_def cli.info.label 'Label' 'ラベル'
msg_def cli.info.boot 'Boot' 'ブート'
msg_def cli.info.windows 'Windows' 'Windows'
msg_def cli.info.largest 'Largest file' '最大のファイル'
msg_def cli.info.content 'Content' '内容'
msg_def cli.info.modes 'Write modes' '書き込みモード'
msg_def cli.info.files '%d files, %s' '%d ファイル、%s'
msg_def cli.hash.title 'Computing image checksums' 'イメージのチェックサムを計算中'
msg_def cli.scanning 'Scanning image...' 'イメージをスキャン中...'
msg_def cli.info.yes 'yes' 'あり'
msg_def cli.info.no 'no' 'なし'
msg_def cli.info.bios 'BIOS' 'BIOS'
msg_def cli.info.uefi 'UEFI (%s)' 'UEFI (%s)'
msg_def cli.info.notboot 'not bootable' 'ブート不可'
msg_def cli.info.compressed '%s compressed' '%s 圧縮'
msg_def cli.info.unscanned 'Run with sudo for a full scan of the image contents.' \
	'イメージの内容を完全にスキャンするには sudo で実行してください。'
msg_def cli.info.mode.iso 'ISO (file copy)' 'ISO (ファイル コピー)'
msg_def cli.info.mode.dd 'DD (raw write)' 'DD (そのまま書き込み)'
msg_def cli.info.wim 'install image' 'インストール イメージ'
msg_def cli.layout 'Partition layout' 'パーティション レイアウト'
msg_def cli.doctor.title 'External tools' '外部ツール'
msg_def cli.doctor.ok 'installed' 'インストール済み'
msg_def cli.doctor.missing 'missing - package: %s' '未インストール - パッケージ: %s'
msg_def cli.doctor.unavailable 'missing - not packaged for this distribution' '未インストール - このディストリビューションにはパッケージがありません'
msg_def cli.doctor.system 'System' 'システム'
msg_def cli.doctor.all_ok 'Everything is installed.' 'すべてインストールされています。'

CLI_COMMAND=''		# '' (write) | list | info | hash | doctor | help | version
CLI_LIST_ALL=0
CLI_HASH_ALGOS=''
CLI_NO_TUI=0
CLI_VERBOSE=0
CLI_QUIET=0
CLI_LOG=''
CLI_WUE_DEFAULTS=0
declare -a CLI_ARGS=()

# --- help -------------------------------------------------------------------

cli_help() {
	cat <<EOF
rufus-cli $RC_VERSION - a Linux command-line port of Rufus $RC_RUFUS_VERSION

Usage:
  rufus-cli                               interactive full-screen interface
  rufus-cli -d DEVICE -i IMAGE [options]  write an ISO or disk image
  rufus-cli -d DEVICE -b none [options]   format a drive (non bootable)
  rufus-cli -d DEVICE -b freedos          create a FreeDOS bootable drive
  rufus-cli list [--all]                  list the drives that can be used
  rufus-cli info IMAGE                    show what an image contains
  rufus-cli hash IMAGE [--algo LIST]      MD5 / SHA-1 / SHA-256 / SHA-512 checksums
  rufus-cli doctor [--install-deps]       check the external tools

Target:
  -d, --device DEV        target drive (e.g. /dev/sdb), or an image file to write into
      --size SIZE         size of the image file to create (e.g. 8G)
      --list-hdd          also accept USB hard drives ("List USB Hard Drives")
      --allow-fixed       also accept internal, non-removable disks (dangerous)

Boot selection:
  -i, --image FILE        ISO image or (compressed) disk image
  -b, --boot TYPE         none = format only, freedos = FreeDOS system
  -m, --mode MODE         auto, iso (file copy) or dd (raw write)

Drive properties:
  -p, --partition-scheme  mbr, gpt or sfd (no partition table)
  -t, --target SYSTEM     bios, uefi or dual (BIOS or UEFI)
      --old-bios-fixes    extra partition and alignment for old BIOSes

Format options:
  -l, --label LABEL       volume label
  -f, --filesystem FS     fat16, fat32, ntfs, exfat, udf, ext2, ext3, ext4
  -c, --cluster-size N    cluster size (e.g. 4096, 16K)
      --full-format       slow format (quick format is the default)
      --no-extended-label do not create autorun.inf and the icon
      --bad-blocks[=N]    check the device first: 1, 2, slc, mlc or tlc passes
      --verify            read back and compare (dd mode)

Windows customization (Windows 10/11 images):
      --win-defaults            the options Rufus selects by default
      --win-bypass              remove the 4GB+ RAM, Secure Boot and TPM 2.0 requirement
      --win-no-online-account   remove the online Microsoft account requirement
      --win-local-account[=NAME] create a local account
      --win-regional            same regional options as this system
      --win-no-data-collection  disable data collection
      --win-no-bitlocker        disable BitLocker automatic device encryption
      --win-qol                 quality-of-life improvements
      --win-ca2023              use 'Windows CA 2023' signed bootloaders
      --win-skusipolicy         apply SkuSiPolicy.p7b on installation
      --win-locale L --win-timezone Z --win-keyboard K   override detected values

General:
  -y, --yes               do not ask for confirmation
  -n, --dry-run           show what would be done, write nothing
      --install-deps      install missing packages without asking
      --no-tui            never open the full-screen interface
      --lang en|ja        interface language
      --color WHEN        auto, always or never        --ascii   plain ASCII drawing
  -v, --verbose           print the log while working  -q, --quiet
      --log FILE          write the log to FILE
  -h, --help              this help                    -V, --version

Examples:
  sudo rufus-cli
  sudo rufus-cli -d /dev/sdb -i ubuntu-24.04.iso
  sudo rufus-cli -d /dev/sdb -i Win11_24H2.iso --win-defaults --win-local-account=taro
  sudo rufus-cli -d /dev/sdb -b none -f exfat -l BACKUP
  sudo rufus-cli -d ./usb.img --size 8G -i Win11.iso -y
EOF
}

# --- option parsing ---------------------------------------------------------

_cli_bad_value() {
	fail_t cli.err.bad_value "$1" "$2"
	return 2
}

# cli_parse ARGS...   fill OPT_* / CLI_*.  Returns 2 on a usage error.
cli_parse() {
	local arg val
	CLI_ARGS=()
	while (($# > 0)); do
		arg=$1
		shift
		# --name=value and -xVALUE forms.
		val=''
		local has_val=0
		case $arg in
			--*=*)
				val=${arg#*=}
				arg=${arg%%=*}
				has_val=1
				;;
		esac
		# Options that take a value: fetch it from the next argument.
		case $arg in
			-d | --device | -i | --image | -b | --boot | -m | --mode | -p | --partition-scheme | -t | --target | \
				-l | --label | -f | --filesystem | --fs | -c | --cluster-size | --size | --lang | --color | --log | \
				--algo | --win-locale | --win-timezone | --win-keyboard)
				if ((!has_val)); then
					if (($# == 0)); then
						fail_t cli.err.missing_value "$arg"
						return 2
					fi
					val=$1
					shift
				fi
				;;
		esac
		case $arg in
			-h | --help | help) CLI_COMMAND='help' ;;
			-V | --version | version) CLI_COMMAND='version' ;;
			list | info | hash | doctor)
				if [[ -z $CLI_COMMAND ]]; then CLI_COMMAND=$arg; else CLI_ARGS+=("$arg"); fi
				;;
			-a | --all) CLI_LIST_ALL=1 ;;
			--algo) CLI_HASH_ALGOS=${val//,/ } ;;
			-d | --device) OPT_DEVICE=$val ;;
			--size)
				parse_size "$val" || { _cli_bad_value "$arg" "$val"; return 2; }
				OPT_SIZE=$REPLY
				;;
			--list-hdd) OPT_LIST_HDD=1 ;;
			--allow-fixed) OPT_ALLOW_FIXED=1; OPT_LIST_HDD=1 ;;
			-i | --image)
				OPT_IMAGE=$val
				OPT_BOOT='image'
				;;
			-b | --boot)
				case ${val,,} in
					none | non-bootable | nonbootable | format) OPT_BOOT='none' ;;
					freedos | dos) OPT_BOOT='freedos' ;;
					image | iso) OPT_BOOT='image' ;;
					*) _cli_bad_value "$arg" "$val"; return 2 ;;
				esac
				;;
			-m | --mode)
				case ${val,,} in
					auto) OPT_MODE='auto' ;;
					iso | file | copy) OPT_MODE='iso' ;;
					dd | raw) OPT_MODE='dd' ;;
					*) _cli_bad_value "$arg" "$val"; return 2 ;;
				esac
				;;
			-p | --partition-scheme)
				case ${val,,} in
					auto) OPT_SCHEME='auto' ;;
					mbr | dos | msdos) OPT_SCHEME='mbr' ;;
					gpt) OPT_SCHEME='gpt' ;;
					sfd | none | superfloppy) OPT_SCHEME='sfd' ;;
					*) _cli_bad_value "$arg" "$val"; return 2 ;;
				esac
				;;
			-t | --target)
				case ${val,,} in
					auto) OPT_TARGET='auto' ;;
					bios | csm | legacy) OPT_TARGET='bios' ;;
					uefi | efi) OPT_TARGET='uefi' ;;
					dual | both | bios+uefi | uefi+bios) OPT_TARGET='dual' ;;
					*) _cli_bad_value "$arg" "$val"; return 2 ;;
				esac
				;;
			--old-bios-fixes) OPT_OLD_BIOS=1 ;;
			-l | --label)
				OPT_LABEL=$val
				OPT_LABEL_SET=1
				;;
			-f | --filesystem | --fs)
				case ${val,,} in
					auto) OPT_FS='auto' ;;
					fat | fat16) OPT_FS='fat16' ;;
					fat32 | vfat) OPT_FS='fat32' ;;
					ntfs | exfat | udf | ext2 | ext3 | ext4) OPT_FS=${val,,} ;;
					*) _cli_bad_value "$arg" "$val"; return 2 ;;
				esac
				;;
			-c | --cluster-size)
				if [[ ${val,,} == default || ${val,,} == auto ]]; then
					OPT_CLUSTER=0
				else
					parse_size "$val" || { _cli_bad_value "$arg" "$val"; return 2; }
					OPT_CLUSTER=$REPLY
				fi
				;;
			--full-format | --no-quick | --slow-format) OPT_QUICK=0 ;;
			--quick-format | --quick) OPT_QUICK=1 ;;
			--no-extended-label) OPT_EXTLABEL=0 ;;
			--extended-label) OPT_EXTLABEL=1 ;;
			--bad-blocks)
				if ((has_val)); then
					case ${val,,} in
						1) OPT_BADBLOCKS=1 ;;
						2) OPT_BADBLOCKS=2 ;;
						4 | slc) OPT_BADBLOCKS=3 ;;
						mlc) OPT_BADBLOCKS=4 ;;
						tlc) OPT_BADBLOCKS=5 ;;
						0 | off | no) OPT_BADBLOCKS=0 ;;
						*) _cli_bad_value "$arg" "$val"; return 2 ;;
					esac
				else
					OPT_BADBLOCKS=1
				fi
				;;
			--verify) OPT_VERIFY=1 ;;
			--win-defaults) CLI_WUE_DEFAULTS=1 ;;
			--win-bypass | --win-bypass-requirements) OPT_WUE_FLAGS=$((OPT_WUE_FLAGS | 0x1)) ;;
			--win-no-online-account) OPT_WUE_FLAGS=$((OPT_WUE_FLAGS | 0x4)) ;;
			--win-no-data-collection) OPT_WUE_FLAGS=$((OPT_WUE_FLAGS | 0x8)) ;;
			--win-regional | --win-duplicate-locale) OPT_WUE_FLAGS=$((OPT_WUE_FLAGS | 0x20)) ;;
			--win-local-account)
				OPT_WUE_FLAGS=$((OPT_WUE_FLAGS | 0x40))
				((has_val)) && OPT_WUE_USER=$val
				;;
			--win-no-bitlocker) OPT_WUE_FLAGS=$((OPT_WUE_FLAGS | 0x80)) ;;
			--win-ca2023) OPT_WUE_FLAGS=$((OPT_WUE_FLAGS | 0x200)) ;;
			--win-skusipolicy) OPT_WUE_FLAGS=$((OPT_WUE_FLAGS | 0x400)) ;;
			--win-qol) OPT_WUE_FLAGS=$((OPT_WUE_FLAGS | 0x1000)) ;;
			--win-locale) OPT_WUE_LOCALE=$val ;;
			--win-timezone) OPT_WUE_TIMEZONE=$val ;;
			--win-keyboard) OPT_WUE_KEYBOARD=$val ;;
			-y | --yes) OPT_YES=1 ;;
			-n | --dry-run) OPT_DRY_RUN=1 ;;
			--install-deps) OPT_INSTALL_DEPS=1 ;;
			--no-tui) CLI_NO_TUI=1 ;;
			--lang) OPT_LANG=$val ;;
			--color)
				case ${val,,} in
					auto | always | never) RUFUS_CLI_COLOR=${val,,} ;;
					*) _cli_bad_value "$arg" "$val"; return 2 ;;
				esac
				;;
			--no-color) RUFUS_CLI_COLOR='never' ;;
			--ascii) RUFUS_CLI_ASCII=1 ;;
			-v | --verbose) CLI_VERBOSE=1 ;;
			-q | --quiet) CLI_QUIET=1 ;;
			--log) CLI_LOG=$val ;;
			--)
				CLI_ARGS+=("$@")
				break
				;;
			-*)
				fail_t cli.err.unknown_option "$arg"
				return 2
				;;
			*) CLI_ARGS+=("$arg") ;;
		esac
	done
	return 0
}

# --- small output helpers ---------------------------------------------------

_cli_say() { ((CLI_QUIET)) || ui_line "$@"; }

_cli_banner() {
	((CLI_QUIET)) && return 0
	local tag
	ui_banner_lines
	t cli.tagline
	tag=$REPLY
	t cli.based_on "$RC_RUFUS_VERSION"
	ui_line ''
	if [[ -n ${UI_BANNER[1]} ]]; then
		ui_line "  ${UI_BANNER[0]}   ${S_BOLD}Rufus CLI${S_RESET} ${C_MUTED}${RC_VERSION} ${G_SEP} ${REPLY}${S_RESET}"
		ui_line "  ${UI_BANNER[1]}   ${C_MUTED}${tag}${S_RESET}"
	else
		ui_line "  ${UI_BANNER[0]} ${C_MUTED}${RC_VERSION} - ${REPLY}${S_RESET}"
	fi
	ui_line ''
}

# _cli_error [MESSAGE]   print ERR_MSG (or MESSAGE) on stderr.
_cli_error() {
	local msg=${1:-$ERR_MSG}
	[[ -n $msg ]] || return 0
	printf '%s%s%s %s\n' "$C_ERR" "$G_FAIL" "$S_RESET" "$msg" >&2
}

# _cli_ask PROMPT   read one line from the terminal -> REPLY (lower-cased).
_cli_ask() {
	local answer=''
	printf '%s' "$1" >&"$UI_FD"
	IFS= read -r -u "$UI_IN_FD" answer || answer=''
	REPLY=$answer
}

# _cli_disk_of_path PATH   -> REPLY: kernel name of the whole disk holding the
# file system PATH lives on ('' when it cannot be determined).
_cli_disk_of_path() {
	local src name sys
	REPLY=''
	have findmnt || return 0
	src=$(findmnt -n -o SOURCE --target "$1" 2>/dev/null | head -n 1) || return 0
	[[ $src == /dev/* ]] || return 0
	src=$(readlink -f "$src" 2>/dev/null) || return 0
	name=${src##*/}
	sys=${RC_SYSFS:-/sys}/class/block/$name
	[[ -e $sys ]] || return 0
	if [[ -e $sys/partition ]]; then
		sys=$(readlink -f "$sys" 2>/dev/null) || return 0
		name=${sys%/*}
		name=${name##*/}
	fi
	REPLY=$name
}

# --- sub-commands -----------------------------------------------------------

cli_cmd_version() {
	printf 'rufus-cli %s (based on Rufus %s)\n' "$RC_VERSION" "$RC_RUFUS_VERSION"
}

_cli_kind_name() {
	t "cli.kind.$1"
}

cli_cmd_list() {
	local i shown=0 why name wdev=10 wsize=4 kind
	dev_scan || { _cli_error; return 1; }
	local -a rows_dev=() rows_size=() rows_kind=() rows_name=() rows_dim=()
	for ((i = 0; i < DEV_COUNT; i++)); do
		why=''
		if ((!DEV_LISTED[i])); then
			((CLI_LIST_ALL)) || continue
			if ((DEV_PROTECTED[i])); then
				t cli.list.why.protected "${DEV_PROTECT_REASON[i]:-}"
			elif [[ ${DEV_KIND[i]} == hdd ]]; then
				t cli.list.why.hdd
			elif [[ ${DEV_KIND[i]} == fixed ]]; then
				t cli.list.why.fixed
			else
				t cli.list.why.other
			fi
			why=$REPLY
		else
			shown=$((shown + 1))
			if ((DEV_RO[i])); then
				t cli.list.why.ro
				why=$REPLY
			fi
		fi
		human_size "${DEV_SIZE[i]}"
		rows_dev+=("${DEV_PATH[i]}")
		rows_size+=("$REPLY")
		_cli_kind_name "${DEV_KIND[i]}"
		rows_kind+=("$REPLY")
		name="${DEV_VENDOR[i]:+${DEV_VENDOR[i]} }${DEV_MODEL[i]}"
		[[ -n ${DEV_LABEL[i]} ]] && name+=" [${DEV_LABEL[i]}]"
		[[ -n $why ]] && name+="  ($why)"
		rows_name+=("$name")
		rows_dim+=("$((1 - DEV_LISTED[i]))")
		ui_width "${DEV_PATH[i]}"
		((REPLY > wdev)) && wdev=$REPLY
	done
	if ((${#rows_dev[@]} == 0)); then
		t cli.list.none
		ui_line "$REPLY"
		return 0
	fi
	local h1 h2 h3 h4 line
	t cli.list.h.device; ui_pad "$REPLY" "$wdev"; h1=$REPLY
	t cli.list.h.size; ui_pad "$REPLY" 10 right; h2=$REPLY
	t cli.list.h.type; ui_pad "$REPLY" 8; h3=$REPLY
	t cli.list.h.name; h4=$REPLY
	ui_line "${C_MUTED}${h1}  ${h2}  ${h3}  ${h4}${S_RESET}"
	for ((i = 0; i < ${#rows_dev[@]}; i++)); do
		ui_pad "${rows_dev[i]}" "$wdev"; h1=$REPLY
		ui_pad "${rows_size[i]}" 10 right; h2=$REPLY
		ui_pad "${rows_kind[i]}" 8; h3=$REPLY
		line="${h1}  ${h2}  ${h3}  ${rows_name[i]}"
		if ((rows_dim[i])); then
			ui_line "${C_SUBTLE}${line}${S_RESET}"
		else
			ui_line "${S_BOLD}${h1}${S_RESET}  ${h2}  ${C_FOCUS}${h3}${S_RESET}  ${rows_name[i]}"
		fi
	done
	if ((!CLI_QUIET)); then
		if ((shown == 1)); then t cli.list.count1 "$shown"; else t cli.list.countn "$shown"; fi
		ui_line "${C_MUTED}${REPLY}${S_RESET}"
	fi
	return 0
}

cli_cmd_info() {
	local file=${CLI_ARGS[0]:-${OPT_IMAGE:-}} v i
	if [[ -z $file || ! -r $file ]]; then
		fail_t cli.err.image_missing "${file:-}"
		_cli_error
		return 1
	fi
	OPT_BOOT='image'
	OPT_IMAGE=$file
	img_analyze "$file" || { _cli_error; return 1; }
	t cli.info.file; ui_kv "$REPLY" "$IMG_PATH"
	human_size "$IMG_SIZE"; v=$REPLY
	if [[ ${IMG_COMPRESSION:-none} != none ]]; then
		t cli.info.compressed "$IMG_COMPRESSION"
		v+=" ($REPLY)"
	fi
	t cli.info.size; ui_kv "$REPLY" "$v"
	t cli.info.type; ui_kv "$REPLY" "${IMG_DESC:-}"
	if [[ -n ${IMG_LABEL:-} ]]; then
		t cli.info.label; ui_kv "$REPLY" "$IMG_LABEL"
	fi
	# How it can boot.
	v=''
	if ((${IMG_HAS_BOOTMGR:-0})) || ((${IMG_IS_BOOTABLE_DISK:-0})) || ((${IMG_HAS_SYSLINUX:-0})) || ((${IMG_HAS_GRUB2:-0})); then
		t cli.info.bios
		v=$REPLY
	fi
	if ((${IMG_HAS_EFI:-0})); then
		t cli.info.uefi "${IMG_EFI_ARCHS:-}"
		v+="${v:+, }$REPLY"
	fi
	if [[ -z $v ]]; then t cli.info.notboot; v=$REPLY; fi
	t cli.info.boot; ui_kv "$REPLY" "$v"
	if ((${IMG_IS_WINDOWS:-0})) && [[ -n ${IMG_WIN_NAME:-} || ${IMG_WIN_BUILD:-0} != 0 ]]; then
		v="${IMG_WIN_NAME:-Windows}"
		((${IMG_WIN_BUILD:-0} > 0)) && v+=" (${IMG_WIN_MAJOR:-0}.${IMG_WIN_MINOR:-0}.${IMG_WIN_BUILD})"
		[[ -n ${IMG_WIN_ARCH:-} ]] && v+=" ${IMG_WIN_ARCH}"
		t cli.info.windows; ui_kv "$REPLY" "$v"
		if [[ -n ${IMG_WININST_PATH:-} ]]; then
			human_size "${IMG_WININST_SIZE:-0}"; v=$REPLY
			t cli.info.wim; ui_kv "$REPLY" "$IMG_WININST_PATH ($v)"
		fi
	fi
	if ((${IMG_SCANNED:-0})); then
		human_size "${IMG_TOTAL_BYTES:-0}"
		t cli.info.files "${IMG_FILE_COUNT:-0}" "$REPLY"; v=$REPLY
		t cli.info.content; ui_kv "$REPLY" "$v"
		if [[ -n ${IMG_LARGEST_FILE:-} ]]; then
			human_size "${IMG_LARGEST_SIZE:-0}"; v=$REPLY
			t cli.info.largest; ui_kv "$REPLY" "$IMG_LARGEST_FILE ($v)"
		fi
	fi
	# Which write modes apply (drive-independent part of the plan).
	TGT_SIZE=0
	plan_resolve || true
	v=''
	for i in "${PLAN_MODES[@]}"; do
		t "cli.info.mode.$i"
		v+="${v:+, }$REPLY"
	done
	if [[ -n $v ]]; then
		t cli.info.modes; ui_kv "$REPLY" "$v"
	fi
	if ((!${IMG_SCANNED:-0})) && ((${IMG_IS_ISO:-0})) && ! core_is_root; then
		t cli.info.unscanned
		ui_dimline "$REPLY"
	fi
	return 0
}

cli_cmd_hash() {
	local file=${CLI_ARGS[0]:-${OPT_IMAGE:-}} algos=${CLI_HASH_ALGOS:-md5 sha1 sha256} a rc=0
	if [[ -z $file || ! -r $file ]]; then
		fail_t cli.err.image_missing "${file:-}"
		_cli_error
		return 1
	fi
	[[ $algos == all ]] && algos='md5 sha1 sha256 sha512'
	job_reset
	t cli.hash.title
	JOB_PHASE=$REPLY
	_cli_progress_begin
	# shellcheck disable=SC2086  # the list of algorithms is meant to be split
	hash_file "$file" $algos || rc=$?
	_cli_progress_end
	if ((rc != 0)); then
		_cli_error
		return "$rc"
	fi
	for a in $algos; do
		ui_pad "${a^^}" 8
		ui_line "${C_MUTED}${REPLY}${S_RESET}${HASH_RESULT[$a]:-}"
	done
	return 0
}

cli_cmd_doctor() {
	local c name rc=0
	local -a missing=() installable=()
	local -a all=(sfdisk blkid lsblk mkfs.fat mkntfs ntfs-3g mkfs.exfat mke2fs mkudffs badblocks wimlib-imagex
		hivexsh mcopy xz zstd bzip2 unzip iconv udevadm)
	deps_detect
	if ((OPT_INSTALL_DEPS)) && ! core_is_root; then
		core_reexec_as_root doctor --install-deps || { _cli_error; return 1; }
	fi
	t cli.doctor.system
	ui_kv "$REPLY" "$DEPS_PRETTY ${C_MUTED}(bash $BASH_VERSION)${S_RESET}"
	ui_line ''
	t cli.doctor.title
	ui_rule_text "$REPLY" 60
	ui_line "  $REPLY"
	for c in "${all[@]}"; do
		ui_pad "$c" 16
		name=$REPLY
		if have "$c"; then
			t cli.doctor.ok
			ui_line "  ${C_OK}${G_OK}${S_RESET} ${name} ${C_MUTED}${REPLY}${S_RESET}"
			continue
		fi
		missing+=("$c")
		deps_pkg_for "$c"
		if [[ -n $REPLY ]]; then
			installable+=("$c")
			if ((DEPS_PKG_EPEL)); then REPLY+=' (EPEL)'; fi
			t cli.doctor.missing "$REPLY"
		else
			t cli.doctor.unavailable
		fi
		ui_line "  ${C_WARN}${G_PENDING}${S_RESET} ${name} ${C_MUTED}${REPLY}${S_RESET}"
	done
	ui_line ''
	if ((${#missing[@]} == 0)); then
		t cli.doctor.all_ok
		ui_ok "$REPLY"
		return 0
	fi
	((${#installable[@]} > 0)) || return 0
	deps_resolve "${installable[@]}"
	deps_install_hint
	t cli.pkgs_hint "$REPLY"
	ui_info "$REPLY"
	if ((OPT_INSTALL_DEPS)); then
		job_reset
		t deps.installing "${DEPS_PKGS[*]}"
		JOB_PHASE=$REPLY
		_cli_progress_begin
		deps_install "${installable[@]}" || rc=$?
		_cli_progress_end
		if ((rc != 0)); then
			_cli_error
			return 1
		fi
		t cli.doctor.all_ok
		ui_ok "$REPLY"
	fi
	return 0
}

# --- line-oriented progress -------------------------------------------------

_CLI_PROGRESS_ACTIVE=0
_CLI_LAST_PLAIN=-1
_CLI_LAST_PLAIN_T=0

# Draw the live status line (terminal) or an occasional plain line (pipe).
_cli_progress_draw() {
	local line bar pct='' detail='' width note avail step
	((CLI_QUIET)) && return 0
	ui_tick
	if ((!UI_TTY)); then
		# Not a terminal: one line every 10 % (or 30 s) is plenty.
		((JOB_PCT >= 0)) || return 0
		step=$((JOB_PCT / 100))
		now_s
		if ((step != _CLI_LAST_PLAIN)) || ((REPLY - _CLI_LAST_PLAIN_T >= 30)); then
			_CLI_LAST_PLAIN=$step
			_CLI_LAST_PLAIN_T=$REPLY
			ui_line "    ${JOB_PHASE}: $((JOB_PCT / 10))%"
		fi
		return 0
	fi
	width=$((UI_COLS - 1))
	((width > 110)) && width=110
	if ((JOB_PCT >= 0)); then
		ui_progress_bar "$JOB_PCT" 24
		bar=$REPLY
		printf -v pct '%3d.%d%%' $((JOB_PCT / 10)) $((JOB_PCT % 10))
		if ((JOB_TOTAL > 0)); then
			human_size "$JOB_DONE"
			detail=$REPLY
			human_size "$JOB_TOTAL"
			detail+=" / $REPLY"
		fi
		if ((JOB_RATE > 0)); then
			ui_rate "$JOB_RATE"
			detail+="${detail:+  }$REPLY"
		fi
		if ((JOB_ETA >= 0)); then
			human_duration "$JOB_ETA"
			detail+="  ETA $REPLY"
		fi
	else
		ui_progress_bar -1 24
		bar=$REPLY
		pct='      '
		if ((JOB_DONE > 0)); then
			human_size "$JOB_DONE"
			detail=$REPLY
			if ((JOB_RATE > 0)); then
				ui_rate "$JOB_RATE"
				detail+="  $REPLY"
			fi
		fi
	fi
	note=$JOB_PHASE
	[[ -n $JOB_NOTE ]] && note+=": $JOB_NOTE"
	# "  <spinner> <note>  <bar> <pct>  <detail>"
	avail=$((width - 4 - 2 - 24 - 1 - ${#pct} - 2 - ${#detail}))
	((avail < 12)) && avail=12
	ui_pad "$note" "$avail"
	note=$REPLY
	ui_spinner
	line="  ${C_FOCUS}${REPLY}${S_RESET} ${note}  ${bar} ${S_BOLD}${pct}${S_RESET}  ${C_MUTED}${detail}${S_RESET}"
	# No wrapping while the line is being redrawn in place.
	printf '\r\e[?7l%s\e[K\e[?7h' "$line" >&"$UI_FD"
	_CLI_PROGRESS_ACTIVE=1
}

_cli_progress_clear() {
	if ((_CLI_PROGRESS_ACTIVE)) && ((UI_TTY)); then
		printf '\r\e[K' >&"$UI_FD"
	fi
	_CLI_PROGRESS_ACTIVE=0
}

# Poll the keyboard during a job: wait at most $1 seconds.
_cli_key_hook() {
	local wait=${1:-0}
	if ((UI_TTY)); then
		if [[ $wait == 0 ]]; then wait=0.001; fi
		# Keys are not used in this mode; reading merely paces the loop and
		# lets Ctrl-C (SIGINT) interrupt the wait at once.
		ui_read_key "$wait" || true
	else
		[[ $wait == 0 ]] || rc_sleep "$wait"
	fi
	if ((RC_CANCELLED)) && ((!_CLI_CANCEL_SHOWN)); then
		_CLI_CANCEL_SHOWN=1
		_cli_progress_clear
		t cli.cancelling
		ui_warn "$REPLY"
	fi
	return 0
}
_CLI_CANCEL_SHOWN=0

_cli_step_hook() {
	local idx=$1 state=$2 title=${PIPE_TITLE[$1]} took=''
	((CLI_QUIET)) && return 0
	_cli_progress_clear
	case $state in
		running)
			_CLI_LAST_PLAIN=-1
			if ((!UI_TTY)); then
				ui_line "  ${G_PENDING} ${title}"
			fi
			;;
		'done')
			if ((PIPE_SECONDS[idx] >= 2)); then
				human_duration "${PIPE_SECONDS[idx]}"
				took=" ${C_MUTED}(${REPLY})${S_RESET}"
			fi
			ui_ok "${title}${took}"
			;;
		failed) ui_fail "$title" ;;
		cancelled) ui_warn "$title" ;;
	esac
	return 0
}

_cli_progress_begin() {
	_CLI_PROGRESS_ACTIVE=0
	_CLI_CANCEL_SHOWN=0
	JOB_UI_HOOK=_cli_progress_draw
	JOB_KEY_HOOK=_cli_key_hook
	if ((UI_TTY)); then
		ui_raw_on
		ui_cursor_hide
		cleanup_push '_cli_progress_end'
	fi
}

_cli_progress_end() {
	_cli_progress_clear
	JOB_UI_HOOK=''
	JOB_KEY_HOOK=''
	if ((UI_TTY)); then
		ui_cursor_show
		ui_raw_off
		cleanup_remove '_cli_progress_end' || true
	fi
	return 0
}

# --- the one-shot job -------------------------------------------------------

# Select the target given on the command line -> TGT_*.
_cli_select_target() {
	local idx
	if [[ $OPT_DEVICE != /dev/* && ( -f $OPT_DEVICE || ! -e $OPT_DEVICE ) ]]; then
		# A regular file (existing or to be created): a disk image target.
		if [[ ! -e $OPT_DEVICE && -z $OPT_SIZE ]]; then
			fail_t cli.err.size_needed "$OPT_DEVICE"
			return 1
		fi
		dev_attach_image "$OPT_DEVICE" "$OPT_SIZE" || return 1
		return 0
	fi
	dev_scan || return 1
	dev_find "$OPT_DEVICE" || return 1
	idx=$REPLY
	dev_select "$idx" || return 1
	TGT_LABEL=${DEV_LABEL[idx]:-}
	TGT_KIND=${DEV_KIND[idx]:-}
	TGT_PARTS=${DEV_PARTS[idx]:-0}
	return 0
}

# Make sure the tools the plan needs are there, installing them if allowed.
_cli_check_deps() {
	local rc=0 c
	local -a missing=() optional=() wanted=() installable=()
	deps_check "${PLAN_CMDS[@]}" || missing=("${DEPS_MISSING[@]}")
	deps_check "${PLAN_CMDS_OPTIONAL[@]}" || optional=("${DEPS_MISSING[@]}")
	if ((${#missing[@]} == 0)); then
		if ((${#optional[@]} == 0)); then
			return 0
		fi
		if ((!OPT_INSTALL_DEPS)); then
			# Nothing essential is missing: carry on with the simpler method.
			t cli.optional_missing "${optional[*]}"
			_cli_say "  ${C_MUTED}${REPLY}${S_RESET}"
			return 0
		fi
	fi
	if ((${#missing[@]} > 0)); then
		t cli.err.missing_cmds "${missing[*]}"
		ui_warn "$REPLY"
	fi
	wanted=("${missing[@]}" "${optional[@]}")
	deps_resolve "${wanted[@]}"
	for c in "${missing[@]}"; do
		if in_list "$c" "${DEPS_UNAVAILABLE[@]}"; then
			fail_t deps.unavailable "$c" "$DEPS_PRETTY"
			return 1
		fi
	done
	# Optional tools that are not packaged here simply stay missing.
	for c in "${wanted[@]}"; do
		in_list "$c" "${DEPS_UNAVAILABLE[@]}" || installable+=("$c")
	done
	if ((${#DEPS_PKGS[@]} == 0)); then
		if ((${#missing[@]} > 0)); then
			fail_t cli.err.missing_cmds "${missing[*]}"
			return 1
		fi
		return 0
	fi
	c="${DEPS_PKGS[*]}"
	if ((DEPS_EPEL)); then c+=' (EPEL)'; fi
	t cli.pkgs_needed "$c"
	ui_info "$REPLY"
	if ((!OPT_INSTALL_DEPS)); then
		if ((OPT_DRY_RUN)) || ((!UI_TTY)) || ((OPT_YES)); then
			deps_install_hint
			t cli.pkgs_hint "$REPLY"
			ui_info "$REPLY"
			((OPT_DRY_RUN)) && return 0
			fail_t cli.err.missing_cmds "${missing[*]}"
			return 1
		fi
		t cli.ask.install
		_cli_ask "  $REPLY"
		case ${REPLY,,} in
			'' | y | yes) ;;
			*)
				fail_t cli.err.missing_cmds "${missing[*]}"
				return 1
				;;
		esac
	fi
	((OPT_DRY_RUN)) && return 0
	job_reset
	t deps.installing "${DEPS_PKGS[*]}"
	JOB_PHASE=$REPLY
	_cli_progress_begin
	deps_install "${installable[@]}" || rc=$?
	_cli_progress_end
	((rc == 130)) && return 130
	# Only the mandatory tools decide whether we can go on.
	if ! deps_check "${missing[@]}"; then
		[[ -n $ERR_MSG ]] || fail_t cli.err.missing_cmds "${DEPS_MISSING[*]}"
		return 1
	fi
	t deps.installing "${DEPS_PKGS[*]}"
	ui_ok "$REPLY"
	return 0
}

# Ask for the final go-ahead (Rufus' MSG_003 / MSG_093 warnings).
_cli_confirm() {
	local name=${TGT_NAME:-}
	t cli.warn.destroy "${TGT_DISPLAY:-$TGT_PATH}"
	ui_line ''
	ui_line "  ${C_WARN}${S_BOLD}${REPLY}${S_RESET}"
	if ((${TGT_PARTS:-0} > 1)); then
		t cli.warn.multipart
		ui_line "  ${C_WARN}${REPLY}${S_RESET}"
	fi
	((OPT_YES)) && return 0
	if ((!UI_TTY)); then
		fail_t cli.err.no_tty
		return 1
	fi
	case ${TGT_KIND:-} in
		hdd | fixed)
			# Not a plain flash drive: make the user spell it out.
			_cli_kind_name "$TGT_KIND"
			t cli.warn.not_removable "$REPLY"
			ui_line "  ${C_WARN}${REPLY}${S_RESET}"
			t cli.ask.type_name "$name"
			_cli_ask "  $REPLY"
			if [[ $REPLY != "$name" && $REPLY != "/dev/$name" ]]; then
				fail_t cli.err.aborted
				return 1
			fi
			;;
		*)
			t cli.ask.continue
			_cli_ask "  $REPLY"
			case ${REPLY,,} in
				y | yes | はい) ;;
				*)
					fail_t cli.err.aborted
					return 1
					;;
			esac
			;;
	esac
	return 0
}

_cli_show_plan() {
	local i lw=0
	((CLI_QUIET)) && return 0
	plan_summary
	for ((i = 0; i < ${#PLAN_SUM_LABEL[@]}; i++)); do
		ui_width "${PLAN_SUM_LABEL[i]}"
		((REPLY > lw)) && lw=$REPLY
	done
	for ((i = 0; i < ${#PLAN_SUM_LABEL[@]}; i++)); do
		ui_kv "${PLAN_SUM_LABEL[i]}" "${PLAN_SUM_VALUE[i]}" $((lw + 2))
	done
	for ((i = 0; i < ${#PLAN_WARNINGS[@]}; i++)); do
		ui_warn "${PLAN_WARNINGS[i]}"
	done
	return 0
}

cli_run_job() {
	local rc=0 disk
	if [[ -z $OPT_DEVICE ]]; then
		fail_t cli.err.no_device
		_cli_error
		return 2
	fi
	if [[ $OPT_BOOT == image ]]; then
		if [[ -z $OPT_IMAGE || ! -r $OPT_IMAGE ]]; then
			fail_t cli.err.image_missing "${OPT_IMAGE:-}"
			_cli_error
			return 1
		fi
	fi
	_cli_banner

	# The drive that holds the image must never become the target.
	DEV_EXTRA_PROTECTED=''
	if [[ $OPT_BOOT == image ]]; then
		_cli_disk_of_path "$OPT_IMAGE"
		DEV_EXTRA_PROTECTED=$REPLY
		t cli.scanning
		_cli_say "  ${C_MUTED}${REPLY}${S_RESET}"
		job_reset
		img_analyze "$OPT_IMAGE" || { _cli_error; return 1; }
	fi
	_cli_select_target || { _cli_error; return 1; }

	if ((CLI_WUE_DEFAULTS)) && [[ $OPT_BOOT == image ]]; then
		win_wue_default_flags
		OPT_WUE_FLAGS=$((OPT_WUE_FLAGS | REPLY))
	fi
	if ! plan_resolve; then
		_cli_error "$PLAN_ERROR"
		return 1
	fi
	_cli_show_plan
	_cli_check_deps || { _cli_error; return 1; }
	if ((OPT_DRY_RUN)); then
		if [[ $PLAN_MODE != dd ]] && pipeline_layout_preview; then
			local layout=$REPLY line
			t cli.layout
			ui_line ''
			ui_line "  ${C_MUTED}${REPLY}${S_RESET}"
			while IFS= read -r line; do
				ui_line "    $line"
			done <<<"$layout"
		fi
		ui_line ''
		t cli.dry_run
		ui_info "$REPLY"
		if ((TGT_IS_IMAGE_FILE)); then
			dev_detach_image || true
		fi
		return 0
	fi
	_cli_confirm || { _cli_error; return 1; }

	ui_line ''
	PIPE_HOOK=_cli_step_hook
	_cli_progress_begin
	pipeline_run || rc=$?
	_cli_progress_end
	PIPE_HOOK=''
	if ((TGT_IS_IMAGE_FILE)); then
		dev_detach_image || true
	fi
	ui_line ''
	case $PIPE_RESULT in
		ok)
			human_duration "$PIPE_ELAPSED"
			t cli.done_detail "$REPLY"
			ui_line "  ${C_OK}${S_BOLD}${G_OK}${S_RESET} ${S_BOLD}${REPLY}${S_RESET}"
			;;
		cancelled)
			t cli.cancelled
			ui_warn "${S_BOLD}${REPLY}${S_RESET}"
			t cli.cancel_note
			ui_dimline "$REPLY"
			rc=130
			;;
		*)
			t cli.failed
			ui_fail "${S_BOLD}${REPLY}${S_RESET}: ${ERR_MSG}"
			t cli.log_at "$LOG_FILE"
			ui_dimline "$REPLY"
			rc=1
			;;
	esac
	return "$rc"
}

# --- entry point ------------------------------------------------------------

cli_main() {
	local rc=0
	plan_defaults
	i18n_init
	cli_parse "$@" || rc=$?
	i18n_init
	ui_setup_locale
	ui_init
	if ((rc != 0)); then
		_cli_error
		return 2
	fi
	case $CLI_COMMAND in
		help)
			cli_help
			return 0
			;;
		version)
			cli_cmd_version
			return 0
			;;
	esac
	LOG_VERBOSE=$CLI_VERBOSE
	log_init "$CLI_LOG"
	core_install_traps
	deps_detect

	case $CLI_COMMAND in
		list)
			cli_cmd_list
			return
			;;
		info)
			cli_cmd_info
			return
			;;
		hash)
			cli_cmd_hash
			return
			;;
		doctor)
			cli_cmd_doctor
			return
			;;
	esac
	if ((${#CLI_ARGS[@]} > 0)); then
		fail_t cli.err.unexpected "${CLI_ARGS[0]}"
		_cli_error
		return 2
	fi

	# Without a target on the command line this is the interactive interface.
	if [[ -z $OPT_DEVICE ]]; then
		if ((CLI_NO_TUI)) || ((!UI_TTY)) || ((OPT_DRY_RUN)); then
			fail_t cli.err.no_device
			_cli_error
			return 2
		fi
	fi
	# Drives can only be examined and written with full privileges.
	if ! core_is_root; then
		t cli.need_root
		_cli_say "$REPLY"
		core_reexec_as_root "$@" || { _cli_error; return 1; }
	fi
	if [[ -z $OPT_DEVICE ]]; then
		tui_main
	else
		cli_run_job
	fi
}

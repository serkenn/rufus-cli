# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# rufus-cli - external tool dependencies: which package provides which
# command on which distribution, and how to install what is missing.
#
# The package names below were verified by installing them in the official
# images of every supported release (Debian 12/13, Ubuntu 20.04-26.04,
# AlmaLinux 8/9/10 with and without EPEL).  Notable gaps:
#   * RHEL family: NTFS tools, wimlib, p7zip (and exfatprogs on 8) come from EPEL
#   * EL 10: no wimlib and no udftools package at all
#   * Ubuntu 20.04: exfat-utils instead of exfatprogs

[[ -n ${_RC_DEPS_LOADED:-} ]] && return 0
_RC_DEPS_LOADED=1

msg_def deps.unknown_distro 'Automatic installation is not supported on this distribution; please install: %s' \
	'このディストリビューションでは自動インストールに対応していません。次のコマンドを手動でインストールしてください: %s'
msg_def deps.unavailable 'No package provides "%s" on %s' '"%s" を提供するパッケージが %s にはありません'
msg_def deps.install_failed 'Package installation failed (see the log): %s' 'パッケージのインストールに失敗しました (ログを参照): %s'
msg_def deps.still_missing 'Still missing after installation: %s' 'インストール後も見つかりません: %s'
msg_def deps.need_root 'Installing packages requires root privileges' 'パッケージのインストールには root 権限が必要です'
msg_def deps.installing 'Installing packages: %s' 'パッケージをインストール中: %s'
msg_def deps.enabling_epel 'Enabling the EPEL repository' 'EPEL リポジトリを有効化中'

DEPS_FAMILY=''		# debian | rhel | fedora | unknown
DEPS_ID=''		# os-release ID
DEPS_MAJOR=0		# major version number
DEPS_MINOR=0
DEPS_PRETTY=''
DEPS_DETECTED=0
declare -a DEPS_MISSING=()	# commands that are not installed
declare -a DEPS_PKGS=()		# packages to install for them
declare -a DEPS_UNAVAILABLE=()	# commands no package provides on this system
DEPS_EPEL=0			# 1 when one of the packages needs EPEL
DEPS_PKG_EPEL=0			# set by deps_pkg_for: the package comes from EPEL

# deps_detect   read os-release once.
deps_detect() {
	((DEPS_DETECTED)) && return 0
	local file line key val id='' like='' version='' pretty=''
	file=${RC_ETC:-/etc}/os-release
	[[ -r $file ]] || file=/usr/lib/os-release
	if [[ -r $file ]]; then
		while IFS= read -r line || [[ -n $line ]]; do
			[[ $line == *=* ]] || continue
			key=${line%%=*}
			val=${line#*=}
			# Values may be quoted with single or double quotes.
			val=${val#[\"\']}
			val=${val%[\"\']}
			case $key in
				ID) id=${val,,} ;;
				ID_LIKE) like=${val,,} ;;
				VERSION_ID) version=$val ;;
				PRETTY_NAME) pretty=$val ;;
			esac
		done <"$file"
	fi
	DEPS_ID=${id:-unknown}
	DEPS_PRETTY=${pretty:-$DEPS_ID}
	DEPS_MAJOR=${version%%.*}
	DEPS_MINOR=0
	if [[ $version == *.* ]]; then
		DEPS_MINOR=${version#*.}
		DEPS_MINOR=${DEPS_MINOR%%.*}
	fi
	is_uint "$DEPS_MAJOR" || DEPS_MAJOR=0
	is_uint "$DEPS_MINOR" || DEPS_MINOR=0
	# Leading zeros ("04") must not be read as octal later on.
	DEPS_MAJOR=$((10#$DEPS_MAJOR))
	DEPS_MINOR=$((10#$DEPS_MINOR))
	case " $id $like " in
		*' fedora '*)
			if [[ $id == fedora ]]; then DEPS_FAMILY='fedora'; else DEPS_FAMILY='rhel'; fi
			;;
		*' rhel '* | *' centos '* | *' almalinux '* | *' rocky '* | *' ol '*) DEPS_FAMILY='rhel' ;;
		*' debian '* | *' ubuntu '*) DEPS_FAMILY='debian' ;;
		*) DEPS_FAMILY='unknown' ;;
	esac
	DEPS_DETECTED=1
	log "distribution: $DEPS_PRETTY (family $DEPS_FAMILY, id $DEPS_ID, version $DEPS_MAJOR.$DEPS_MINOR)"
}

# True on Ubuntu (or a derivative that reports Ubuntu's numbering).
_deps_is_ubuntu() { [[ $DEPS_ID == ubuntu ]]; }

# deps_pkg_for COMMAND   -> REPLY: package providing COMMAND on this system
# ('' when none does).  Sets DEPS_PKG_EPEL.
deps_pkg_for() {
	local cmd=$1 pkg='' epel=0
	deps_detect
	case $DEPS_FAMILY in
		debian)
			case $cmd in
				sfdisk | fdisk) pkg='fdisk' ;;
				lsblk | blkid | wipefs | findmnt | losetup | blockdev | partx | mount | umount | flock) pkg='util-linux' ;;
				mkfs.fat | mkfs.vfat | fsck.fat | fatlabel) pkg='dosfstools' ;;
				mkntfs | mkfs.ntfs | ntfs-3g | ntfslabel) pkg='ntfs-3g' ;;
				mkfs.exfat)
					# exfatprogs replaced exfat-utils from Debian 11 / Ubuntu 22.04 on.
					if _deps_is_ubuntu && ((DEPS_MAJOR < 22)); then pkg='exfat-utils'; else pkg='exfatprogs'; fi
					;;
				mount.exfat-fuse) pkg='exfat-fuse' ;;
				mkudffs) pkg='udftools' ;;
				mke2fs | mkfs.ext2 | mkfs.ext3 | mkfs.ext4 | badblocks | e2label) pkg='e2fsprogs' ;;
				wimlib-imagex) pkg='wimtools' ;;
				hivexsh) pkg='libhivex-bin' ;;
				hivexregedit) pkg='libwin-hivex-perl' ;;
				mcopy | mdir | mattrib) pkg='mtools' ;;
				7z)
					if { _deps_is_ubuntu && ((DEPS_MAJOR >= 24)); } || { [[ $DEPS_ID == debian ]] && ((DEPS_MAJOR >= 13)); }; then
						pkg='7zip'
					else
						pkg='p7zip-full'
					fi
					;;
				xz) pkg='xz-utils' ;;
				zstd) pkg='zstd' ;;
				bzip2) pkg='bzip2' ;;
				gzip) pkg='gzip' ;;
				unzip) pkg='unzip' ;;
				iconv) pkg='libc-bin' ;;
				udevadm) pkg='udev' ;;
				eject) pkg='eject' ;;
				fatattr) pkg='fatattr' ;;
			esac
			;;
		rhel | fedora)
			case $cmd in
				sfdisk | fdisk | lsblk | blkid | wipefs | findmnt | losetup | blockdev | partx | mount | umount | flock) pkg='util-linux' ;;
				mkfs.fat | mkfs.vfat | fsck.fat | fatlabel) pkg='dosfstools' ;;
				mkntfs | mkfs.ntfs | ntfslabel) pkg='ntfsprogs'; epel=1 ;;
				ntfs-3g) pkg='ntfs-3g'; epel=1 ;;
				mkfs.exfat)
					pkg='exfatprogs'
					[[ $DEPS_FAMILY == rhel ]] && ((DEPS_MAJOR <= 8)) && epel=1
					;;
				mkudffs)
					# Not packaged for EL 10 (neither in the base repositories nor in EPEL).
					if [[ $DEPS_FAMILY == rhel ]] && ((DEPS_MAJOR >= 10)); then pkg=''; else pkg='udftools'; fi
					;;
				mke2fs | mkfs.ext2 | mkfs.ext3 | mkfs.ext4 | badblocks | e2label) pkg='e2fsprogs' ;;
				wimlib-imagex)
					if [[ $DEPS_FAMILY == rhel ]] && ((DEPS_MAJOR >= 10)); then
						pkg=''
					else
						pkg='wimlib-utils'
						epel=1
					fi
					;;
				hivexsh) pkg='hivex' ;;
				mcopy | mdir | mattrib) pkg='mtools' ;;
				7z) pkg='p7zip-plugins'; epel=1 ;;
				xz) pkg='xz' ;;
				zstd) pkg='zstd' ;;
				bzip2) pkg='bzip2' ;;
				gzip) pkg='gzip' ;;
				unzip) pkg='unzip' ;;
				iconv) pkg='glibc-common' ;;
				udevadm) pkg='systemd-udev' ;;
				eject) pkg='util-linux' ;;
			esac
			# Fedora carries everything in its own repositories.
			[[ $DEPS_FAMILY == fedora ]] && epel=0
			;;
	esac
	DEPS_PKG_EPEL=$epel
	REPLY=$pkg
}

# deps_check COMMAND...   -> DEPS_MISSING[] (may be empty).  True when all are present.
deps_check() {
	local c
	DEPS_MISSING=()
	for c in "$@"; do
		have "$c" || DEPS_MISSING+=("$c")
	done
	((${#DEPS_MISSING[@]} == 0))
}

# deps_resolve COMMAND...   map missing commands to packages:
# -> DEPS_PKGS[] (unique), DEPS_EPEL, DEPS_UNAVAILABLE[]
deps_resolve() {
	local c
	DEPS_PKGS=()
	DEPS_UNAVAILABLE=()
	DEPS_EPEL=0
	for c in "$@"; do
		deps_pkg_for "$c"
		if [[ -z $REPLY ]]; then
			DEPS_UNAVAILABLE+=("$c")
			continue
		fi
		in_list "$REPLY" "${DEPS_PKGS[@]}" || DEPS_PKGS+=("$REPLY")
		((DEPS_PKG_EPEL)) && DEPS_EPEL=1
	done
	return 0
}

# deps_install_hint   -> REPLY: the command line a user would type to install
# DEPS_PKGS (after deps_resolve).
deps_install_hint() {
	deps_detect
	local pkgs="${DEPS_PKGS[*]}"
	case $DEPS_FAMILY in
		debian) REPLY="sudo apt-get install $pkgs" ;;
		rhel | fedora)
			if ((DEPS_EPEL)); then
				REPLY="sudo dnf install epel-release && sudo dnf install $pkgs"
			else
				REPLY="sudo dnf install $pkgs"
			fi
			;;
		*) REPLY=$pkgs ;;
	esac
}

_deps_pkg_tool() {
	if have dnf; then REPLY='dnf'; elif have yum; then REPLY='yum'; else REPLY=''; fi
	[[ -n $REPLY ]]
}

# Enable EPEL (and the CodeReady/PowerTools repository its packages may need).
_deps_enable_epel() {
	local tool arch
	_deps_pkg_tool || return 1
	tool=$REPLY
	if "$tool" -q repolist --enabled 2>/dev/null | grep -q -i '^epel'; then
		return 0
	fi
	t deps.enabling_epel
	job_note "$REPLY"
	if [[ $DEPS_ID == rhel ]]; then
		# Red Hat Enterprise Linux proper does not carry epel-release.
		arch=$(uname -m)
		job_spin "$tool" install -y \
			"https://dl.fedoraproject.org/pub/epel/epel-release-latest-${DEPS_MAJOR}.noarch.rpm" || return 1
		if have subscription-manager; then
			run_quiet subscription-manager repos --enable "codeready-builder-for-rhel-${DEPS_MAJOR}-${arch}-rpms" || true
		fi
	else
		job_spin "$tool" install -y epel-release || return 1
	fi
	# "crb" ships with epel-release and knows the right repository name.
	if have crb; then
		run_quiet crb enable || true
	fi
	return 0
}

# deps_install COMMAND...   install the packages that provide the commands.
# Returns 0 when every command is available afterwards.
deps_install() {
	local -a want=("$@") still=()
	local c tool rc=0
	deps_detect
	deps_check "${want[@]}" && return 0
	if ((EUID != 0)); then
		fail_t deps.need_root
		return 1
	fi
	deps_resolve "${DEPS_MISSING[@]}"
	if ((${#DEPS_UNAVAILABLE[@]} > 0)); then
		fail_t deps.unavailable "${DEPS_UNAVAILABLE[*]}" "$DEPS_PRETTY"
		return 1
	fi
	((${#DEPS_PKGS[@]} > 0)) || return 0
	t deps.installing "${DEPS_PKGS[*]}"
	job_note "$REPLY"
	case $DEPS_FAMILY in
		debian)
			have apt-get || {
				fail_t deps.unknown_distro "${DEPS_MISSING[*]}"
				return 1
			}
			# Refresh the package lists only when the first attempt fails
			# (stale or missing lists, as on freshly provisioned systems).
			job_spin env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${DEPS_PKGS[@]}" || rc=$?
			((rc == 130)) && return 130
			if ((rc != 0)); then
				rc=0
				job_spin env DEBIAN_FRONTEND=noninteractive apt-get update || rc=$?
				((rc == 130)) && return 130
				rc=0
				job_spin env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${DEPS_PKGS[@]}" || rc=$?
				((rc == 130)) && return 130
			fi
			;;
		rhel | fedora)
			_deps_pkg_tool || {
				fail_t deps.unknown_distro "${DEPS_MISSING[*]}"
				return 1
			}
			tool=$REPLY
			if ((DEPS_EPEL)); then
				_deps_enable_epel || {
					rc=$?
					((rc == 130)) && return 130
					fail_t deps.install_failed 'epel-release'
					return 1
				}
			fi
			job_spin "$tool" install -y "${DEPS_PKGS[@]}" || rc=$?
			((rc == 130)) && return 130
			;;
		*)
			fail_t deps.unknown_distro "${DEPS_MISSING[*]}"
			return 1
			;;
	esac
	hash -r
	for c in "${want[@]}"; do
		have "$c" || still+=("$c")
	done
	if ((${#still[@]} > 0)); then
		if ((rc != 0)); then
			fail_t deps.install_failed "${DEPS_PKGS[*]}"
		else
			fail_t deps.still_missing "${still[*]}"
		fi
		return 1
	fi
	return 0
}

#!/usr/bin/env bash
# Environment probe: records what each supported distribution actually ships,
# so that rufus-cli's assumptions about tools, packages and kernel interfaces
# are checked against real systems instead of documentation.
#
# Usage: probe.sh            (run as root inside a privileged container with
#                             /dev bind-mounted, or directly on a VM)
set -u
export LC_ALL=C DEBIAN_FRONTEND=noninteractive

section() { printf '\n===== %s =====\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

section "identity"
# shellcheck disable=SC1091
. /etc/os-release
echo "ID=${ID:-} VERSION_ID=${VERSION_ID:-} ID_LIKE=${ID_LIKE:-} PRETTY=${PRETTY_NAME:-}"
echo "kernel=$(uname -r) arch=$(uname -m) euid=$EUID"
echo "bash=$BASH_VERSION"
echo "PATH=$PATH"

COMMANDS=(lsblk blkid wipefs sfdisk fdisk findmnt losetup blockdev partx flock udevadm sgdisk parted partprobe
	mkfs.fat mkfs.vfat fatlabel fsck.fat mkntfs mkfs.ntfs ntfs-3g ntfslabel ntfsfix mkfs.exfat mkexfatfs exfatlabel
	mkfs.ext4 mke2fs e2label mkudffs udflabel wimlib-imagex 7z 7zz 7za 7zr bsdtar xorriso isoinfo genisoimage mkisofs
	rsync pv badblocks mcopy mdir curl wget xz zstd bzip2 gzip unzip eject udisksctl numfmt stdbuf awk gawk mawk sed
	file python3 sudo doas timeout od xxd hexdump iconv getent stat sha256sum md5sum sha1sum sha512sum sync mount umount
	swapoff kpartx dmsetup lsof fuser hivexregedit hivexsh syslinux extlinux grub-install grub2-install mknod tput stty
	script tmux expect locale)

show_commands() {
	local c p
	for c in "${COMMANDS[@]}"; do
		p=$(command -v "$c" 2>/dev/null) || p='-'
		printf '%-16s %s\n' "$c" "$p"
	done
}

section "commands in the base image"
show_commands

section "package installation"
FAMILY=unknown
case " ${ID:-} ${ID_LIKE:-} " in
	*" debian "* | *" ubuntu "*) FAMILY=debian ;;
	*" rhel "* | *" fedora "* | *" centos "*) FAMILY=rhel ;;
esac
echo "family=$FAMILY"

try_install() { # pkg...
	local pkg ok
	for pkg in "$@"; do
		if [[ $FAMILY == debian ]]; then
			if apt-get install -y --no-install-recommends "$pkg" >/tmp/probe-install.log 2>&1; then ok=OK; else ok=FAIL; fi
			printf '%-28s %-5s %s\n' "$pkg" "$ok" "$(dpkg-query -W -f '${Version} [${Section}]' "$pkg" 2>/dev/null)"
		else
			if dnf install -y "$pkg" >/tmp/probe-install.log 2>&1; then ok=OK; else ok=FAIL; fi
			printf '%-28s %-5s %s\n' "$pkg" "$ok" "$(rpm -q --qf '%{VERSION}-%{RELEASE} [%{VENDOR}]' "$pkg" 2>/dev/null | head -1)"
		fi
		if [[ $ok == FAIL ]]; then
			tail -3 /tmp/probe-install.log | sed 's/^/    | /'
		fi
	done
}

if [[ $FAMILY == debian ]]; then
	apt-get update >/tmp/probe-update.log 2>&1 || { echo "apt-get update FAILED"; tail -5 /tmp/probe-update.log; }
	try_install util-linux fdisk dosfstools gdisk parted e2fsprogs ntfs-3g exfatprogs exfat-utils exfat-fuse wimtools \
		udftools p7zip-full 7zip libarchive-tools xorriso genisoimage mtools rsync pv curl ca-certificates xz-utils \
		zstd bzip2 unzip eject udisks2 udev kmod file python3 sudo psmisc lsof kpartx libhivex-bin \
		bsdextrautils bsdutils locales
elif [[ $FAMILY == rhel ]]; then
	echo "--- before EPEL ---"
	try_install util-linux dosfstools gdisk parted e2fsprogs ntfs-3g ntfsprogs exfatprogs wimlib-utils udftools \
		p7zip p7zip-plugins bsdtar xorriso genisoimage mtools rsync pv curl xz zstd bzip2 unzip eject udisks2 \
		systemd-udev kmod file python3 sudo psmisc lsof kpartx hivex glibc-langpack-ja glibc-langpack-en
	echo "--- enabling EPEL ---"
	if dnf install -y epel-release >/tmp/probe-epel.log 2>&1; then echo "epel-release OK"; else echo "epel-release FAIL"; tail -3 /tmp/probe-epel.log; fi
	if have crb; then
		if crb enable >/tmp/probe-crb.log 2>&1; then echo "crb enable OK"; else echo "crb enable FAIL"; tail -3 /tmp/probe-crb.log; fi
	fi
	dnf config-manager --set-enabled crb >/dev/null 2>&1 && echo "config-manager crb OK"
	dnf config-manager --set-enabled powertools >/dev/null 2>&1 && echo "config-manager powertools OK"
	dnf repolist 2>/dev/null | sed 's/^/    | /'
	echo "--- after EPEL ---"
	try_install ntfs-3g ntfsprogs exfatprogs wimlib-utils udftools p7zip p7zip-plugins 7zip pv hivex genisoimage
fi

section "commands after installation"
show_commands

section "versions"
lsblk --version 2>&1 | head -1
sfdisk --version 2>&1 | head -1
mkfs.fat --help 2>&1 | head -1
mkfs.fat 2>&1 | head -1
mkntfs --version 2>&1 | grep -m1 -i -E 'mkntfs|ntfs' || true
ntfs-3g --version 2>&1 | head -1
mkfs.exfat -V 2>&1 | head -1
wimlib-imagex --version 2>&1 | head -1
dd --version 2>&1 | head -1
sed --version 2>&1 | head -1
awk -W version 2>&1 | head -1 || awk --version 2>&1 | head -1
readlink -f "$(command -v awk)" 2>/dev/null
find . --version 2>&1 | head -1
7z 2>&1 | sed -n '2p'
xorriso -version 2>&1 | grep -m1 -i 'xorriso version' || true
udevadm --version 2>&1 | head -1
sudo --version 2>&1 | head -1
locale -a 2>/dev/null | tr '\n' ' ' | cut -c1-300
echo

section "mkfs.fat options"
mkfs.fat --help 2>&1 | sed 's/^/    | /' | head -40

section "sfdisk options"
sfdisk --help 2>&1 | grep -E -- '--(wipe|lock|label|no-reread|no-tell-kernel|json|dump|part-|disk-id|move|force|quiet)' | sed 's/^/    | /'

section "lsblk columns"
lsblk --help 2>&1 | sed -n '/Available/,$p' | sed 's/^/    | /' | head -70

section "kernel interfaces"
echo "/dev/kvm: $(ls -la /dev/kvm 2>&1)"
echo "/sys/block: $(cd /sys/block 2>/dev/null && echo * | cut -c1-200)"
echo "/run/udev: $(ls -d /run/udev 2>&1)"
echo "udevd running: $(pgrep -a -f 'systemd-udevd|udevd' 2>/dev/null | head -2 | tr '\n' ';')"
echo "filesystems: $(tr '\n' ' ' </proc/filesystems | tr -s '\t ' ' ' | cut -c1-400)"
for m in udf isofs vfat exfat ntfs3 ntfs fuse loop nls_utf8 nls_cp437 nls_iso8859-1; do
	printf 'modinfo %-12s %s\n' "$m" "$(modinfo -F filename "$m" 2>&1 | head -1)"
done
echo "loop max_part: $(cat /sys/module/loop/parameters/max_part 2>&1)"

section "loop device round trip"
IMG=/tmp/probe-disk.img
rm -f "$IMG"
truncate -s 300M "$IMG"
LOOP=$(losetup --show -f -P "$IMG" 2>&1) || { echo "losetup failed: $LOOP"; LOOP=''; }
echo "loop=$LOOP"
if [[ -n $LOOP && -b $LOOP ]]; then
	base=${LOOP##*/}
	echo "--- lsblk -P (whole device) ---"
	lsblk -P -b -d -o NAME,KNAME,PKNAME,TYPE,SIZE,TRAN,RM,HOTPLUG,RO,MODEL,VENDOR,SERIAL,LABEL,FSTYPE,MOUNTPOINT,SUBSYSTEMS,PTTYPE,LOG-SEC,PHY-SEC "$LOOP" 2>&1
	echo "--- lsblk PATH / MOUNTPOINTS columns ---"
	lsblk -P -d -o NAME,PATH "$LOOP" 2>&1 | head -2
	lsblk -P -d -o NAME,MOUNTPOINTS "$LOOP" 2>&1 | head -2
	echo "--- sysfs ---"
	echo "stat: $(cat "/sys/block/$base/stat" 2>&1)"
	echo "size: $(cat "/sys/block/$base/size" 2>&1) removable: $(cat "/sys/block/$base/removable" 2>&1) ro: $(cat "/sys/block/$base/ro" 2>&1)"
	echo "--- sfdisk: GPT ---"
	printf 'label: gpt\nstart=2048, size=409600, type=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7, name="Main Data Partition"\nstart=411648, size=2048, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="UEFI:NTFS", attrs="RequiredPartition NoBlockIOProtocol"\n' |
		sfdisk --wipe always --wipe-partitions always "$LOOP" 2>&1 | tail -8
	sfdisk --dump "$LOOP" 2>&1
	echo "--- partition nodes ---"
	partx -u "$LOOP" 2>&1; blockdev --rereadpt "$LOOP" 2>&1; sleep 1
	ls -la "${LOOP}"p* 2>&1
	(cd "/sys/block/$base/" && echo *)
	P1="${LOOP}p1"
	if [[ ! -b $P1 && -r /sys/block/$base/${base}p1/dev ]]; then
		echo "partition node missing; sysfs says dev=$(cat "/sys/block/$base/${base}p1/dev")"
	fi
	if [[ -b $P1 ]]; then
		echo "--- mkfs.fat ---"
		mkfs.fat -F 32 -n "PROBE" -s 8 -h 2048 "$P1" 2>&1 | tail -3
		blkid "$P1" 2>&1
		blkid -p -o export "$P1" 2>&1 | tr '\n' ' '
		echo
		mkdir -p /tmp/probe-mnt
		if mount -t vfat -o rw,utf8,shortname=mixed "$P1" /tmp/probe-mnt 2>&1; then
			echo "mounted: $(findmnt -n -o SOURCE,FSTYPE,OPTIONS /tmp/probe-mnt 2>&1)"
			dd if=/dev/urandom of=/tmp/probe-mnt/data.bin bs=1M count=20 2>&1 | tail -1
			sync
			echo "stat after 20MiB write: $(cat "/sys/block/$base/stat" 2>&1)"
			lsblk -P -b -o NAME,TYPE,SIZE,FSTYPE,LABEL,MOUNTPOINT "$LOOP" 2>&1
			umount /tmp/probe-mnt 2>&1 && echo "unmounted"
		fi
		if have mkntfs; then
			echo "--- mkntfs ---"
			mkntfs -Q -F -L "PROBE NTFS" -c 4096 "$P1" 2>&1 | tail -4
			blkid "$P1" 2>&1
			if have ntfs-3g && mount -t ntfs-3g -o rw,noatime "$P1" /tmp/probe-mnt 2>&1; then
				echo "ntfs-3g mounted: $(findmnt -n -o SOURCE,FSTYPE /tmp/probe-mnt 2>&1)"
				umount /tmp/probe-mnt 2>&1
			fi
			if mount -t ntfs3 "$P1" /tmp/probe-mnt 2>/tmp/probe-ntfs3.log; then
				echo "ntfs3 mounted"; umount /tmp/probe-mnt
			else
				echo "ntfs3 mount failed: $(head -1 /tmp/probe-ntfs3.log)"
			fi
		fi
		if have mkfs.exfat; then
			echo "--- mkfs.exfat ---"
			mkfs.exfat -L "PROBE" "$P1" 2>&1 | tail -3
			blkid "$P1" 2>&1
			if mount -t exfat "$P1" /tmp/probe-mnt 2>/tmp/probe-exfat.log; then echo "exfat mounted"; umount /tmp/probe-mnt; else echo "exfat mount failed: $(head -1 /tmp/probe-exfat.log)"; fi
		fi
	fi
	echo "--- sfdisk: MBR ---"
	printf 'label: dos\nlabel-id: 0x12345678\nstart=2048, size=409600, type=0c, bootable\nstart=411648, size=2048, type=ef\n' |
		sfdisk --wipe always --wipe-partitions always "$LOOP" 2>&1 | tail -6
	sfdisk --dump "$LOOP" 2>&1
	blkid -p -o export "$LOOP" 2>&1 | tr '\n' ' '
	echo
	echo "--- flock on the whole-disk node ---"
	flock -n "$LOOP" true 2>&1 && echo "flock ok"
	echo "--- wipefs ---"
	wipefs -a "$LOOP" 2>&1 | tail -3
	losetup -d "$LOOP" 2>&1 && echo "detached"
fi
rm -f "$IMG"

section "UDF/ISO mount"
if have xorriso || have genisoimage || have mkisofs; then
	mkdir -p /tmp/probe-iso/sources /tmp/probe-iso/efi/boot
	echo hello >/tmp/probe-iso/sources/install.wim
	echo boot >/tmp/probe-iso/bootmgr
	if have genisoimage; then
		genisoimage -quiet -udf -V "PROBE_UDF" -o /tmp/probe.iso /tmp/probe-iso 2>&1 | tail -2
	elif have mkisofs; then
		mkisofs -quiet -udf -V "PROBE_UDF" -o /tmp/probe.iso /tmp/probe-iso 2>&1 | tail -2
	else
		xorriso -as mkisofs -quiet -V "PROBE_ISO" -o /tmp/probe.iso /tmp/probe-iso 2>&1 | tail -2
	fi
	if [[ -s /tmp/probe.iso ]]; then
		blkid /tmp/probe.iso 2>&1
		blkid -p -o export /tmp/probe.iso 2>&1 | tr '\n' ' '
		echo
		mkdir -p /tmp/probe-isomnt
		if mount -o loop,ro /tmp/probe.iso /tmp/probe-isomnt 2>&1; then
			echo "iso mounted as: $(findmnt -n -o FSTYPE /tmp/probe-isomnt)"
			find /tmp/probe-isomnt | head -8
			umount /tmp/probe-isomnt
		fi
		if mount -t udf -o loop,ro /tmp/probe.iso /tmp/probe-isomnt 2>/tmp/probe-udf.log; then
			echo "udf mount ok"; umount /tmp/probe-isomnt
		else
			echo "udf mount failed: $(head -1 /tmp/probe-udf.log)"
		fi
	fi
else
	echo "no ISO authoring tool available"
fi

section "bash features"
declare -A probe_map=([a]=1)
echo "associative arrays ok: ${probe_map[a]}"
probe_arr=()
set -u
echo "empty array expansion ok: ${#probe_arr[@]} ${probe_arr[*]:-}"
printf -v probe_t '%(%s)T' -1 && echo "printf %(...)T ok: $probe_t"
echo "EPOCHREALTIME=${EPOCHREALTIME:-unset}"
read -r -t 0.05 -u 0 _ </dev/null; echo "fractional read timeout rc=$?"
probe_v=''
# shellcheck disable=SC2034
probe_f() { local -n ref=$1; ref=nameref-ok; }
probe_f probe_v
echo "$probe_v"
printf '%d\n' "'あ" 2>&1 | head -1
LC_ALL=C.UTF-8 bash -c 's="日本語abc"; echo "len(C.UTF-8)=${#s}"; printf "%d\n" "'"'"'あ"' 2>&1
compgen -f /etc/os-rel 2>&1 | head -2

section "done"

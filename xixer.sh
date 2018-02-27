#!/usr/bin/env bash

die() { echo -e "$@" ; exit 1; }

# defaults
XIXER_HOSTNAME="xixer-$(sha1sum <<< ${RANDOM} | head -c4)"
XIXER_ROOT_PASSWORD="xixer"
DEB_ARCH="amd64"
DEB_SUITE="stretch"
DEB_MIRROR="http://ftp.us.debian.org/debian/"
TARGET_PACKAGES=(
  ca-certificates
  curl
  linux-image-${DEB_ARCH}
  live-boot
  nmap
  openssh-client
  parted
  squashfs-tools
  systemd-sysv
  tcpdump
  unzip
  xz-utils
  zip
)

for opt in "$@"; do
  case ${opt} in
    --hostname=*)
      XIXER_HOSTNAME="${opt#*=}" ; shift ;;
    --password=*)
      XIXER_ROOT_PASSWORD="${opt#*=}" ; shift ;;
    --usb-device=*)
      XIXER_USB_DEV="${opt#*=}" ; shift ;;
    --arch=*)
      DEB_ARCH="${opt#*=}" ; shift ;;
    --suite=*)
      DEB_SUITE="${opt#*=}" ; shift ;;
    --mirror=*)
      DEB_MIRROR="${opt#*=}" ; shift ;;
  esac
done

[[ -n ${XIXER_USB_DEV} ]] || \
  die "--usb-device=<device name> is required"

XIXER_ROOT=${PWD}/xixer-root
mkdir -p ${XIXER_ROOT} || \
  die "Failed to create ${XIXER_ROOT}!"

debootstrap \
  --arch=${DEB_ARCH} --variant=minbase \
  ${DEB_SUITE} ${XIXER_ROOT} ${DEB_MIRROR} || \
    die "debootstrap failed!"

chroot ${XIXER_ROOT} /bin/bash << EOF
set -e
echo ${XIXER_HOSTNAME} > /etc/hostname
chpasswd <<< "root:${XIXER_ROOT_PASSWORD}"
mount -t tmpfs none /dev/shm
rm -vf /etc/apt/sources.list /etc/apt/sources.list.d/*.list
cat > /etc/apt/sources.list.d/security.list <<EOS
deb  http://cloudfront.debian.net/debian-security  stable/updates  main contrib non-free
deb  http://cloudfront.debian.net/debian-security  testing/updates main contrib non-free
EOS
for dist in stable testing unstable experimental; do
  echo "deb  http://cloudfront.debian.net/debian ${dist} main contrib non-free" \
    > /etc/apt/sources.list.d/${dist}.list
  done
apt-get update
apt-get install -y --no-install-recommends ${TARGET_PACKAGES}
apt-get clean
umount /dev/shm
rm -rf /var/lib/apt/lists/*
EOF

[[ $? -eq 0 ]] || \
  die "Failed to configure root filesystem!"

parted /dev/${XIXER_USB_DEV} --script -- \
  'mklabel msdos mkpart primary fat32 0% 100% set 1 boot on' || \
    die "Failed to partition /dev/${XIXER_USB_DEV}!"

mkdosfs -F 32 -I /dev/${XIXER_USB_DEV}1 || \
  die "Failed to format /dev/${XIXER_USB_DEV}1!"

syslinux -i /dev/${XIXER_USB_DEV}1 || \
  die "Failed to install syslinux!"

dd conv=notrunc bs=440 count=1 if=/usr/lib/syslinux/mbr/mbr.bin \
  of=/dev/${XIXER_USB_DEV} || \
    die "Failed to install syslinux MBR to ${XIXER_USB_DEV}!"

mount /dev/${XIXER_USB_DEV}1 /mnt && mkdir /mnt/live || \
  die "Failed to mount ${XIXER_USB_DEV}!"

(cd ${XIXER_ROOT} && \
  mksquashfs . /mnt/live/filesystem.squashfs -e boot -noappend) || \
    die "Failed to create squashfs!"

cp -v ${XIXER_ROOT}/boot/vmlinuz* /mnt/live/vmlinuz || \
  die "Failed to copy kernel and ramdisk!"

cp -v ${XIXER_ROOT}/boot/initrd.img* /mnt/live/initrd || \
  die "Failed to copy kernel and ramdisk!"

tar -C /usr/lib/syslinux/modules/bios -cf - \
  menu.c32 hdt.c32 ldlinux.c32 libutil.c32 libmenu.c32 \
  libcom32.c32 libgpl.c32 | tar -C /mnt -xf - || \
    die "Failed to copy syslinux files!"

cp /boot/memtest86+.bin /mnt/live/memtest || \
  die "Failed to copy memtest86"

cp /usr/share/misc/pci.ids /mnt || \
  die "Failed to copy pci.ids"

cp /xixer/syslinux.cfg /mnt || \
  die "Failed to copy syslinux.cfg"

umount /mnt
sync

echo "DONE!!"

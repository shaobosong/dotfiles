#!/usr/bin/env bash

set -e

USER="user"
PASSWD="123456"
SHADOW_PASSWD=$(openssl passwd -6 "${PASSWD}")

TEMP_ROOTFS_DIR=$(mktemp -d)
NBD_DEVICE=/dev/nbd0

ROOTFS_IMAGE=rootfs.qcow2
ROOTFS_IMAGE_SIZE=64G

QEMU_IMG=${QEMU_IMG:-qemu-img}
QEMU_NBD=${QEMU_NBD:-qemu-nbd}

EXIT_CODE=1

function check_uid() {
    echo "Checking if uid is 0..."
    if test $(id -u) -ne 0; then
        echo "Please run this with 'root' privilege." >&2
        exit 1
    fi
}

function create_image() {
    echo "Creating qcow2 format image..."
    ${QEMU_IMG} create -f qcow2 $ROOTFS_IMAGE $ROOTFS_IMAGE_SIZE
}

# image ---- device ---- mountpoint
function image_nbd_rootfs() {
    modprobe nbd
    # image ---- device
    echo "Connecting $ROOTFS_IMAGE to $NBD_DEVICE..."
    ${QEMU_NBD} -c $NBD_DEVICE $ROOTFS_IMAGE
    # partition
    # cfdisk $NBD_DEVICE
    mkfs.ext4 $NBD_DEVICE
    #            device ---- mountpoint
    echo "Attaching the filesystem on $NBD_DEVICE at $TEMP_ROOTFS_DIR..."
    mount $NBD_DEVICE $TEMP_ROOTFS_DIR
}

function _download_rootfs() {
    echo "Downloading rootfs..."
    temp_rootfs_dir=$1
    # debian()
    # debootstrap \
    # 	--no-check-gpg \
    # 	sid \
    # 	$temp_rootfs_dir \
    # 	http://deb.debian.org/debian

    # ubuntu
    # debootstrap \
    # 	--no-check-gpg \
    # 	jammy \
    # 	$temp_rootfs_dir \
    # 	http://archive.ubuntu.com/ubuntu

    # ubuntu
    # debootstrap \
    # 	--no-check-gpg \
    # 	jammy \
    # 	$temp_rootfs_dir \
    # 	https://mirrors.tuna.tsinghua.edu.cn/ubuntu

    # ubuntu
    # mmdebstrap \
    # 	--variant=standard \
    # 	noble \
    # 	$temp_rootfs_dir \
    # 	http://mirrors.aliyun.com/ubuntu

    # voidlinux
    test ! -f rootfs.tar.xz && curl -Ljo rootfs.tar.xz https://repo-default.voidlinux.org/live/current/void-x86_64-ROOTFS-20250202.tar.xz
    # test ! -f void-x86_64-musl-ROOTFS.tar.xz && curl -Ljo rootfs.tar.xz https://repo-default.voidlinux.org/live/current/void-x86_64-ROOTFS-20250202.tar.xz
    echo "Unarchiving rootfs..."
    tar -C $temp_rootfs_dir -xJf rootfs.tar.xz
    # tar -C $temp_rootfs_dir -xJf void-x86_64-musl-ROOTFS.tar.xz
}

function _chroot_run() {
    /usr/sbin/chroot $TEMP_ROOTFS_DIR <<< "$@"
}

function _update_rootfs() {
    echo "Updating rootfs..."
    # generic
    _chroot_run "chsh -s /bin/bash root"
    _chroot_run "useradd -m -s /bin/bash ${USER}"
    _chroot_run "sed -i 's|^\(${USER}\):[^:]*:|\1:${SHADOW_PASSWD}:|' /etc/shadow"

    # Error: have a problem
    # _chroot_run "echo 'root:$PASSWD' | chpasswd --root /"
    # _chroot_run "echo 'user:$PASSWD' | chpasswd --root /"
    # echo "root:$PASSWD" | chpasswd --root $(readlink -e $TEMP_ROOTFS_DIR)
    # echo "user:$PASSWD" | chpasswd --root $(readlink -e $TEMP_ROOTFS_DIR)

    # # debian 12
    # _chroot_run "usermod -aG sudo user"
    # _chroot_run "echo -e 'auto enp0s3\niface enp0s3 inet dhcp' > /etc/network/interfaces"

    # # debian sid
    # _chroot_run "echo -e '[Match]\nName=enp0s3\n[Network]\nDHCP=yes' > /etc/systemd/network/20-wired.network"

    # # ubuntu
    # _chroot_run "echo -e 'network:\n  version: 2\n  ethernets:\n    enp0s3:\n      dhcp4: true' > /etc/netplan/01-netcfg.yaml"

    # voidlinux
    _chroot_run "usermod -aG wheel ${USER}"
    _chroot_run "sed -i 's/^#\s*\(%wheel\s\+ALL=(ALL:ALL)\s\+ALL\)/\1/' /etc/sudoers"
    _chroot_run "cp /usr/share/xbps.d/*-repository-*.conf /etc/xbps.d/"
    _chroot_run "sed -i 's|https://repo-default.voidlinux.org|https://mirrors.tuna.tsinghua.edu.cn/voidlinux|g' /etc/xbps.d/*-repository-*.conf"
    # _chroot_run "rm -rf /etc/runit/runsvdir/default/agetty-tty*"
    _chroot_run "sed -i 's/^TERM_NAME=.*$/TERM_NAME=xterm-256color/' /etc/sv/agetty-hvc0/conf"
    _chroot_run "ln -sfn /etc/sv/agetty-hvc0 /etc/runit/runsvdir/default/agetty-hvc0"
    _chroot_run "ln -sfn /etc/sv/agetty-ttyS0 /etc/runit/runsvdir/default/agetty-ttyS0"
    _chroot_run "ln -sfn /etc/sv/dhcpcd /etc/runit/runsvdir/default/dhcpcd"
    _chroot_run "ln -sfn /etc/sv/sshd /etc/runit/runsvdir/default/sshd"
}

function create_rootfs() {
    _download_rootfs $TEMP_ROOTFS_DIR

    # mkdir -p $TEMP_ROOTFS_DIR/dev \
    # 	$TEMP_ROOTFS_DIR/proc \
    # 	$TEMP_ROOTFS_DIR/sys
    # mount --bind /dev $TEMP_ROOTFS_DIR/dev
    # mount --bind /proc $TEMP_ROOTFS_DIR/proc
    # mount --bind /sys $TEMP_ROOTFS_DIR/sys

    _update_rootfs
}

function _umount_checked() {
    if mountpoint -q "$@"; then
        umount "$@"
    fi
}

function cleanup() {
    # _umount_checked $TEMP_ROOTFS_DIR/dev || :
    # _umount_checked $TEMP_ROOTFS_DIR/proc || :
    # _umount_checked $TEMP_ROOTFS_DIR/sys || :

    _umount_checked $TEMP_ROOTFS_DIR || :
    rm -rf $TEMP_ROOTFS_DIR || :
    ${QEMU_NBD} -d $NBD_DEVICE || :
    # modprobe -r nbd || :

    if test $EXIT_CODE -eq 0; then
        echo "Succeed"
    else
        echo "Failed"
    fi
}

check_uid
create_image
trap cleanup EXIT
image_nbd_rootfs
create_rootfs

EXIT_CODE=0

#!/usr/bin/env -S bash -e

set -o xtrace

DISK=/dev/disk/by-id/usb-WD_My_Passport_0748_575833314331323531313238-0:0

# # Partition sizes
# ESP=2G
# SWAP=8G

# # Create partitions
# sgdisk --zap-all $DISK
# sgdisk -n1:1M:+${ESP}     -t1:EF00 $DISK # ESP
# sgdisk -n2:0:+${SWAP}     -t2:8200 $DISK # Swap
# sgdisk -n3:0:0            -t3:BE00 $DISK # ZFS Pool

# sync
# sleep 10

# # Create pool
# zpool create \
#   -o compatibility=grub2 \
#   -o ashift=12 \
#   -o autotrim=on \
#   -O acltype=posixacl \
#   -O canmount=off \
#   -O compression=lz4 \
#   -O devices=off \
#   -O normalization=formD \
#   -O atime=off \
#   -O xattr=sa \
#   -O mountpoint=/ \
#   -O sync=disabled \
#   -R /mnt \
#   -f \
#   zpool \
#   ${DISK}-part3

# # Create datasets
# zfs create -o canmount=noauto -o mountpoint=/     zpool/root
# zfs snapshot zpool/root@clean
# zfs mount zpool/root
# zfs create -o canmount=off    -o mountpoint=/     zpool/KEEP
# zfs create -o canmount=on                         zpool/KEEP/root
# zfs create -o canmount=on                         zpool/KEEP/state
# zfs create -o canmount=on                         zpool/KEEP/nix

# chmod 700 /mnt/root

# mkdir -p /mnt/state/etc/nixos /mnt/etc/nixos \
#          /mnt/state/etc/cryptkey.d /mnt/etc/cryptkey.d \
#          /mnt/state/var/log /mnt/var/log
# mount -o bind /mnt/state/etc/nixos /mnt/etc/nixos
# mount -o bind /mnt/state/etc/cryptkey.d /mnt/etc/cryptkey.d
# mount -o bind /mnt/state/var/log /mnt/var/log

# # Format and mount ESP
# mkfs.vfat -n EFI $DISK-part1
# mkdir /mnt/boot
# mount -t vfat $DISK-part1 /mnt/boot

# # Disable ZFS cache
# mkdir -p /mnt/state/etc/zfs/
# rm -f /mnt/state/etc/zfs/zpool.cache
# touch /mnt/state/etc/zfs/zpool.cache
# chmod a-w /mnt/state/etc/zfs/zpool.cache
# chattr +i /mnt/state/etc/zfs/zpool.cache

# cp configuration.nix id_ed25519.pub /mnt/etc/nixos/

# Pre-install snapshot
zfs snapshot -r zpool/KEEP@before_install

nixos-install -v --show-trace --no-root-passwd --option system aarch64-linux --root /mnt

zfs snapshot -r zpool/KEEP@after_install

umount /mnt/boot
umount /mnt/var/log
umount /mnt/etc/cryptkey.d
umount /mnt/etc/nixos
zfs unmount zpool/KEEP/root
zfs unmount zpool/KEEP/state
zfs unmount zpool/KEEP/nix
zfs unmount zpool/root

zpool export zpool

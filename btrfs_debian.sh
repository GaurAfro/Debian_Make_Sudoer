#!/bin/sh
# Unmount if already mounted
umount /target/boot/efi/
umount /target/

# Perform the mounting operations
mount /dev/sda2 /mnt/

cd /mnt/
mv @rootfs @
btrfs subvolume create @home
mount -o rw,noatime,space_cache=v2,compress-zstd,ssd,discard=async,subvol=@ /dev/sda2 /target/
# Ensure the necessary directories exist
mkdir -p /target/boot/efi/ /target/home/
mount -o rw,noatime,space_cache=v2,compress-zstd,ssd,discard=async,subvol=@home /dev/sda2 /target/home/
mount /dev/sda1 /target/boot/efi/

# Get UUID of /dev/sda2
UUID=$(blkid -s UUID -o value /dev/sda2)

# Update /etc/fstab for rootfs and @home
grep -q "UUID=$UUID / btrfs" /etc/fstab && \
sed -i "s|UUID=$UUID / btrfs.*|UUID=$UUID / btrfs rw,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvol=@ 0 0|" /etc/fstab || \
echo "UUID=$UUID / btrfs rw,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvol=@ 0 0" >> /etc/fstab

echo "UUID=$UUID /home btrfs rw,noatime,space_cache=v2,compress=zstd,ssd,discard=async,subvol=@home 0 0" >> /etc/fstab

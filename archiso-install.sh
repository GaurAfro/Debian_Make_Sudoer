#!/usr/bin/env bash

set -xeuo pipefail

# Define your color variables for pretty printf statements
# these are used like this: printf "%bThis is red text.%b\n" "${RED}" "${NC}"
# these are used like this: printf "%bThis is %b%s%b string hilighted.%b\n" "${GREEN}" "${YELLOW}" "${VAR_STRING}" "${GREEN}" "${NC}"
# %b is for the color variable
# %s is for the string variable
# and they are used in the order they are defined in the printf statement
export RED='\033[0;31m' # Red color (for errors)
export YELLOW='\033[1;33m' # Yellow color (for warnings and hints)
export GREEN='\033[0;32m' # Green color (for success)
export NC='\033[0m' # No Color (to reset the terminal color)

# Load environment variables from file
printf "%bLoading environment variables from file if it exists.%b\n" "${YELLOW}" "${NC}"
if [ -f ./archiso-install.env ]; then
  source ./archiso-install.env
fi

# Global variables
: "${GH_TOKEN:=}"
: "${USER_EMAIL:=}"
: "${USER_NAME:=}"
: "${USER_PASSWORD:=}"
: "${CRYPTLVM_PASSWORD:=}"
: "${HOSTNAME:=}"
: "${rootmnt:=}"
: "${LOCALE:="en_US.UTF-8"}"
: "${TIMEZONE:="Europe/Amsterdam"}"
: "${KEYMAP:="us"}"

# Set the target disk to install to based on the virtualization platform or disk type
if [[ $(systemd-detect-virt) == "kvm" ]]; then
  printf "%bDetected KVM, setting target disk to /dev/vda%b\n" "${YELLOW}" "${NC}"
  : "${TARGET:="/dev/vda"}"
else
  if [[ $(lsblk -d -o name | grep -E "^nvme") ]]; then
    printf "%bDetected NVME, setting target disk to /dev/nvme0n1%b\n" "${YELLOW}" "${NC}"
    : "${TARGET:="/dev/nvme0n1"}"
  else
    printf "%bDetected non-NVME, setting target disk to /dev/sda%b\n" "${YELLOW}" "${NC}"
    : "${TARGET:="/dev/sda"}"
  fi
fi

export GH_TOKEN="${GH_TOKEN}"
export USER_EMAIL="${USER_EMAIL}"
export USER_NAME="${USER_NAME}"
export USER_PASSWORD="${USER_PASSWORD}"
export CRYPTLVM_PASSWORD="${CRYPTLVM_PASSWORD}"
export HOSTNAME="${HOSTNAME}"
export rootmnt="${rootmnt}"
export TARGET="${TARGET}"
export LOCALE="${LOCALE}"
export TIMEZONE="${TIMEZONE}"
export KEYMAP="${KEYMAP}"


# BTRFS Variables
BTRFS_MOUNT_OPTS="rw,noatime,space_cache=v2,ssd,discard=async,compress=zstd:5"
SYS_ROOT="/dev/MyLinuxVolGroup/base"

# Function to create partitions
partition_disk() {
  parted --script "${TARGET}" mklabel gpt
  parted --script "${TARGET}" mkpart primary fat32 0% 512mib
  parted --script "${TARGET}" set 1 esp on
  parted --script "${TARGET}" name 1 ESP
  parted --script "${TARGET}" mkpart primary ext4 512mib 2048mib
  parted --script "${TARGET}" name 2 BOOT
  parted --script "${TARGET}" mkpart primary 2048mib 95%
  parted --script "${TARGET}" name 3 LINUX
}

# Function to format boot partitions
format_boot_partitions() {
  mkfs.fat -F32 -n ESP /dev/disk/by-partlabel/ESP
  mkfs.ext4 -F -L BOOT /dev/disk/by-partlabel/BOOT
}

# Function to setup LUKS
setup_luks() {
  echo -n "${CRYPTLVM_PASSWORD}" | cryptsetup luksFormat --label=cryptlvm --type luks2 /dev/disk/by-partlabel/LINUX -
  echo -n "${CRYPTLVM_PASSWORD}" | cryptsetup luksOpen /dev/disk/by-partlabel/LINUX cryptlvm -
  cryptsetup refresh \
        --allow-discards \
        --perf-no_read_workqueue --perf-no_write_workqueue \
        --persistent \
        root
}

# Function to setup LVM
setup_lvm() {
  pvcreate /dev/mapper/cryptlvm
  vgcreate MyLinuxVolGroup /dev/mapper/cryptlvm
}

# # Function to create a swapfile on LVM
# create_swapfile() {
#   lvcreate -L 4GB MyLinuxVolGroup -n swap
#   mkswap /dev/MyLinuxVolGroup/swap
#   swapon /dev/MyLinuxVolGroup/swap
# }

# Function to create a BTRFS root partition on LVM
create_root_btrfs_partition() {
  lvcreate -l 90%FREE MyLinuxVolGroup -n base
  mkfs.btrfs -f "${SYS_ROOT}"
  mount -t btrfs "${SYS_ROOT}" "${rootmnt}"
}

# Function to create a BTRFS subvolume
create_btrfs_subvol() {
  local subvol_path=$1
  local subvol_name=$2

  if ! btrfs subvolume show "$subvol_path" > /dev/null 2>&1; then
    printf "%bCreating subvolume: %s%b\n" "${YELLOW}" "$subvol_name" "${NC}"
    btrfs subvolume create "$subvol_path"
  fi
}

# Function to remount a BTRFS subvolume
remount_btrfs_subvol() {
  local subvol_name=$1
  local mount_path="${subvol_paths[$subvol]}"
  local subvol_id

  # Fetch subvolume ID
  subvol_id=$(btrfs subvolume list "$rootmnt" | awk -v subvol="$subvol_name" '$0 ~ subvol {print $2; exit}')

  # Mount subvolume using its ID
  if [[ -n "$mount_path" ]] && ! mountpoint -q "$mount_path"; then
    printf "%bMounting subvolume: %s at %s with ID %s%b\n" "${YELLOW}" "$subvol_name" "$mount_path" "$subvol_id" "${NC}"
    mkdir -p "$mount_path"
    mount -t btrfs -o "$BTRFS_MOUNT_OPTS,subvolid=$subvol_id" "$SYS_ROOT" "$mount_path"
  fi
}

# Function to create and remount all BTRFS subvolumes
create_and_remount_btrfs_subvols() {
  # Create the @ subvolume
  create_btrfs_subvol "$rootmnt/@" "@"
  top_level_id=$(btrfs subvolume list -o "$rootmnt" | awk '/path @$/ {print $2; exit}')

  # Array for other subvolumes
  declare -a other_subvols=("@home" "@snapshots" "@root" "@srv" "@opt" "@cache" "@log" "@tmp" "@skel")
  declare -A subvol_paths=(
    ["@home"]="$rootmnt/home"
    ["@snapshots"]="$rootmnt/.snapshots"
    ["@root"]="$rootmnt/root"
    ["@srv"]="$rootmnt/srv"
    ["@opt"]="$rootmnt/opt"
    ["@cache"]="$rootmnt/var/cache"
    ["@log"]="$rootmnt/var/log"
    ["@tmp"]="$rootmnt/var/tmp"
    ["@skel"]="$rootmnt/etc/skel"
  )


  # Create other subvolumes
  for subvol in "${other_subvols[@]}"; do
    create_btrfs_subvol "$rootmnt/$subvol" "$subvol"
  done

  # Unmount the root device
  umount -R "$rootmnt"

  # Remount the @ subvolume first
  mount -t btrfs -o "${BTRFS_MOUNT_OPTS},subvolid=$top_level_id" "${SYS_ROOT}" "${rootmnt}"

  # Remount other subvolumes
  for subvol in "${other_subvols[@]}"; do
    remount_btrfs_subvol "$subvol" "$rootmnt/$subvol"
  done
}

# Mount the EFI and boot partition
mount_efi_boot() {
  printf "%bCreate directories for boot and efi partitions and mount them %b\n" "${YELLOW}" "${NC}"
  mkdir -p "$rootmnt"/boot && mount -v -t ext4 /dev/disk/by-partlabel/BOOT "$rootmnt"/boot
  mkdir -p "$rootmnt"/boot/efi && mount -v -t vfat /dev/disk/by-partlabel/ESP "$rootmnt"/boot/efi
}

# Mount the tmpfs partition
mount_tmpfs() {
  printf "%bCreate directories for tmpfs partitions and mount them%b\n" "${YELLOW}" "${NC}"
  mkdir -p "$rootmnt"/tmp && mount -v -o defaults,noatime,mode=1777 -t tmpfs tmpfs "$rootmnt"/tmp
}

# Function to install packages
install_base_system() {
  # Generate mirrorlist on the host system for my country
  # (The live disk runs reflector, but with global mirror selection).
  # pacstrap then copies this mirrorlist to the new root
  printf "%bBootstrapping the base system%b\n" "${YELLOW}" "${NC}"
  sed -i \
    -e '/^#Color/s/^#//' \
    -e '/^#VerbosePkgLists/s/^#//' \
    -e '/^#ParallelDownloads/{s/^#//;s/[0-9]*$/8\nILoveCandy\nDisableDownloadTimeout/;}' \
    -e '/^#\[multilib\]/,/^Include/{/^#Include = \/etc\/pacman.d\/mirrorlist/s/^#//}' \
    -e '/^#\[multilib\]/s/^#//' \
    /etc/pacman.conf

  reflector --save /etc/pacman.d/mirrorlist --protocol https --country Netherlands --latest 5 --sort age


  bootstrap_packages=(
    base
    base-devel
    binutils
    btrfs-progs
    cryptsetup
    curl
    efibootmgr
    expect
    fish
    git
    github-cli
    grub
    grub-btrfs
    intel-ucode
    jq
    linux
    linux-firmware
    lvm2
    neovim
    networkmanager
    openssh
    reflector
    terminus-font
    unzip
    vim
    zram-generator
  )
  pacstrap -K "$rootmnt" "${bootstrap_packages[@]}"
}

# Function to configure system settings
configure_core_system() {
  printf "%bGenerate fstab%b" "${YELLOW}" "${NC}"
  genfstab -U "$rootmnt" >> "$rootmnt"/etc/fstab

  # Enable NetworkManager service
  printf "%bEnable NetworkManager service%b" "${YELLOW}" "${NC}"
  systemctl --root "$rootmnt" enable NetworkManager

  # Install GRUB bootloader
  printf "%bInstall GRUB bootloader%b" "${YELLOW}" "${NC}"
  arch-chroot "$rootmnt" grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB

  # Update GRUB for target encryption
  printf "%bUpdate GRUB for target encryption%b" "${YELLOW}" "${NC}"
  UUID=$(blkid -s UUID -o value /dev/disk/by-partlabel/LINUX)
  # arch-chroot "$rootmnt" sed -i -e "s|^GRUB_CMDLINE_LINUX=.*$|GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${UUID}:cryptlvm root=/dev/MyLinuxVolGroup/root\"|" /etc/default/grub
  arch-chroot "$rootmnt" sed -i -e "s|^GRUB_CMDLINE_LINUX=.*$|GRUB_CMDLINE_LINUX=\"rd.luks.name=${UUID}=cryptlvm root=/dev/MyLinuxVolGroup/base\"|" /etc/default/grub

  # Generate GRUB configuration file
  printf "%bGenerate GRUB configuration file%b" "${YELLOW}" "${NC}"
  arch-chroot "$rootmnt" grub-mkconfig -o /boot/grub/grub.cfg

  # arch-chroot "$rootmnt" sed -i -e "s|^HOOKS=.*$|HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block encrypt lvm2 btrfs filesystems fsck)|" /etc/mkinitcpio.conf
  printf "%bGenerate initramfs%b" "${YELLOW}" "${NC}"
  arch-chroot "$rootmnt" sed -i -e "s|^HOOKS=.*$|HOOKS=(base systemd autodetect modconf kms keyboard sd-vconsole block sd-encrypt lvm2 filesystems btrfs fsck)|" /etc/mkinitcpio.conf


  # Set console font
  printf "%bSet console font%b" "${YELLOW}" "${NC}"
  echo 'FONT=ter-132b' | arch-chroot "$rootmnt" tee -a /etc/vconsole.conf > /dev/null

  # Update pacman.conf
  printf "%bUpdate pacman.conf%b" "${YELLOW}" "${NC}"
  sed -i \
    -e '/^#Color/s/^#//' \
    -e '/^#VerbosePkgLists/s/^#//' \
    -e '/^#ParallelDownloads/{s/^#//;s/[0-9]*$/8\nILoveCandy\nDisableDownloadTimeout/;}' \
    -e '/^#\[multilib\]/,/^Include/{/^#Include = \/etc\/pacman.d\/mirrorlist/s/^#//}' \
    -e '/^#\[multilib\]/s/^#//' \
    "$rootmnt/etc/pacman.conf"

  # Update mirrorlist
  printf "%bUpdate mirrorlist%b" "${YELLOW}" "${NC}"
  arch-chroot "$rootmnt" curl -o /etc/pacman.d/mirrorlist https://archlinux.org/mirrorlist/all/

  # Sort and save mirrorlist
  printf "%bSort and save mirrorlist%b" "${YELLOW}" "${NC}"
  reflector -c Netherlands -p https -a 5 --sort rate --save "$rootmnt"/etc/pacman.d/mirrorlist

  # Place this configuration on the target installed system, not the live environment
  printf "%bSet zram-generator configuration%b" "${YELLOW}" "${NC}"
  echo -e "[zram0]\nzram-fraction=0.25\nmax-zram-size=4096\ncompression-algorithm=zstd" | arch-chroot "$rootmnt" tee /etc/systemd/zram-generator.conf

  # Set hardware clock
  printf "%bSet hardware clock%b" "${YELLOW}" "${NC}"
  arch-chroot "$rootmnt" hwclock --systohc

  # Set Timezone
  printf "%bSet Timezone%b" "${YELLOW}" "${NC}"
  arch-chroot "$rootmnt" ln -sf /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime

  # Set locale information
  printf "%bSet locale information%b" "${YELLOW}" "${NC}"
  sed -i \
    -e '/^#en_US.UTF-8/s/^#//' \
    -e '/^#nl_NL.UTF-8/s/^#//' \
    "$rootmnt"/etc/locale.gen

  # Set the target systems locale settings /etc/locale.conf
  # Setting the LANG to en_US.UTF-8
  # Setting the LC_TIME to nl_NL.UTF-8
  # Setting the LC_MONETARY to nl_NL.UTF-8
  printf "%bSet the target systems locale settings%b" "${YELLOW}" "${NC}"
  cat <<EOF>"$rootmnt"/etc/locale.conf
LANG=en_US.UTF-8
LC_TIME=nl_NL.UTF-8
LC_MONETARY=nl_NL.UTF-8
EOF

  # Generate locale information
  printf "%bGenerate locale information%b" "${YELLOW}" "${NC}"
  arch-chroot "$rootmnt" locale-gen

  #create a basic kernel cmdline, we're using DPS so we don't need to have anything here really, but if the file doesn't exist, mkinitcpio will complain
  printf "%bCreate a basic kernel cmdline%b" "${YELLOW}" "${NC}"
  echo "quiet rw" > "$rootmnt"/etc/kernel/cmdline

  # Generate initramfs
  printf "%bGenerate initramfs%b" "${YELLOW}" "${NC}"
  arch-chroot "$rootmnt" mkinitcpio -P
}

# Function to perform final steps and cleanup
finalize_installation() {

  # Generate hashed user password using OpenSSL
  USER_HASHED_PASSWORD=$(openssl passwd -6 -salt "$(openssl rand -base64 12)" "${USER_PASSWORD}")

  arch-chroot "$rootmnt" groupadd autologin

  # Create a new user and add it to all the groups, set the shell to fish and set the password
  printf "%bCreate a new user and add it to all the groups, set the shell to fish and set the password%b" "${YELLOW}" "${NC}"
  arch-chroot "$rootmnt" useradd -m -G wheel,audio,video,power,autologin -s /usr/bin/fish -p "${USER_HASHED_PASSWORD}" "$USER_NAME"

  # Create a sudoers file for the new user
  echo "${USER_NAME} ALL=(ALL:ALL) NOPASSWD: ALL" | arch-chroot "$rootmnt" tee "/etc/sudoers.d/${USER_NAME}"

  # Set correct permissions for the sudoers file
  arch-chroot "$rootmnt" chmod 0440 "/etc/sudoers.d/${USER_NAME}"

  # Modify getty service for automatic login
  arch-chroot "$rootmnt" sed -i "s|^ExecStart=-/sbin/agetty.*$|ExecStart=-/sbin/agetty -a ${USER_NAME} - \$TERM|" /usr/lib/systemd/system/getty@.service

  # Set hostname
  printf "%bSet hostname%b" "${YELLOW}" "${NC}"
  echo "$HOSTNAME" | arch-chroot "$rootmnt" tee /etc/hostname > /dev/null

  # Set hosts file
  printf "%bSet hosts file%b" "${YELLOW}" "${NC}"
  cat <<EOF >"$rootmnt/etc/hosts"
# Standard host addresses
127.0.0.1  localhost
::1        localhost ip6-localhost ip6-loopback
ff02::1    ip6-allnodes
ff02::2    ip6-allrouters
# This host address
127.0.1.1 ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

# https://vault.bitwarden.com/download/?app=cli&platform=linux
  # Enable SSH service
  arch-chroot "$rootmnt" mkdir -p /home/"${USER_NAME}"/.ssh
  echo -e "Host github.com\n  HostName github.com\n  User git\n  AddKeysToAgent yes\n  IdentityFile ~/.ssh/id_ed25519" | arch-chroot "$rootmnt" tee -a /home/"${USER_NAME}"/.ssh/config
  arch-chroot "$rootmnt" ssh-keygen -t ed25519 -C "${USER_EMAIL}" -f /home/"${USER_NAME}"/.ssh/id_ed25519 -q -N ""
  arch-chroot "$rootmnt" chmod 700 /home/"${USER_NAME}"/.ssh
  arch-chroot "$rootmnt" chmod 600 /home/"${USER_NAME}"/.ssh/config
  arch-chroot "$rootmnt" chmod 600 /home/"${USER_NAME}"/.ssh/id_ed25519

  arch-chroot "$rootmnt" mkdir -p /etc/fish/conf.d
  echo -e "if status --is-login\n  if test -z \"\$DISPLAY\" -a (tty) = \"/dev/tty1\"\n    exec startx\n  end\nend" | arch-chroot "$rootmnt" tee /etc/fish/conf.d/autostartx.fish
  echo -e "if command -sq nvim\n  set -gx EDITOR nvim\nend" | arch-chroot "$rootmnt" tee /etc/fish/conf.d/editor.fish
  echo -e "if command -sq kitty\n  set -gx TERM xterm-kitty\nend" | arch-chroot "$rootmnt" tee /etc/fish/conf.d/term.fish
  echo -e "set running_ssh_agents (pgrep -f ssh-agent)\n\nif test (count \$running_ssh_agents) -gt 0\n    if not contains -- \$SSH_AGENT_PID \$running_ssh_agents\n        killall ssh-agent\n        set -e SSH_AUTH_SOCK\n        set -e SSH_AGENT_PID\n    end\nend\n\nif not set -q SSH_AGENT_PID\n    killall ssh-agent\n    set -Ux SSH_AUTH_SOCK (ssh-agent -c | grep -o -m 1 '/tmp/ssh-[^/]*/agent.[0-9]*')\n    set -Ux SSH_AGENT_PID (pgrep -f ssh-agent)\nend\n" | arch-chroot "$rootmnt" tee /etc/fish/conf.d/ssh-agent.fish
  arch-chroot "$rootmnt" mkdir -p /home/"${USER_NAME}"/.config/fish/conf.d
  cat <<EOF >"$rootmnt"/home/"${USER_NAME}"/.config/fish/conf.d/gh-token.fish
if command -sq gh && test -z \$GH_TOKEN && test (logname) = "${USER_NAME}"
    set -gx GH_TOKEN "${GH_TOKEN}"
end
EOF

  arch-chroot "$rootmnt" chmod 600 /home/"${USER_NAME}"/.config/fish/conf.d/gh-token.fish

  # Set the default git and gh credentials
  cat << _EOF_ >"$rootmnt"/home/"${USER_NAME}"/.gitconfig
[user]
    name = "${USER_NAME}"
    email = "${USER_EMAIL}"
[credential "https://github.com"]
    helper =
    helper = !/usr/bin/gh auth git-credential
[credential "https://gist.github.com"]
    helper =
    helper = !/usr/bin/gh auth git-credential
_EOF_

  arch-chroot "$rootmnt" mkdir -p /home/"${USER_NAME}"/.config/gh
  cat << _EOF_ >"$rootmnt"/home/"${USER_NAME}"/.config/gh/hosts.yml
github.com:
    user: GaurAfro
    git_protocol: ssh
_EOF_

  cat << _EOF_ >"$rootmnt"/home/"${USER_NAME}"/.config/gh/config.yml
# What protocol to use when performing git operations. Supported values: ssh, https
git_protocol: ssh
# What editor gh should run when creating issues, pull requests, etc. If blank, will refer to environment.
editor:
# When to interactively prompt. This is a global config that cannot be overridden by hostname. Supported values: enabled, disabled
prompt: enabled
# A pager program to send command output to, e.g. "less". Set the value to "cat" to disable the pager.
pager:
# Aliases allow you to create nicknames for gh commands
aliases:
    co: pr checkout
# The path to a unix socket through which send HTTP connections. If blank, HTTP traffic will be handled by net/http.DefaultTransport.
http_unix_socket:
# What web browser gh should use when opening URLs. If blank, will refer to environment.
browser:
_EOF_

  arch-chroot "$rootmnt" chown -R "${USER_NAME}":"${USER_NAME}" /home/"${USER_NAME}"/
  # Log in to GitHub with the gh CLI using the token stored in the GH_TOKEN environment variable
  printf "%bLog in to GitHub with the gh CLI using the token stored in the GH_TOKEN environment variable%b" "${YELLOW}" "${NC}"
  arch-chroot "$rootmnt" su "${USER_NAME}" -c 'gh auth status'

  # Enable SSH service
  printf "%bEnable SSH service%b" "${YELLOW}" "${NC}"
  arch-chroot "$rootmnt" systemctl enable sshd

  #lock the root account
  printf "%block the root account%b" "${YELLOW}" "${NC}"
  arch-chroot "$rootmnt" usermod -L root

  # Unmount all partitions
  printf "%bUnmount all partitions%b" "${YELLOW}" "${NC}"
  umount -R "$rootmnt"

  # Close LUKS container
  printf "%bClose LUKS container%b" "${YELLOW}" "${NC}"
  cryptsetup close root || true

  # Sync filesystem buffers
  printf "%bSync filesystem buffers%b" "${YELLOW}" "${NC}"
  sync

  # Inform the user before rebooting
  printf "%bInstallation complete. Please reboot.%b\n" "${GREEN}" "${NC}"
  printf "%bPress any key to cancel reboot in 10 seconds.%b\n" "${YELLOW}" "${NC}"
  if ! read -r -t 10 -n 1; then
  clear
  printf "%bRebooting in 5 seconds.%b\n" "${YELLOW}" "${NC}"
  sleep 1
  clear
  printf "%bRebooting in 4 seconds.%b\n" "${YELLOW}" "${NC}"
  sleep 1
  clear
  printf "%bRebooting in 3 seconds.%b\n" "${YELLOW}" "${NC}"
  sleep 1
  clear
  printf "%bRebooting in 2 seconds.%b\n" "${YELLOW}" "${NC}"
  sleep 1
  clear
  printf "%bRebooting in 1 seconds.%b\n" "${YELLOW}" "${NC}"
  sleep 1
  clear
  printf "%bRebooting now.%b\n" "${GREEN}" "${NC}"
  reboot
  else
    printf "%bReboot cancelled.%b\n" "${YELLOW}" "${NC}"
    exit 0
  fi

}

# Main function to orchestrate the setup
main() {
  partition_disk
  format_boot_partitions
  setup_luks
  setup_lvm
  # Call the function to create and remount subvolumes
  create_root_btrfs_partition
  create_and_remount_btrfs_subvols
  mount_efi_boot
  mount_tmpfs

  install_base_system
  configure_core_system
  finalize_installation
}

# Execute the script
main "$@"

#!/usr/bin/env bash

# Readable comments are displayed to the user
readable_comments(){
    printf '\n\n%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' '-'
    printf "\n%s\n\n" "$@"
    printf '%*s\n\n\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' '-'
}

readable_comments "This script will install Arch Linux on your system."

readable_comments "This script will exit on error"
set -e

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    cat <<EOF | less
This script will install Arch Linux on your system.
Usage: ./arch-install.sh [OPTIONS]
Options:
  --auto, -a: Run the script in auto mode
  --test, -t: Run the script in test mode
  --step, -s: Run the script starting at the specified step
  --cryptlvmpassword, -c: Set the cryptlvm password
  --hostname, -H: Set the hostname
  --username, -n: Set the username
  --userpassword, -p: Set the user password
  --rootpassword, -P: Set the root password
  --verbose, -v: Output what the script does
  --variables, -V: Output the variables used by the script
EOF
    exit 0
fi

readable_comments "Import the variables from arch-install-variables.env if it exists"
if [ ! -f arch-install-variables.env ]; then
    readable_comments "arch-install-variables.env does not exist. Creating it."
    touch arch-install-variables.env
else
    readable_comments "arch-install-variables.env exists. Sourcing it."
    . arch-install-variables.env
fi

readable_comments "Initialize the last successfully completed step, only if it's not already set"

: "${current_step:=0}"

readable_comments "Initialize these variables only if they are not set"

: "${current_step:=0}"
: "${cryptlvmpassword:=}"
: "${username:=}"
: "${userpassword:=}"
: "${rootpassword:=}"
: "${hostname:=}"
: "${mode:=}"

readable_comments "Function to run the command and check its status"

run_step_check() {
    local step="$1"; shift
    if [ "$step" -eq "$((current_step + 1))" ]; then
        if [[ "$mode" != "auto" ]]; then
            printf "About to run: %s [Y/n] " "$*"
            read -r response
            case "$response" in
                [yY]* | "" | " ")
                ;;
                [nN]*)
                    printf "Stopped at step %s as per user request.\n" "$step"
                    exit 0
                    ;;
                *)
                    printf "Invalid option.\n"
                    exit 1
                    ;;
            esac
        fi
        "$@" || {
            local exit_status=$?
            printf "Step %s failed with exit status %d. Manual intervention needed.\n" "$step" "$exit_status"
            exit 1
        }
        printf "Finished step %s\n" "$step"
        success_step
    else
        if [ "$step" -le "$((current_step))" ]; then
            printf "Step %s was already completed.\n" "$step"
        else
            printf "Step %s is too high; we are missing:\n" "$step"
            for ((i=$((current_step + 1)); i<$step; i++)); do
                printf "Missing step: %s\n" "$i"
            done
            exit 1
        fi
    fi
}

readable_comments "Function to mark the current step as successful and move to the next"
success_step() {
  current_step=$((current_step + 1))
  export current_step
}

readable_comments "Parsing flags for test, auto modes, and update-step"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --auto | -a)
      mode="auto"
      shift
      ;;
    --test | -t)
      export cryptlvmpassword="test"
      export username="test"
      export userpassword="test"
      export rootpassword="test"
      export hostname="test"
      shift
      ;;
    --step | -s)
      # is this a integer?
      if [[ "$2" =~ ^[0-9]+$ ]]; then
      export current_step="$2"
      shift 2
      else
        # if not, then set it to 0 and go to the next step
        export current_step=0
        shift
      fi
      ;;
    --cryptlvmpassword | -c)
      export cryptlvmpassword="$2"
      shift 2
      ;;
    --hostname | -H)
      export hostname="$2"
      shift 2
      ;;
    --username | -n)
      export username="$2"
      shift 2
      ;;
    --userpassword | -p)
      export userpassword="$2"
      shift 2
      ;;
    --rootpassword | -P)
      export rootpassword="$2"
      shift 2
      ;;
    --verbose | -v)
        readable_comments "This script will output what it does"
        set -x
        shift
        ;;
    --variables | -V)
        cat arch-install-variables.env
        exit 0
        ;;
    *)
        printf "Unknown option: %s\n" "$1"
        exit 1
        ;;
  esac
done

readable_comments "Your code here, using 'run_step_check' as needed."

readable_comments "Exporting variables for reference if needed in future re-runs"
run_step_check 1 bash -c 'cat <<EOF > arch-install-variables.env
export current_step="${current_step}"
export cryptlvmpassword="${cryptlvmpassword}"
export username="${username}"
export userpassword="${userpassword}"
export rootpassword="${rootpassword}"
export hostname="${hostname}"
EOF'

run_step_check 2 echo "This is step 2"
run_step_check 3 echo "This is step 3"
run_step_check 4 echo "This is step 4"
run_step_check 5 echo "This is step 5"
run_step_check 6 echo "This is step 6"
run_step_check 7 echo "This is step 7"
run_step_check 8 echo "This is step 8"
run_step_check 9 echo "This is step 9"
run_step_check 10 echo "This is step 10"
run_step_check 11 echo "${cryptlvmpassword}"
run_step_check 12 echo "${username}"
run_step_check 13 echo "${userpassword}"
run_step_check 14 echo "${rootpassword}"
run_step_check 15 echo "${hostname}"
run_step_check 16 echo "${mode}"
run_step_check 12 echo "This is step is  to be skipped"
run_step_check 17 echo "This is step is to continue after skipping the current"
run_step_check 27 echo "This is step is to produce an error or to be called directly"


exit 0

readable_comments "Check if all required variables are set and prompt if missing"
for varname in cryptlvmpassword hostname username userpassword rootpassword; do
  if [[ -z "${!varname}" ]]; then
    read -rp "Enter ${varname}: " input
    printf -v "$varname" '%s' "$input"
    export "$varname=$input"
  fi
done

readable_comments "Check EFI mode"
if [ -d "/sys/firmware/efi" ]; then
  echo "Booted in UEFI mode."
else
  echo "Booted in Legacy mode."
  echo "Please boot in UEFI mode."
fi
    parted /dev/vda mklabel gpt
    parted /dev/vda mkpart primary fat32 0% 512MiB
    parted /dev/vda mkpart primary ext4 512MiB 2048MiB
    parted /dev/vda mkpart primary 2048MiB 95%
    parted /dev/vda set 1 esp on
    parted /dev/vda set 2 boot on
    mkfs.fat -F32 /dev/vda1
    mkfs.ext4 /dev/vda2

readable_comments "Feed YES and the password into cryptsetup with the label 'cryptlvm'"
{ echo YES; echo "${cryptlvmpassword}"; echo "${cryptlvmpassword}"; } | cryptsetup luksFormat --label=cryptlvm /dev/vda3 --type luks2
echo "${cryptlvmpassword}" | cryptsetup open --type luks2 /dev/vda3 cryptlvm

readable_comments "Create LVM partition"
pvcreate /dev/mapper/cryptlvm
vgcreate MyVolGroup /dev/mapper/cryptlvm

readable_comments "Create LVM logical volumes"
readable_comments "swap 2GB"
lvcreate -L 2GB MyVolGroup -n swap
mkswap /dev/MyVolGroup/swap
swapon /dev/MyVolGroup/swap
swapon --show

readable_comments "Create Logical Volume taking up 90% of remaining free space"
lvcreate -l 90%FREE MyVolGroup -n root

readable_comments "Make Btrfs filesystem"
mkfs.btrfs /dev/MyVolGroup/root

readable_comments "Mount the root Btrfs filesystem"
mount /dev/MyVolGroup/root /mnt

readable_comments "Declare subvolume names in an array"
declare -a subvols=("rootfs" "home" "snapshots" "rootuser" "srv" "cache" "log" "tmp")

readable_comments "Loop over each subvolume name and create it"
for subvol in "${subvols[@]}"; do
  btrfs subvolume create "/mnt/@${subvol}"
done

readable_comments "Mount subvolumes"
readable_comments "Your custom mount options"
mount_opts="rw,noatime,space_cache=v2,ssd,discard=async,compress=zstd:5"

readable_comments "The device you're mounting from"
device="/dev/MyVolGroup/root"

readable_comments "Declare an associative array to hold subvol names and their corresponding directories"
declare -A subvol_dirs
for subvol in "${subvols[@]}"; do
  case "$subvol" in
    "rootfs")
      subvol_dirs["@${subvol}"]="/mnt"
      ;;
    "home" | "rootuser" | "srv")
      subvol_dirs["@${subvol}"]="/mnt/$subvol"
      ;;
    "snapshots")
      subvol_dirs["@${subvol}"]="/mnt/.snapshots"
      ;;
    "cache" | "log" | "tmp")
      subvol_dirs["@${subvol}"]="/mnt/var/$subvol"
      ;;
  esac
done

readable_comments "Unmount existing subvolumes recursively from /mnt"
umount -R -v /mnt

readable_comments "Create directories and mount subvolumes"
for name in "${!subvol_dirs[@]}"; do
  dir=${subvol_dirs[$name]}

  # Create the directory if it doesn't exist
  mkdir -p "$dir"

  # Mount the subvolume
  mount -v -t btrfs -o "${mount_opts},subvolid=@${name}" "$device" "$dir"
done


readable_comments "Create directories for boot and efi partitions and mount them"
mkdir -p /mnt/boot && mount -v -t ext4 /dev/vda2 /mnt/boot
mkdir -p /mnt/boot/efi && mount -v -t vfat /dev/vda1 /mnt/boot/efi

readable_comments "Create directories for tmpfs partitions and mount them"
mkdir -p /mnt/tmp && mount -v -o defaults,noatime,mode=1777 -t tmpfs tmpfs /mnt/tmp

# Base and Development
# shellcheck disable=SC2034
base_and_dev=("base" "base-devel" "linux" "linux-firmware" "linux-headers" "arch-install-scripts" "archinstall")

# Networking
# shellcheck disable=SC2034
network=("bind-tools" "inetutils" "networkmanager" "wget" "reflector" "openssh")

# File Systems
# shellcheck disable=SC2034
filesystem=("btrfs-progs" "lvm2")

# Shell and Terminal
# shellcheck disable=SC2034
shell_and_terminal=("fish" "htop" "neovim")

# Git and Version Control
# shellcheck disable=SC2034
git_vc=("git" "github-cli" "gnupg" "gnutls")

# Boot and EFI
# shellcheck disable=SC2034
boot_efi=("efibootmgr" "grub" "grub-btrfs")

# Utilities
# shellcheck disable=SC2034
utilities=("curl" "jq" "man-db" "man-pages" "python" "usbutils" "util-linux" "util-linux-libs" "xdg-utils" "xdg-user-dirs" "unzip" "zip")

# Audio
# shellcheck disable=SC2034
audio=("pipewire" "pipewire-alsa" "pipewire-pulse")

# Graphics and Display
# shellcheck disable=SC2034
graphics=("mesa" "xorg" "xorg-apps" "xorg-server" "xorg-xinit" "xorg-xrandr")

# Copy and Paste Utilities
# shellcheck disable=SC2034
clipboard=("xclip" "xsel")

# Virtualization
# shellcheck disable=SC2034
virtualization=("qemu-guest-agent" "spice-vdagent")

# Window Manager
# shellcheck disable=SC2034
wm=("qtile")

# Fonts
# shellcheck disable=SC2034
fonts=("terminus-font")

# All groups
all_groups=("base_and_dev" "network" "filesystem" "shell_and_terminal" "git_vc" "boot_efi" "utilities" "audio" "graphics" "clipboard" "virtualization" "wm" "fonts")

add_packages() {
  for pkg in "$@"; do
    packages_to_install+=("$pkg")
  done
}

install_packages() {
  if [[ ${#packages_to_install[@]} -ne 0 ]]; then
    echo "Installing: ${packages_to_install[*]}" >> install.log
    if ! pacstrap /mnt "${packages_to_install[@]}"; then
      echo "Failed to install some packages. Check install.log for details."
      exit 1
    fi
  else
    echo "No packages to install."
  fi
}

readable_comments "Iterate over each group and add packages"
for group in "${all_groups[@]}"; do
  add_packages "${!group[@]}"
done

install_packages


readable_comments "Generate fstab"
genfstab -U /mnt >> /mnt/etc/fstab

cat <<EOF > /mnt/arch-post-install.sh
#!/usr/bin/env bash

# Readable comments are displayed to the user
readable_comments(){
    printf '\n\n%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' '-'
    printf "\n%s\n\n" "$@"
    printf '%*s\n\n\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' '-'
}
set -e  # Exit on error

# Default variable values (will be overridden if already set)
cryptlvmpassword=${cryptlvmpassword-}
username=${username-}
userpassword=${userpassword-}
rootpassword=${rootpassword-}
hostname=${hostname-}
mode=${mode-}

# Enable Network Manager
systemctl enable NetworkManager || { echo "Failed to enable NetworkManager"; exit 1; }

# Install GRUB
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB || { echo "Failed to install GRUB"; exit 1; }

# Update GRUB settings
UUID=$(blkid -s UUID -o value /dev/vda3)
sed -i "s|^GRUB_CMDLINE_LINUX=.*$|GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${UUID}:cryptlvm root=/dev/MyVolGroup/root\"|" /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg || { echo "Failed to generate GRUB config"; exit 1; }

# Update mkinitcpio.conf
sed -i "s|^HOOKS=.*$|HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block encrypt lvm2 filesystems fsck)|" /etc/mkinitcpio.conf

# Set console font
echo 'FONT=ter-132b' | tee -a /etc/vconsole.conf

# Update pacman.conf
sed -i 's|^#VerbosePkgLists|VerbosePkgLists|; s|^#ParallelDownloads = 5|ParallelDownloads = 5|' /etc/pacman.conf

# Update mirrorlist
curl -o /etc/pacman.d/mirrorlist https://archlinux.org/mirrorlist/all/
reflector -c "Netherlands," -p https -a 3 --sort rate --save /etc/pacman.d/mirrorlist

# Set hardware clock
hwclock --systohc || { echo "Failed to set hardware clock"; exit 1; }

# Set Timezone
ln -sf /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime || { echo "Failed to set timezone"; exit 1; }

# Generate Locales
sed -i 's|^#\(en_US.UTF-8 UTF-8\)|\1|; s|^#\(en_US ISO-8859-1\)|\1|' /etc/locale.gen || { echo "Failed to set locale in /etc/locale.gen"; exit 1; }
locale-gen || { echo "Failed to generate locale"; exit 1; }
echo "LANG=en_US.UTF-8" > /etc/locale.conf || { echo "Failed to set LANG in /etc/locale.conf"; exit 1; }

# Install yay from AUR
command -v git >/dev/null 2>&1 || { echo "Git is not installed. Aborting."; exit 1; }
mkdir -p ~/.local/share/src && cd ~/.local/share/src
git clone https://aur.archlinux.org/yay-git.git || { echo "Failed to clone yay-git"; exit 1; }
cd yay-git
makepkg -si || { echo "Failed to install yay"; exit 1; }

# Generate initial ramdisk
mkinitcpio -P || { echo "Failed to generate initial ramdisk"; exit 1; }

# Check for root password
if [ -z "$rootpassword" ]; then
  read -rp "Enter the root password: " rootpassword
fi

# Set the root password
echo -e "$rootpassword\n$rootpassword" | passwd

# Check for username
if [ -z "$username" ]; then
  read -rp "Enter the username: " username
fi

# Check for user password
if [ -z "$userpassword" ]; then
  read -rp "Enter the user password: " userpassword
fi

# Create user, set shell, and add to 'wheel' group
useradd -m -G wheel -s /usr/bin/fish "$username"

# Set the user password
echo "${username}:${userpassword}" | chpasswd

# Create a sudoers file for the user
echo "$username ALL=(ALL) ALL" > "/etc/sudoers.d/$username"
chmod 0440 "/etc/sudoers.d/$username"

# Check for hostname
if [ -z "${hostname}" ]; then
  read -rp "Enter the hostname: " hostname
fi

# Set the hostname
echo "${hostname}" > /etc/hostname

if [[ "$mode" == "auto" ]] || [[ "$mode" == "test" ]]; then
  groupadd autologin
  gpasswd -a "$username" autologin
fi

# Check if git is installed
command -v git >/dev/null 2>&1 || { echo "Git is not installed. Aborting."; exit 1; }

# Define the directory for yay-git
USER_DIR="/home/$username/.local/share/src"

# Create directory if doesn't exist
su - "$username" -c "mkdir -p $USER_DIR"

# Clone yay-git repository
su - "$username" -c "git clone https://aur.archlinux.org/yay-git.git $USER_DIR/yay-git" || { echo "Failed to clone yay-git"; exit 1; }

# Build and install yay
su - "$username" -c "makepkg -si -C $USER_DIR/yay-git" || { echo "Failed to install yay"; exit 1; }

EOF

chmod +x /mnt/arch-post-install.sh
# Change root into new system
arch-chroot /mnt
# Run post-install script
./arch-post-install.sh
# Remove post-install script
rm /mnt/arch-post-install.sh
# Unmount all partitions
umount -R /mnt
# Reboot
reboot

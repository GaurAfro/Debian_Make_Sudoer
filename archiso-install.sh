#!/usr/bin/env bash

# Readable comments are displayed to the user
readable_comments(){
    printf '\n\n%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' '-'
    printf "\n%s\n\n" "$@"
    printf '%*s\n\n\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' '-'
}

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
readable_comments "showing help"
less -c <<EOF





              this script will install arch linux on your system.
              usage: ./arch-install.sh [options]
              options:
                  --auto, -a: run the script in auto mode
                  --test, -t: run the script in test mode
                  --step, -s: run the script starting at the specified step
                  --cryptlvmpassword, -c: set the cryptlvm password
                  --hostname, -h: set the hostname
                  --username, -n: set the username
                  --userpassword, -p: set the user password
                  --rootpassword, -p: set the root password
                  --verbose, -v: output what the script does
                  --variables, -v: output the variables used by the script
EOF
exit 0
fi

readable_comments "This script will install Arch Linux on your system."

readable_comments "This script will exit on error"
set -e

readable_comments "Import the variables from arch-install-variables.env if it exists"
if [ ! -f arch-install-variables.env ]; then
    readable_comments "arch-install-variables.env does not exist. Creating it."
    touch arch-install-variables.env
else
    readable_comments "arch-install-variables.env exists. Sourcing it."
    # shellcheck disable=SC1091
    . ./arch-install-variables.env
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
: "${disk:=}"

readable_comments "Function to run the command and check its status"

run_step_check() {
    local step="$1"; shift
    if [ "$step" -eq "$((current_step + 1))" ]; then
        if [[ "$mode" != "auto" ]]; then
            printf '\n\n%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' '-'
            printf "About to run: %s [Y/n]\n" "$*"
            printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' '-'
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
        # printf '\n\n%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' '-'
        printf "\nFinished step %s\n" "$step"
        printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' '-'
        success_step
    else
        if [ "$step" -le "$((current_step))" ]; then
            printf "Step %s was already completed.\n" "$step"
        else
            printf "Step %s is too high; we are missing:\n" "$step"
            for ((i=current_step + 1; i<step; i++)); do
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

choose_disk() {
  # List all available disks
  available_disks=$(lsblk -d -o NAME,SIZE,TYPE | grep 'disk' | awk '{print $1}')

  # Count the number of available disks
  num_disks=$(echo "$available_disks" | wc -l)

  # Check if more than one disk is available
  if [ "$num_disks" -gt 1 ]; then
    # Show the available disks with a corresponding number
    echo "Multiple disks detected. Available disks for partitioning:"
    i=1
    for disk in $available_disks; do
      echo "$i) /dev/$disk"
      i=$((i + 1))
    done

    # Prompt user for choice
    read -rp "Choose a disk by typing its name or number: " choice

    # Determine if the choice is a number or a disk name
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
      chosen_disk=$(echo "$available_disks" | sed -n "${choice}p")
    else
      chosen_disk="$choice"
    fi

    # Validate the chosen disk
    if echo "$available_disks" | grep -qw "$chosen_disk"; then
      echo "You chose /dev/$chosen_disk."
      export disk="/dev/$chosen_disk"
    else
      echo "Invalid choice. Please try again."
      choose_disk  # Call the function recursively
    fi
  else
    # If there's only one disk, automatically choose it and export it
    chosen_disk="$available_disks"
    echo "Only one disk detected. Automatically choosing /dev/$chosen_disk."
    export disk="/dev/$chosen_disk"
  fi
}

create_valid_hostname() {
  while true; do
    read -rp "Enter a valid hostname (letters, numbers, and hyphens only): " input_hostname
    if [[ "$input_hostname" =~ ^[a-zA-Z0-9-]+$ ]]; then
      echo "Valid hostname: $input_hostname"
      export hostname="$input_hostname"
      break  # Exit the loop
    else
      echo "Invalid hostname. Please try again."
    fi
  done
}

create_valid_username() {
  while true; do
    read -rp "Enter a valid username (letters, numbers, dashes, and underscores only, must start with a letter): " input_username
    if [[ "$input_username" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
      echo "Valid username: $input_username"
      export username="$input_username"
      break  # Exit the loop
    else
      echo "Invalid username. Please try again."
    fi
  done
}


readable_comments "Parsing flags for test, auto modes, and update-step"
while [ "$#" -gt 0 ]; do
case "$1" in
  --auto | -a)
    export mode="auto"
    shift
    ;;
  --test | -t)
    export cryptlvmpassword="test"
    export username="test"
    export userpassword="test"
    export rootpassword="test"
    export hostname="test"
    # Detect if running in a KVM/QEMU virtual machine
    vm_status=$(systemd-detect-virt)

    if [[ -z "$disk" && "$vm_status" == "kvm" ]]; then
    export disk="/dev/vda"
    fi
    # Uncomment the following lines if you want to use the above logic for other VMs
    # if [[ -z "$disk" && "$vm_status" != "none" ]]; then
    # export disk="/dev/vda"
    # fi
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
    passed_hostname="$2"
    # Validate the passed hostname
    if [[ ! "$passed_hostname" =~ ^[a-zA-Z0-9-]+$ ]]; then
    echo "Invalid hostname passed as a flag."
    create_valid_hostname
    else
      echo "Valid hostname passed as a flag: $passed_hostname"
      export hostname="$passed_hostname"
    fi
    shift 2
    ;;
  --username | -n)
    passed_username="$2"
    if [[ ! "$passed_username" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
    echo "Invalid username passed as a flag."
    create_valid_username
    else
      echo "Valid username passed as a flag: $passed_username"
      export username="$passed_username"
    fi
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
    readable_comments "Displaying current environment variables:"
    cat arch-install-variables.env
    exit 0
    ;;
  *)
    printf "Unknown option: %s\n" "$1"
    exit 1
    ;;
esac
done

# Call the function to choose the disk
readable_comments "Exporting variables for reference if needed in future re-runs"
run_step_check 1 bash -c 'cat <<EOF > arch-install-variables.env
export current_step='"${current_step}"'
export cryptlvmpassword='"${cryptlvmpassword}"'
export username='"${username}"'
export userpassword='"${userpassword}"'
export rootpassword='"${rootpassword}"'
export hostname='"${hostname}"'
export disk='"${disk}"'
EOF'

readable_comments "Check if all required variables are set and prompt if missing"

for varname in cryptlvmpassword disk hostname username userpassword rootpassword; do
  if [[ -z "${!varname}" ]]; then
    if [[ "$varname" == "hostname" ]]; then
      create_valid_hostname
    elif [[ "$varname" == "username" ]]; then
      create_valid_username
    elif [[ "$varname" == "disk" ]]; then
      choose_disk
    else
      read -rp "Enter ${varname}: " input
      printf -v "$varname" '%s' "$input"
      export "$varname=$input"
    fi
  fi
done

# Exit the script if not in UEFI mode
if [ ! -d "/sys/firmware/efi" ]; then
  readable_comment "Booted in Legacy mode. Please boot in UEFI mode."
  exit 1
fi
# Skip the confirmation if in 'auto' mode
if [[ "$mode" == "auto" ]]; then
  skip_confirmation=true
else
  read -rp "Do you want to reformat the disk? This will erase all data on it. Press [Y, space, or Enter] to proceed: " reformat_choice
  reformat_choice=$(echo "$reformat_choice" | tr -d '[:space:]')
  skip_confirmation=false
fi
# Proceed with reformatting if in 'auto' mode or user confirms
if [[ "$skip_confirmation" == true || -z "$reformat_choice" || "$reformat_choice" =~ ^[yy]$ ]]; then
  if parted "${disk}" print 1>/dev/null 2>&1; then
    partitions_to_remove=$(parted "${disk}" print | awk '/^ / {print $1}')
    if [[ ! -z "$partitions_to_remove" ]]; then
      parted --script "${disk}" rm "$partitions_to_remove"
    fi
  fi

  echo "creating new partitions..."
  parted --script "${disk}" mklabel gpt
  parted --script "${disk}" mkpart primary fat32 0% 512mib
  parted --script "${disk}" mkpart primary ext4 512mib 2048mib
  parted --script "${disk}" mkpart primary 2048mib 95%
  parted --script "${disk}" set 1 esp on
  parted --script "${disk}" set 2 boot on

  echo "formatting partitions..."
  mkfs.fat -F 32 "${disk}1"
  mkfs.ext4 "${disk}2"
else
  echo "skipping disk reformatting."
fi

readable_comments "Feed YES and the password into cryptsetup with the label 'cryptlvm'"
# Securely format and open LUKS volume
echo -n "${cryptlvmpassword}" | cryptsetup luksFormat --label=cryptlvm "${disk}3" --type luks2 --key-file /dev/stdin
echo -n "${cryptlvmpassword}" | cryptsetup open --type luks2 "${disk}3" cryptlvm --key-file /dev/stdin

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
mkdir -p /mnt/boot && mount -v -t ext4 "${disk}"2 /mnt/boot
mkdir -p /mnt/boot/efi && mount -v -t vfat "${disk}"1 /mnt/boot/efi

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
UUID=$(blkid -s UUID -o value "${disk}"3)
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

readable_comments "Check if arch-post-install.sh is created and executable"
if [[ -f /mnt/arch-post-install.sh  &&  ! -x /mnt/arch-post-install.sh ]]; then
  readable_comments "The sript is there, now we wil make it executable."
  chmod +x /mnt/arch-post-install.sh
else
  readable_comments "arch-post-install.sh is missing or not executable. Exiting."
  exit 1
fi

# Change root into new system
readable_comments "Change root into new system"
arch-chroot /mnt

# Run post-install script
readable_comments "Run post-install script"
./arch-post-install.sh

# Remove post-install script
readable_comments "Remove post-install script"
rm /mnt/arch-post-install.sh

# Unmount all partitions
readable_comments "Unmount all partitions"
umount -R /mnt

# Inform the user before rebooting
echo "Installation complete. Rebooting now."
# Reboot
reboot
#+END_SRC

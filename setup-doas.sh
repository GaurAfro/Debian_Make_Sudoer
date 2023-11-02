#!/usr/bin/env bash

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

if command -v "doas" >/dev/null 2>&1; then
    echo "doas already installed"
else
    echo "Installing doas"

    package_manager=""
    for pm in apt pacman; do
        if command -v "$pm" >/dev/null 2>&1; then
            package_manager="$pm"
            break
        fi
    done

    if [ -z "$package_manager" ]; then
        echo "No package manager found."
        exit 1
    fi

    pkg_for_package_manager=""
    if [ "$package_manager" = "apt" ]; then
        pkg_for_package_manager="doas"
    elif [ "$package_manager" = "pacman" ]; then
        pkg_for_package_manager="opendoas"
    fi

    case "$package_manager" in
        apt)
            apt update
            apt install -y "$pkg_for_package_manager"
            ;;
        pacman)
            pacman -Sy --noconfirm "$pkg_for_package_manager"
            ;;
        *)
            echo "No package manager found"
            exit 1
            ;;
    esac
fi

# Get the current effective username
current_user=$(whoami)

# Logic to determine the actual username
if [ "$current_user" = "root" ]; then
    # If a sudo user exists and is not root, use that
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        actual_user="$SUDO_USER"
    # If no sudo user, check the USER environment variable
    elif [ -n "$USER" ] && [ "$USER" != "root" ]; then
        actual_user="$USER"
    # Lastly, check the USERNAME environment variable
    elif [ -n "$USERNAME" ] && [ "$USERNAME" != "root" ]; then
        actual_user="$USERNAME"
    else
        # If all else fails, ask the user to enter their username
        read -rp "Please enter your actual username: " actual_user
    fi
else
    # If not running as root, use the current effective user
    actual_user="$current_user"
fi

if [ -f /etc/doas.conf ]; then
    echo "doas.conf already exists"

    # Loop over each line to append
    while IFS= read -r line; do
        # Replace REPLACEMENT_USER_NAME with actual_user in the line before the grep check
        # line_replaced=$(echo "$line" | sed "s/REPLACEMENT_USER_NAME/$actual_user/g")
        line_replaced="${line//REPLACEMENT_USER_NAME/$actual_user}"

        # Check if the replaced line already exists for the user in doas.conf
        if ! grep -Fxq "$line_replaced" /etc/doas.conf; then
            echo "$line_replaced" | tee -a /etc/doas.conf > /dev/null
        fi
    done <<EOF
permit persist keepenv REPLACEMENT_USER_NAME as root
permit nopass keepenv REPLACEMENT_USER_NAME as root cmd virt-clone
permit nopass keepenv REPLACEMENT_USER_NAME as root cmd virt-viewer
permit nopass REPLACEMENT_USER_NAME as root cmd apt
permit nopass REPLACEMENT_USER_NAME as root cmd cat
permit nopass REPLACEMENT_USER_NAME as root cmd chmod
permit nopass REPLACEMENT_USER_NAME as root cmd chown
permit nopass REPLACEMENT_USER_NAME as root cmd cp
permit nopass REPLACEMENT_USER_NAME as root cmd find
permit nopass REPLACEMENT_USER_NAME as root cmd grep
permit nopass REPLACEMENT_USER_NAME as root cmd ln
permit nopass REPLACEMENT_USER_NAME as root cmd mkdir
permit nopass REPLACEMENT_USER_NAME as root cmd mount
permit nopass REPLACEMENT_USER_NAME as root cmd mv
permit nopass REPLACEMENT_USER_NAME as root cmd nala
permit nopass REPLACEMENT_USER_NAME as root cmd nvim
permit nopass REPLACEMENT_USER_NAME as root cmd pacman
permit nopass REPLACEMENT_USER_NAME as root cmd poweroff
permit nopass REPLACEMENT_USER_NAME as root cmd rc-service
permit nopass REPLACEMENT_USER_NAME as root cmd rc-update
permit nopass REPLACEMENT_USER_NAME as root cmd reboot
permit nopass REPLACEMENT_USER_NAME as root cmd rm
permit nopass REPLACEMENT_USER_NAME as root cmd sed
permit nopass REPLACEMENT_USER_NAME as root cmd snapctl
permit nopass REPLACEMENT_USER_NAME as root cmd su
permit nopass REPLACEMENT_USER_NAME as root cmd systemctl
permit nopass REPLACEMENT_USER_NAME as root cmd tee
permit nopass REPLACEMENT_USER_NAME as root cmd umount
permit nopass REPLACEMENT_USER_NAME as root cmd unzip
permit nopass REPLACEMENT_USER_NAME as root cmd updatedb
permit nopass REPLACEMENT_USER_NAME as root cmd virsh
permit nopass REPLACEMENT_USER_NAME as root cmd vmctl
EOF
else
    echo "Creating doas.conf"
    cat <<EOF | sed "s/REPLACEMENT_USER_NAME/$actual_user/g" | tee -a /etc/doas.conf
permit persist keepenv REPLACEMENT_USER_NAME as root
permit nopass keepenv REPLACEMENT_USER_NAME as root cmd virt-clone
permit nopass keepenv REPLACEMENT_USER_NAME as root cmd virt-viewer
permit nopass REPLACEMENT_USER_NAME as root cmd apt
permit nopass REPLACEMENT_USER_NAME as root cmd cat
permit nopass REPLACEMENT_USER_NAME as root cmd chmod
permit nopass REPLACEMENT_USER_NAME as root cmd chown
permit nopass REPLACEMENT_USER_NAME as root cmd cp
permit nopass REPLACEMENT_USER_NAME as root cmd find
permit nopass REPLACEMENT_USER_NAME as root cmd grep
permit nopass REPLACEMENT_USER_NAME as root cmd ln
permit nopass REPLACEMENT_USER_NAME as root cmd mkdir
permit nopass REPLACEMENT_USER_NAME as root cmd mount
permit nopass REPLACEMENT_USER_NAME as root cmd mv
permit nopass REPLACEMENT_USER_NAME as root cmd nala
permit nopass REPLACEMENT_USER_NAME as root cmd nvim
permit nopass REPLACEMENT_USER_NAME as root cmd pacman
permit nopass REPLACEMENT_USER_NAME as root cmd poweroff
permit nopass REPLACEMENT_USER_NAME as root cmd rc-service
permit nopass REPLACEMENT_USER_NAME as root cmd rc-update
permit nopass REPLACEMENT_USER_NAME as root cmd reboot
permit nopass REPLACEMENT_USER_NAME as root cmd rm
permit nopass REPLACEMENT_USER_NAME as root cmd sed
permit nopass REPLACEMENT_USER_NAME as root cmd snapctl
permit nopass REPLACEMENT_USER_NAME as root cmd su
permit nopass REPLACEMENT_USER_NAME as root cmd systemctl
permit nopass REPLACEMENT_USER_NAME as root cmd tee
permit nopass REPLACEMENT_USER_NAME as root cmd umount
permit nopass REPLACEMENT_USER_NAME as root cmd unzip
permit nopass REPLACEMENT_USER_NAME as root cmd updatedb
permit nopass REPLACEMENT_USER_NAME as root cmd virsh
permit nopass REPLACEMENT_USER_NAME as root cmd vmctl
EOF
fi

# Validate the target file before changing permissions
if [ -f /etc/doas.conf ]; then
    chown -c root:root /etc/doas.conf
    chmod -c 0400 /etc/doas.conf
else
    echo "doas.conf does not exist. Skipping permission change."
    exit 1
fi

# Validate the configuration
doas -C /etc/doas.conf && echo "Config OK" || echo "Config error"

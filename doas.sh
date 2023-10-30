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

current_user=$(whoami)
sudo_user=$SUDO_USER
user_env_var=$USER

if [ "$current_user" = "root" ] && { [ "$sudo_user" = "root" ] || [ -z "$sudo_user" ]; } && { [ "$user_env_var" = "root" ] || [ -z "$user_env_var" ]; }; then
    read -rp "Please enter your actual username: " actual_user
else
    if [ -n "$SUDO_USER" ]; then
        actual_user="$SUDO_USER"
    elif [ -n "$USER" ] && [ "$USER" != "root" ]; then
        actual_user="$USER"
    else
        actual_user="$current_user"
    fi
fi

if [ -f /etc/doas.conf ]; then
    echo "doas.conf already exists"

    # Loop over each line to append
    while IFS= read -r line; do
        # Replace USER with actual_user in the line before the grep check
        line_replaced=$(echo "$line" | sed "s/USER/$actual_user/g")

        # Check if the replaced line already exists for the user in doas.conf
        if ! grep -Fxq "$line_replaced" /etc/doas.conf; then
            echo "$line_replaced" | tee -a /etc/doas.conf > /dev/null
        fi
    done <<EOF
permit persist keepenv USER as root
permit nopass keepenv USER as root cmd virt-clone
permit nopass keepenv USER as root cmd virt-viewer
permit nopass USER as root cmd apt
permit nopass USER as root cmd cat
permit nopass USER as root cmd chmod
permit nopass USER as root cmd chown
permit nopass USER as root cmd cp
permit nopass USER as root cmd find
permit nopass USER as root cmd grep
permit nopass USER as root cmd ln
permit nopass USER as root cmd mkdir
permit nopass USER as root cmd mount
permit nopass USER as root cmd mv
permit nopass USER as root cmd nala
permit nopass USER as root cmd nvim
permit nopass USER as root cmd pacman
permit nopass USER as root cmd poweroff
permit nopass USER as root cmd rc-service
permit nopass USER as root cmd rc-update
permit nopass USER as root cmd reboot
permit nopass USER as root cmd rm
permit nopass USER as root cmd sed
permit nopass USER as root cmd snapctl
permit nopass USER as root cmd su
permit nopass USER as root cmd systemctl
permit nopass USER as root cmd tee
permit nopass USER as root cmd umount
permit nopass USER as root cmd unzip
permit nopass USER as root cmd updatedb
permit nopass USER as root cmd virsh
permit nopass USER as root cmd vmctl
EOF
else
    echo "Creating doas.conf"
    cat <<EOF | sed "s/USER/$actual_user/g" | tee -a /etc/doas.conf
permit persist keepenv USER as root
permit nopass keepenv USER as root cmd virt-clone
permit nopass keepenv USER as root cmd virt-viewer
permit nopass USER as root cmd apt
permit nopass USER as root cmd cat
permit nopass USER as root cmd chmod
permit nopass USER as root cmd chown
permit nopass USER as root cmd cp
permit nopass USER as root cmd find
permit nopass USER as root cmd grep
permit nopass USER as root cmd ln
permit nopass USER as root cmd mkdir
permit nopass USER as root cmd mount
permit nopass USER as root cmd mv
permit nopass USER as root cmd nala
permit nopass USER as root cmd nvim
permit nopass USER as root cmd pacman
permit nopass USER as root cmd poweroff
permit nopass USER as root cmd rc-service
permit nopass USER as root cmd rc-update
permit nopass USER as root cmd reboot
permit nopass USER as root cmd rm
permit nopass USER as root cmd sed
permit nopass USER as root cmd snapctl
permit nopass USER as root cmd su
permit nopass USER as root cmd systemctl
permit nopass USER as root cmd tee
permit nopass USER as root cmd umount
permit nopass USER as root cmd unzip
permit nopass USER as root cmd updatedb
permit nopass USER as root cmd virsh
permit nopass USER as root cmd vmctl
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

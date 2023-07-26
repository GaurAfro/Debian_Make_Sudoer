#!/bin/bash

# Ensure the script is being run as root
if [ "$(id -u)" != "0" ]; then
    echo "Please run this script as root."
    exit 1
fi

# Get the current username
USERNAME=$(logname)

# Create a file for the user in /etc/sudoers.d/ with the correct permissions
echo "$USERNAME ALL=(ALL:ALL) ALL" > "/etc/sudoers.d/$USERNAME"
chmod 0440 "/etc/sudoers.d/$USERNAME"

echo "Added $USERNAME to sudoers."


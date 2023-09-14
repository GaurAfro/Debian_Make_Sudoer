#!/usr/bin/env sh

# Prompt user for name and email
read -r -p "Enter your name: " name
read -r -p "Enter your email: " email

# Set the provided name and email for git
git config --global user.name "$name"
git config --global user.email "$email"

# Generate SSH key
ssh-keygen -t ed25519 -C "$email"

# Start the ssh-agent and load the SSH key
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Copy the SSH key to clipboard (requires xclip to be installed)

if command -v xclip > /dev/null 2>&1; then
    xclip -selection clipboard < ~/.ssh/id_ed25519.pub
elif command -v xsel > /dev/null 2>&1; then
    xsel -b < ~/.ssh/id_ed25519.pub
else
    echo "Neither xclip nor xsel is installed."
fi

# Open the GitHub SSH keys settings page in the default browser
xdg-open "https://github.com/settings/keys"

# Test the SSH connection to GitHub
ssh -T git@github.com

echo "Git and SSH have been configured with the provided name and email."


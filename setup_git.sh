#!/usr/bin/env sh

set -e
set -u

log_file=/tmp/setup_git.log
teesudo() { sudo tee -a "$log_file"; }
log_and_run() {
    cmd="$1"
    echo "Executing: $cmd" | teesudo

    set +e
    eval "$cmd" 2>&1 | teesudo
    cmd_exit_status=$?
    set -e

    if [ $cmd_exit_status -ne 0 ]; then
        echo "Command failed with exit status $cmd_exit_status: $cmd" | teesudo
        echo "cat /tmp/setup_git.log"
        echo "nvim /tmp/setup_git.log"

        exit 1
    fi
}

echo "---------------------------------------------------------------" | teesudo
echo "$(date) Starting the Setup for Git & GitHub CLI..." | teesudo
echo "---------------------------------------------------------------" | teesudo
echo "" | teesudo
echo "" | teesudo
echo "" | teesudo
echo "----------------------------------------------------------------" | teesudo
echo "Created a log file in the same directory of this script location" | teesudo
echo "----------------------------------------------------------------" | teesudo
echo "" | teesudo
echo "" | teesudo
echo "" | teesudo

# Prompt user for name and email
echo "Enter your username: "   | teesudo
read -r username && log_and_run "echo 'Name acquired'"
echo "Enter your email: "  | teesudo
read -r email && log_and_run "echo 'Email acquired'"
echo "" | teesudo
echo "" | teesudo
echo "" | teesudo

# Set the provided name and email for git
git config --global user.name "$username" && log_and_run "echo 'Set the git global username'"
git config --global user.email "$email" && log_and_run "echo 'Set the git global email'"
echo "" | teesudo
echo "" | teesudo
echo "" | teesudo

# Generate SSH key
ssh-keygen -t ed25519 -C "$email"  && log_and_run "echo 'Set the git global email'"
ssh_key_path="$HOME/.ssh/id_ed25519" && log_and_run "echo 'Set the git global email'"
echo "" | teesudo
echo "" | teesudo
echo "" | teesudo

# Start the ssh-agent and load the SSH key
eval "$(ssh-agent -s)" && log_and_run "echo 'Started the ssh-agent'"
ssh-add "$ssh_key_path" && log_and_run "echo 'Added the SSH Key'"
echo "" | teesudo
echo "" | teesudo
echo "" | teesudo

# Authenticate GitHub CLI
if command -v gh > /dev/null 2>&1; then
    echo "GitHub Cli is installed" | teesudo
    gh auth login -s 'user:email,read:org,repo,write:org,notifications' -p ssh && log_and_run "echo 'Logged in to GitHub'"
    echo "" | teesudo
    echo "" | teesudo
    echo "" | teesudo
else
    echo "------------------------------------------------------------" | teesudo
    echo "See the Linux/BSD page for distro speciffic instuctions"      | teesudo
    echo "https://github.com/cli/cli/blob/trunk/docs/install_linux.md"  | teesudo
    echo "------------------------------------------------------------" | teesudo
    echo "GitHub Cli is not installed" | teesudo
    exit 1
fi

# Test the SSH connection to GitHub
log_and_run "ssh -T git@github.com"
echo "" | teesudo
echo "" | teesudo
echo "" | teesudo

# rm ./setup_git.log
# echo "--------------------"
# echo "Removing the logfile"
# echo "--------------------"
# echo ""
# echo ""
# echo ""
echo "------------------------------------------------------------------"
echo "Git and SSH have been configured with the provided name and email."
echo "------------------------------------------------------------------"
exit 0

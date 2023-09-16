#!/usr/bin/env sh

set -e
set -u

log_file=./setup_git.log

log_and_run() {
    cmd="$1"
    echo "Executing: $cmd" | tee -a "$log_file"

    set +e
    eval "$cmd" 2>&1 | tee -a "$log_file"
    cmd_exit_status=$?
    set -e

    if [ $cmd_exit_status -ne 0 ]; then
        echo "Command failed with exit status $cmd_exit_status: $cmd" | tee -a "$log_file"
        exit 1
    fi
}

echo "---------------------------------------------------------------" | tee -a "$log_file"
echo "$(date) Starting the Setup for Git & GitHub CLI..." | tee -a "$log_file"
echo "---------------------------------------------------------------" | tee -a "$log_file"
echo "" | tee -a "$log_file"
echo "" | tee -a "$log_file"
echo "" | tee -a "$log_file"
echo "----------------------------------------------------------------" | tee -a "$log_file"
echo "Created a log file in the same directory of this script location" | tee -a "$log_file"
echo "----------------------------------------------------------------" | tee -a "$log_file"
echo "" | tee -a "$log_file"
echo "" | tee -a "$log_file"
echo "" | tee -a "$log_file"

# Prompt user for name and email
echo "Enter your username: "   | tee -a "$log_file"
read -r username && log_and_run "echo 'Name acquired'"
echo "Enter your email: "  | tee -a "$log_file"
read -r email && log_and_run "echo 'Email acquired'"
echo "" | tee -a "$log_file"
echo "" | tee -a "$log_file"
echo "" | tee -a "$log_file"

# Set the provided name and email for git
git config --global user.name "$username" && log_and_run "echo 'Set the git global username'"
git config --global user.email "$email" && log_and_run "echo 'Set the git global email'"
echo "" | tee -a "$log_file"
echo "" | tee -a "$log_file"
echo "" | tee -a "$log_file"

# Generate SSH key
ssh-keygen -t ed25519 -C "$email"  && log_and_run "echo 'Set the git global email'"
ssh_key_path="$HOME/.ssh/id_ed25519" && log_and_run "echo 'Set the git global email'"
echo "" | tee -a "$log_file"
echo "" | tee -a "$log_file"
echo "" | tee -a "$log_file"

# Start the ssh-agent and load the SSH key
eval "$(ssh-agent -s)" && log_and_run "echo 'Started the ssh-agent'"
ssh-add "$ssh_key_path" && log_and_run "echo 'Added the SSH Key'"
echo "" | tee -a "$log_file"
echo "" | tee -a "$log_file"
echo "" | tee -a "$log_file"

# Authenticate GitHub CLI
if command -v gh > /dev/null 2>&1; then
    echo "GitHub Cli is installed" | tee -a "$log_file"
    log_and_run "gh auth login -s 'user:email,read:org,repo,write:org,notifications' -p ssh"
    echo "" | tee -a "$log_file"
    echo "" | tee -a "$log_file"
    echo "" | tee -a "$log_file"
else
    echo "------------------------------------------------------------" | tee -a "$log_file"
    echo "See the Linux/BSD page for distro speciffic instuctions"      | tee -a "$log_file"
    echo "https://github.com/cli/cli/blob/trunk/docs/install_linux.md"  | tee -a "$log_file"
    echo "------------------------------------------------------------" | tee -a "$log_file"
    echo "GitHub Cli is not installed" | tee -a "$log_file"
    exit 1
fi

# Test the SSH connection to GitHub
log_and_run "ssh -T git@github.com"
echo "" | tee -a "$log_file"
echo "" | tee -a "$log_file"
echo "" | tee -a "$log_file"

rm ./setup_git.log
echo "--------------------"
echo "Removing the logfile"
echo "--------------------"
echo "" 
echo "" 
echo "" 
echo "------------------------------------------------------------------" 
echo "Git and SSH have been configured with the provided name and email."
echo "------------------------------------------------------------------"
exit 0

#!/usr/bin/env sh
if [ -z "$test_setup" ]; then
    set -e
    set -u

    tmp_log_file=$(mktemp)

    teesudo() { sudo tee -a "$tmp_log_file"; }
    teetmp() { tee -a "$tmp_log_file"; }

    readeable_log_file_before() {
        echo "" | teesudo
        echo "" | teesudo
        echo "---------------------------------------------------------------" | teesudo
    }

    readeable_log_file_after() {
        echo "---------------------------------------------------------------" | teesudo
        echo "" | teesudo
        echo "" | teesudo
    }


    log_and_run() {
        cmd="$1"
        readeable_log_file_before
        echo "Executing: $cmd" | teesudo
        readeable_log_file_after

        set +e
        eval "$cmd" 2>&1 | teesudo
        cmd_exit_status=$?
        set -e

        if [ $cmd_exit_status -ne 0 ]; then
            echo "Command failed with exit status $cmd_exit_status: $cmd" | teesudo
            mv "$tmp_log_file" ./setup_git.log

            echo "cat ./setup_git.log"
            echo "nvim ./setup_git.log"

            exit 1
        fi
    }

    readeable_log_file_before
    echo "$(date) Starting the Setup for Git & GitHub CLI..." | teesudo
    readeable_log_file_after

    readeable_log_file_before
    echo "Created a log file in the same directory of this script location" | teesudo
    readeable_log_file_after

    # Prompt user for name and email only if they are not provided
    if [ -z "$username" ]; then
        readeable_log_file_before
        read -rp "Enter your username: "  username && log_and_run "echo 'Name acquired'"
        readeable_log_file_after
    fi
    if [ -z "$email" ]; then
        readeable_log_file_before
        read -rp "Enter your email: "  username && log_and_run "echo 'Email acquired'"
        readeable_log_file_after
    fi

    # Set the provided name and email for git
    readeable_log_file_before
    git config --global user.name "$username" && log_and_run "echo 'Set the git global username'"
    readeable_log_file_after

    readeable_log_file_before
    git config --global user.email "$email" && log_and_run "echo 'Set the git global email'"
    readeable_log_file_after

    # Generate SSH key
    ssh_key_path="$HOME/.ssh/id_ed25519"
    if [ ! -f "$ssh_key_path" ]; then
        readeable_log_file_before
        ssh-keygen -t ed25519 -C "$email"  && log_and_run "echo 'Set the git global email'"
        readeable_log_file_after
        # Start the ssh-agent and load the SSH key
        readeable_log_file_before
        eval "$(ssh-agent -s)" && log_and_run "echo 'Started the ssh-agent'"
        readeable_log_file_after

        readeable_log_file_before
        ssh-add "$ssh_key_path" && log_and_run "echo 'Added the SSH Key'"
        readeable_log_file_after
    fi


    # Authenticate GitHub CLI
    if command -v gh > /dev/null 2>&1; then
        readeable_log_file_before
        echo "GitHub Cli is installed" | teesudo
        readeable_log_file_after

        readeable_log_file_before
        gh auth login -s 'user:email,read:org,repo,write:org,notifications' -p ssh && log_and_run "echo 'Logged in to GitHub'"
        readeable_log_file_after
    else
        readeable_log_file_before
        echo "See the Linux/BSD page for distro speciffic instuctions"      | teesudo
        echo "https://github.com/cli/cli/blob/trunk/docs/install_linux.md"  | teesudo
        echo "GitHub Cli is not installed" | teesudo
        readeable_log_file_after
        exit 1
    fi

    # Test the SSH connection to GitHub
    readeable_log_file_before
    log_and_run "ssh -T git@github.com"
    readeable_log_file_after

    readeable_log_file_before
    echo "Git and SSH have been configured with the provided name and email."
    readeable_log_file_after
    exit 0
else
    username="$(if test -z "$username"; then read -r "Provide your username: " username; fi)"
    email="$(if test -z "$email"; then read -r "Provide your email: " email; fi)"
    git config --global user.name "$username"
    git config --global user.email "$email"
fi

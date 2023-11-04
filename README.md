# Public Scripts
---
test 

## **Setup SSH for GitHub Login**
```bash
bash -c "$( export username=[YOUR USERNAME]; export email=[YOUR EMAIL]; curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/gaurafro/public-scripts/main/setup-git.sh )"
```

```bash
curl -sSL -o setup_git.sh https://raw.githubusercontent.com/gaurafro/public-scripts/main/setup-git.sh
chmod +x setup-git.sh
./setup-git.sh
```
---

## **Setup Doas**
If you are using this script in an install, or before defining the user the variable **"USER"**,
then you can export the custom variable **"USERNAME"** in the subshell(i.e. just for that one time use).
```bash
bash -c "$(curl --proto '=https' --tlsv1.2 -ssf https://raw.githubusercontent.com/gaurafro/public-scripts/main/setup-doas.sh)"
```

```bash
curl -sSL -o setup_git.sh https://raw.githubusercontent.com/gaurafro/public-scripts/main/setup-doas.sh
chmod +x setup-doas.sh
./setup-doas.sh
```
---
### **Using the `add-to-sudoers.sh` Script with `curl`**

This guide will walk you through the process of executing the `add-to-sudoers.sh` script using `curl`.

#### **Instructions**:

1. **Switch to the Superuser**: Before running the script, ensure you are the superuser (root).
   ```bash
   su
   ```
2. **Install `curl`**: If it's not already installed, you can get it with:
   ```bash
   apt install -y curl sudo
   ```
3. **Execute the Script**: Now, execute the following command:
   ```bash
   curl -sSL https://raw.githubusercontent.com/gaurafro/public-scripts/main/add-to-sudoers.sh | sh
   ```

3. **Script Execution**: The script will run and automatically configure the necessary settings to grant sudo privileges to the current user.

4. **Verification**: To verify, exit from the superuser mode:
   ```bash
   exit
   ```
   Then, try a sudo command to ensure the current user has been added to the `sudoers`:
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

5. **Completion**: If the `sudo` command runs without any permission issues, the script has successfully added the user to the `sudoers`.

#### **Safety Reminder**:
Always ensure you trust the source of scripts you're fetching and executing directly from the web. It's a good practice to review the content of scripts before running them, especially as a superuser.

---

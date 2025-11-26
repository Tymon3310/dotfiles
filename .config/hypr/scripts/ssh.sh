#!/bin/bash

# Define paths
SSH_CONFIG_FILE="$HOME/.ssh/config"
SSH_KEYS_DIR="$HOME/.ssh"

echo "--- Add New SSH Host Entry ---"
echo "This script will add an entry to your ~/.ssh/config and generate the corresponding .pub file."
echo ""

# 1. Get Host Details
read -p "Enter the SSH Host Alias (e.g., my-server, github-new): " HOST_ALIAS
read -p "Enter the Hostname or IP address (e.g., 192.168.1.10, example.com): " HOST_ADDRESS
read -p "Enter the User for this connection (e.g., root, admin): " SSH_USER

# 2. Get Key Comment from Agent
echo ""
echo "Now, we need to find the key comment as listed by your SSH agent."
echo "Running 'ssh-add -l' to show currently loaded keys:"
ssh-add -l
echo ""
read -p "Enter the EXACT key comment for this host (e.g., root@192.168.1.100, Github): " KEY_COMMENT

# Sanitize the key comment for filename creation
# Replace user@host with user_host, then replace non-alphanumeric (except _-) with _
SANITIZED_KEY_COMMENT=$(echo "$KEY_COMMENT" | sed -E 's/(\w+)@(\S+)/\1_\2/' | sed 's/[^a-zA-Z0-9_-]/_/g')
IDENTITY_FILE="${SSH_KEYS_DIR}/id_ed25519_${HOST_ALIAS}.pub"

# 3. Generate the .pub file locally
echo ""
echo "Attempting to generate the public key file: ${IDENTITY_FILE}"

# Extract the specific public key from ssh-add -L based on the comment
ssh-add -L | grep -F "${KEY_COMMENT}" >"${IDENTITY_FILE}"

if [ -s "${IDENTITY_FILE}" ]; then
  echo "Successfully generated public key file: ${IDENTITY_FILE}"
  echo "Contents:"
  cat "${IDENTITY_FILE}"
else
  echo "Error: Could not find or generate the public key for comment '${KEY_COMMENT}' from ssh-add -L."
  echo "Please ensure the key is loaded in your Bitwarden SSH agent and the comment is exact."
  read -p "Do you want to continue without generating the .pub file? (y/N): " CONTINUE_WITHOUT_PUB
  if [[ ! "$CONTINUE_WITHOUT_PUB" =~ ^[yY]$ ]]; then
    echo "Aborting."
    exit 1
  fi
fi

# 4. Append to ~/.ssh/config
echo ""
echo "Adding entry to ${SSH_CONFIG_FILE}..."

# Create the config block
CONFIG_BLOCK="
# ${HOST_ALIAS} configuration
Host ${HOST_ADDRESS}
    # HostName ${HOST_ADDRESS}
    User ${SSH_USER}
    Port 22
    IdentityFile ${IDENTITY_FILE}
    IdentitiesOnly yes
"

# Check if config file exists, if not, create it with initial global settings
if [ ! -f "${SSH_CONFIG_FILE}" ]; then
  echo "Creating new SSH config file with global settings."
  echo "# Global settings" >"${SSH_CONFIG_FILE}"
  echo "IdentitiesOnly yes" >>"${SSH_CONFIG_FILE}"
  echo "IdentityAgent /home/tymon/.bitwarden-ssh-agent.sock" >>"${SSH_CONFIG_FILE}"
  echo "" >>"${SSH_CONFIG_FILE}"
  chmod 600 "${SSH_CONFIG_FILE}"
fi

echo "${CONFIG_BLOCK}" >>"${SSH_CONFIG_FILE}"

echo ""
echo "--- Entry Added Successfully! ---"
echo "New entry for '${HOST_ALIAS}' added to ${SSH_CONFIG_FILE}."
echo "You can now connect using: ssh ${SSH_USER}@${HOST_ALIAS} (or ssh ${HOST_ALIAS})"
echo "Please review your ${SSH_CONFIG_FILE} to confirm."
echo "You can open it with nvim: nvim ${SSH_CONFIG_FILE}"

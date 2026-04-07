#!/bin/bash
# SSH Setup Script for Machine 1 N (macOS 15.7.3)
# This script sets up SSH connection and generates automation scripts

set -e

echo "=== SSH Setup for Machine 1 N ==="
echo ""

# Variables - CUSTOMIZE THESE
MACHINE1N_USER="${MACHINE1N_USER:-nonlineari}"
MACHINE1N_HOST="${MACHINE1N_HOST:-machine1n.local}"  # or IP address
MACHINE1N_IP="${MACHINE1N_IP:-}"  # Set if not using .local
SSH_KEY_NAME="id_machine1n"

echo "Target Machine: $MACHINE1N_USER@$MACHINE1N_HOST"
echo ""

# Step 1: Generate SSH key if it doesn't exist
if [ ! -f ~/.ssh/$SSH_KEY_NAME ]; then
    echo "→ Generating SSH key pair..."
    ssh-keygen -t ed25519 -f ~/.ssh/$SSH_KEY_NAME -C "NCOMM-$(hostname)-to-machine1n" -N ""
    echo "✓ SSH key generated: ~/.ssh/$SSH_KEY_NAME"
else
    echo "✓ SSH key already exists: ~/.ssh/$SSH_KEY_NAME"
fi

# Step 2: Display public key for manual copying
echo ""
echo "=== PUBLIC KEY (copy this to Machine 1 N) ==="
cat ~/.ssh/${SSH_KEY_NAME}.pub
echo "=== END PUBLIC KEY ==="
echo ""

# Step 3: Instructions for Machine 1 N
cat << 'EOF'

=== On Machine 1 N, run these commands: ===

# Enable Remote Login (SSH)
sudo systemsetup -setremotelogin on

# Add the public key above to authorized_keys
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "PASTE_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Get the IP address
ifconfig | grep "inet " | grep -v 127.0.0.1

EOF

# Step 4: Test connection prompt
echo "After completing the above steps on Machine 1 N, test with:"
echo "  ssh -i ~/.ssh/$SSH_KEY_NAME $MACHINE1N_USER@$MACHINE1N_HOST"
echo ""

# Step 5: Create SSH config entry
echo "→ Adding SSH config entry..."
SSH_CONFIG_ENTRY="
# Machine 1 N Configuration
Host machine1n
    HostName $MACHINE1N_HOST
    User $MACHINE1N_USER
    IdentityFile ~/.ssh/$SSH_KEY_NAME
    ServerAliveInterval 60
    ServerAliveCountMax 3
    Compression yes
"

if ! grep -q "Host machine1n" ~/.ssh/config 2>/dev/null; then
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    echo "$SSH_CONFIG_ENTRY" >> ~/.ssh/config
    chmod 600 ~/.ssh/config
    echo "✓ SSH config updated"
else
    echo "⚠ SSH config entry for machine1n already exists"
fi

echo ""
echo "✓ Setup complete! After configuring Machine 1 N, connect with:"
echo "  ssh machine1n"

# Add user, create home directory, set default shell
sudo useradd -m -s /bin/bash newuser

# Change user passowrd
sudo passwd newuser

# Switch to the target user (or log in as them):
sudo su - username

# Create the SSH directory and set restricted permissions:
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Add the public key to the authorized_keys file:
# Open the file with a text editor like Nano
# Paste your public key string (starts with ssh-rsa, ssh-ed25519, etc.) on a new line
vim ~/.ssh/authorized_keys

# Set file permissions:
chmod 600 ~/.ssh/authorized_keys

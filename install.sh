#!/bin/bash

if [ "$EUID" -eq 0 ]; then
    echo "Error: Do not run this script as root or with sudo."
    echo "It will use sudo internally where needed."
    exit 1
fi

# Check for .env file
if [ ! -f .env ]; then
    echo "Warning: .env file not found."
    if [ -f .env.example ]; then
        echo "Copying .env.example to .env..."
        cp .env.example .env
        echo "Please edit .env with your passwords before running 'docker compose up -d'"
    else
        echo "Error: .env.example not found either."
        exit 1
    fi
fi

# Update package list and system
echo "Updating system..."
sudo apt-get update && sudo apt-get upgrade -y

# Install required dependencies
echo "Installing dependencies..."
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
echo "Adding Docker GPG key..."
sudo mkdir -m 0755 -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up Docker repository
echo "Setting up Docker repository..."
echo \
  "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package list again
sudo apt-get update

# Install Docker
echo "Installing Docker..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker service
echo "Starting Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

# Add current user to docker group
echo "Adding user to docker group..."
sudo usermod -aG docker $USER

echo "Installation complete!"
echo "Please log out and log back in for docker group changes to take effect"
echo "Then run 'docker compose up -d' to start all services."
IP=$(hostname -I | awk '{print $1}')
echo "Access Portainer at http://$IP:9000"
echo "Access Pi-hole admin at http://$IP:8081/admin"
echo "Pi-hole DNS is on port 5353 (configure devices to use $IP:5353 as DNS server)"
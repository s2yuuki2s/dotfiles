#!/usr/bin/env bash
set -euo pipefail

echo "== Docker Installer =="

# Check if Docker is already installed
if ! command -v docker >/dev/null 2>&1; then
  # Add Docker's official GPG key:
  echo "Adding Docker's official GPG key..."
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  # Add the repository to Apt sources:
  echo "Adding Docker repository to Apt sources..."
  sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

  sudo apt-get update

  # Install Docker Engine, CLI, and Compose
  echo "Installing Docker Engine, CLI, and Plugins..."
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
  echo "Docker is already installed (version: $(docker --version))"
fi

# Post-installation: add current user to docker group
if ! getent group docker >/dev/null; then
  sudo groupadd docker
fi

echo "Adding user $USER to docker group..."
sudo usermod -aG docker "$USER"

echo "Docker installed successfully!"
echo "IMPORTANT: Please log out and log back in (or run 'newgrp docker') for group changes to take effect."
echo "After that, you can verify the installation by running: docker run hello-world"

#!/usr/bin/env bash

set -euo pipefail

echo "Checking for NVIDIA GPU and driver..."

check_nvidia_driver() {
    if lspci | grep -i nvidia > /dev/null; then
        if nvidia-smi > /dev/null 2>&1; then
            echo "NVIDIA GPU and driver are properly installed."
            return 0
        else
            echo "NVIDIA GPU found, but driver is not installed or not working properly."
            return 1
        fi
    else
        echo "NVIDIA GPU not found."
        return 1
    fi
}

install_docker() {
    echo "Installing Docker on the host machine..."

    sudo apt update
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin git openssh-server openssh-client
    sudo usermod -aG docker "${USER}"
    sudo chmod 666 /var/run/docker.sock
    sudo systemctl restart docker

    echo "Docker installation finished."
}

install_nvidia_container_toolkit() {
    echo "Setting up NVIDIA Container Toolkit. Make sure the NVIDIA graphics driver is already installed."

    sudo apt install -y curl
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
      sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
      sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
      sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null

    sudo sed -i -e '/experimental/ s/^#//g' /etc/apt/sources.list.d/nvidia-container-toolkit.list

    sudo apt-get update
    sudo apt-get install -y nvidia-container-toolkit
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker

    echo "NVIDIA Container Toolkit installation finished."
}

if check_nvidia_driver; then
    install_docker
    install_nvidia_container_toolkit
else
    install_docker
fi


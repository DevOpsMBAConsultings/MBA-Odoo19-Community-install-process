#!/bin/bash
set -e

echo "Updating system packages..."
apt update -y
apt upgrade -y

echo "Checking swap space..."
if [ $(swapon --show=SIZE --noheadings --bytes | awk '{s+=$1} END {print s+0}') -eq 0 ]; then
    echo "No swap space detected. Creating a 2GB swap file to prevent OOM errors..."
    fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile none swap sw 0 0" | tee -a /etc/fstab
    echo "Swap space created and enabled."
else
    echo "Swap space already exists."
fi

echo "System update completed."

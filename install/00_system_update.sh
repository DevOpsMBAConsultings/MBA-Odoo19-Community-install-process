#!/bin/bash
set -e

echo "Updating system packages..."
apt update -y
apt upgrade -y

echo "System update completed."

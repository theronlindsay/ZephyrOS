#!/usr/bin/env bash
set -oue pipefail

# Make the integration script executable
chmod +x /usr/libexec/zephyros-integrate-appimages.sh

# Enable the first-boot AppImage integration service
systemctl enable zephyros-integrate-appimages.service

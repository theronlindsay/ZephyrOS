#!/usr/bin/env bash
# Integrate AppImages with GearLever
# This runs once on first boot since flatpak can't run during image build

set -euo pipefail

# Wait for flatpak to be ready
sleep 5

# Integrate Helium AppImage if it exists
if [ -f /usr/libexec/helium/helium.AppImage ]; then
    echo "Integrating Helium AppImage..."
    flatpak run it.mijorus.gearlever --integrate /usr/libexec/helium/helium.AppImage -y || true
fi

echo "AppImage integration complete"

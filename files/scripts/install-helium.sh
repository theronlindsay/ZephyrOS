#!/usr/bin/env bash
set -oue pipefail

# Get latest Helium release for x86_64
LATEST_URL=$(curl -sL https://api.github.com/repos/imputnet/helium-linux/releases/latest \
  | grep -o "https://.*x86_64.*\.AppImage" \
  | head -n 1)

if [ -z "$LATEST_URL" ]; then
  echo "Failed to find AppImage download URL"
  exit 1
fi

echo "Downloading Helium from: $LATEST_URL"

# Download the AppImage
curl -L "$LATEST_URL" -o /usr/libexec/helium/helium.AppImage
chmod +x /usr/libexec/helium/helium.AppImage

flatpak run it.mijorus.gearlever --integrate /usr/libexec/helium.AppImage -y


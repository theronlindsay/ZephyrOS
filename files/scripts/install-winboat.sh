#!/usr/bin/env bash
set -oue pipefail

# Get latest WinBoat release for x86_64
LATEST_URL=$(curl -sL https://api.github.com/repos/TibixDev/winboat/releases/latest \
  | grep -o "https://.*x86_64.*\.AppImage" \
  | head -n 1)

if [ -z "$LATEST_URL" ]; then
  echo "Failed to find AppImage download URL"
  exit 1
fi

echo "Downloading WinBoat from: $LATEST_URL"

# Create directory and download the AppImage
mkdir -p /usr/libexec/winboat
curl -L "$LATEST_URL" -o /usr/libexec/winboat/winboat.AppImage
chmod +x /usr/libexec/winboat/winboat.AppImage

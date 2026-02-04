#!/usr/bin/env bash
set -oue pipefail

# Create AppImages directory in skel if it doesn't exist
if [ ! -d /etc/skel/AppImages ]; then
  mkdir -p /etc/skel/AppImages
fi

# Remove existing Helium AppImage if present
if [ -f /etc/skel/AppImages/helium.AppImage ]; then
  echo "Removing existing Helium AppImage..."
  rm -f /etc/skel/AppImages/helium.AppImage
fi

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
curl -L "$LATEST_URL" -o /etc/skel/AppImages/helium.AppImage
chmod +x /etc/skel/AppImages/helium.AppImage

# Create desktop entry that points to AppImages folder
cat > /usr/share/applications/helium.desktop << 'EOF'
[Desktop Entry]
Name=Helium
Exec=~/AppImages/helium.AppImage
Icon=helium
Type=Application
Categories=Network;Audio;
Terminal=false
Comment=Helium Music Player
EOF

#!/usr/bin/env bash

# Tell this script to exit if there are any errors.
# You should have this in every custom script, to ensure that your completed
# builds actually ran successfully without any errors!
set -oue pipefail

# Your code goes here.
echo 'Setting up Hibernation'
echo 'Creating btrfs subvolume....'

btrfs subvolume create /var/swap
semanage fcontext -a -t var_t /var/swap
restorecon /var/swap

echo 'Creating swapfile'

# Get total RAM in KB and add 4GB for hibernation
RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
# Add 4GB (4194304 KB) for swap
SIZEKB=$((RAM_KB + 4194304))
SIZEG=$((SIZEKB / 1024 / 1024))
echo "Total RAM: $((RAM_KB / 1024)) MB"
echo "Swap size: $((SIZEKB / 1024)) MB ($SIZEG GB)"


echo 'Creating swapfile'
btrfs filesystem mkswapfile --size ${SIZEG}G /var/swap/swapfile
semanage fcontext -a -t swapfile_t /var/swap/swapfile
restorecon /var/swap/swapfile
echo 'Enabling swap'
swapon /var/swap/swapfile

echo "" | sudo tee /etc/systemd/zram-generator.conf

echo 'Hibernation setup complete!'
if command -v notify-send &> /dev/null; then
    notify-send "Hibernation Setup" "Setup complete. Please reboot to enable hibernation."
fi




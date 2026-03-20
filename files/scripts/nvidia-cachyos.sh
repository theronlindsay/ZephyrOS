#!/usr/bin/env bash
set -oue pipefail

# Step 1: Enable the ublue-os akmods copr repository.
# Bazzite uses its own specific version of the NVIDIA user-space drivers (already in our base image).
# We MUST use their matching akmod-nvidia package, otherwise we get dependency conflicts 
# with RPMFusion asserting mismatched xorg-x11-drv-nvidia-libs versions.
dnf -y copr enable ublue-os/akmods

# Step 2: Install the NVIDIA driver akmod package from the ublue repo.
# 'akmods' will use this package to build the actual kernel module for our specific kernel.
dnf -y install --setopt=install_weak_deps=False akmod-nvidia

# Step 3: Determine the kernel version that was installed earlier by cachyos-kernel.sh.
VER=$(ls /lib/modules)
echo "Building nvidia kmod for kernel $VER..."

# Step 4: Force akmods to build the NVIDIA kernel module for the detected CachyOS kernel.
akmods --force --kernels $VER --kmod nvidia

# Step 5: Update module dependencies (depmod) to register the newly built NVIDIA module.
# Then, regenerate the initramfs (dracut) to ensure the NVIDIA drivers are loaded early during boot.
depmod -a $VER
dracut --kver $VER --force --add ostree --no-hostonly --reproducible /usr/lib/modules/$VER/initramfs.img

# Step 6: Clean up the ublue akmod repo so it doesn't interfere later.
rm -f /etc/yum.repos.d/*ublue-os-akmods*.repo
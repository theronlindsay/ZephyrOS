#!/usr/bin/env bash
set -oue pipefail

# Step 1: Enable the RPMFusion repositories.
# These repositories contain the NVIDIA driver packages that are not shipped with Fedora by default.
dnf -y install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
               https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Step 2: Install the open-source version of the NVIDIA driver akmod package.
# 'akmods' will use this package to build the actual kernel module for our specific kernel.
dnf -y install --setopt=install_weak_deps=False akmod-nvidia-open

# Step 3: Determine the kernel version that was installed earlier by cachyos-kernel.sh.
VER=$(ls /lib/modules)
echo "Building nvidia kmod for kernel $VER..."

# Step 4: Force akmods to build the NVIDIA kernel module for the detected CachyOS kernel.
akmods --force --kernels $VER --kmod nvidia

# Step 5: Update module dependencies (depmod) to register the newly built NVIDIA module.
# Then, regenerate the initramfs (dracut) to ensure the NVIDIA drivers are loaded early during boot.
depmod -a $VER
dracut --kver $VER --force --add ostree --no-hostonly --reproducible /usr/lib/modules/$VER/initramfs.img
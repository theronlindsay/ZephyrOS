#!/usr/bin/env bash
set -oue pipefail

# Step 1: Enable the RPMFusion repositories explicitly.
# We need these to get the raw akmod-nvidia tools.
dnf -y install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
               https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

dnf -y config-manager setopt rpmfusion-nonfree.enabled=1
dnf -y config-manager setopt rpmfusion-nonfree-updates.enabled=1

# Step 2: Download the akmod-nvidia package without immediately resolving dependencies.
# Bazzite has strictly versioned NVIDIA user-space libraries already installed, which conflicts
# with standard DNF dependency resolution. We just need the akmod source files!
cd /tmp
dnf -y download --enablerepo=rpmfusion-nonfree-updates --enablerepo=rpmfusion-nonfree akmod-nvidia xorg-x11-drv-nvidia-kmodsrc

# Step 3: Force install the downloaded akmod RPMs while ignoring dependency checks.
# We also use --noscripts to prevent RPM from running the %post install scriptlet.
# The post-install script tries to background-build the module or hit OSTree hooks
# which fail inside an immutable Podman build container. We will build it manually anyway.
# Bazzite already has nvidia-kmod-common built-in.
rpm -ivh --nodeps --noscripts akmod-nvidia-*.rpm xorg-x11-drv-nvidia-kmodsrc-*.rpm

# Step 4: Determine the kernel version that was installed earlier by cachyos-kernel.sh.
VER=$(ls /lib/modules)
echo "Building nvidia kmod for kernel $VER..."

# Step 5: Force akmods to build the NVIDIA kernel module for the detected CachyOS kernel.
akmods --force --kernels $VER --kmod nvidia

# Step 6: Update module dependencies (depmod) to register the newly built NVIDIA module.
# Then, regenerate the initramfs (dracut) to ensure the NVIDIA drivers are loaded early during boot.
depmod -a $VER
dracut --kver $VER --force --add ostree --no-hostonly --reproducible /usr/lib/modules/$VER/initramfs.img

# Step 7: Clean up RPMs and disable RPMfusion so it doesn't try to auto-update on user systems.
rm -f /tmp/*.rpm
dnf -y config-manager setopt rpmfusion-nonfree.enabled=0
dnf -y config-manager setopt rpmfusion-nonfree-updates.enabled=0
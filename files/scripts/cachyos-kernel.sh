#!/usr/bin/env bash
# This script replaces the default Fedora kernel with the performance-optimized CachyOS kernel.
# It was adapted from solarpowered by askpng:
# https://github.com/askpng/solarpowered/blob/main/files/scripts/kernels/kernel-cachy.sh

# Step 1: Remove the default Fedora kernel and its leftover module files.
# This ensures we don't have conflicting kernels taking up space or causing boot issues.
dnf -y remove \
    kernel \
    kernel-* && \
rm -r -f /usr/lib/modules/*

# Step 2: Install DNF core plugins just in case they are missing.
# These plugins help manage repositories and packages more effectively.
dnf -y install --setopt=install_weak_deps=False \
    dnf-plugins-core \
    dnf5-plugins

# Step 3: Enable third-party repositories needed for the new kernel and related tools.
# We add CachyOS for the kernel, and multimedia/terra repos for additional dependencies.
dnf -y copr enable bieszczaders/kernel-cachyos
dnf -y copr enable bieszczaders/kernel-cachyos-addons
# dnf -y copr enable ublue-os/akmods
dnf -y config-manager addrepo --from-repofile=https://negativo17.org/repos/fedora-multimedia.repo
dnf -y config-manager addrepo --from-repofile=https://raw.githubusercontent.com/terrapkg/subatomic-repos/main/terra.repo

# (Commented out) Step 4: Temporarily disable kernel post-transaction scripts.
# Sometimes needed in immutable OS builds to prevent RPM tree generation errors.
# mv /usr/lib/kernel/install.d/05-rpmostree.install /usr/lib/kernel/install.d/05-rpmostree.install.bak
# mv /usr/lib/kernel/install.d/50-dracut.install /usr/lib/kernel/install.d/50-dracut.install.bak
# printf '%s\n' '#!/bin/sh' 'exit 0' > /usr/lib/kernel/install.d/05-rpmostree.install
# printf '%s\n' '#!/bin/sh' 'exit 0' > /usr/lib/kernel/install.d/50-dracut.install
# chmod +x \
#      /usr/lib/kernel/install.d/05-rpmostree.install \
#      /usr/lib/kernel/install.d/50-dracut.install

# Step 5: Install the CachyOS LTO kernel, headers (devel), module builders (akmods),
# and various performance scheduling tools (scx-scheds, scx-tools).
dnf -y install --setopt=install_weak_deps=False \
    kernel-cachyos-lto \
    kernel-cachyos-lto-devel \
    akmods \
    akmod-evdi \
    zenergy \
    scx-scheds \
    scx-tools \
    scx-manager

# Step 6: Replace default zram settings with CachyOS's optimized memory compression settings.
dnf -y swap zram-generator-defaults cachyos-settings

# (Commented out) Step 7: Restore the kernel post-transaction scripts.
# rm -f /usr/lib/kernel/install.d/05-rpmostree.install \
#       /usr/lib/kernel/install.d/50-dracut.install
# mv /usr/lib/kernel/install.d/05-rpmostree.install.bak /usr/lib/kernel/install.d/05-rpmostree.install
# mv /usr/lib/kernel/install.d/50-dracut.install.bak /usr/lib/kernel/install.d/50-dracut.install

# Step 8: Manually compile extra kernel modules (zenergy, evdi) for the newly installed kernel.
# Then update module dependencies (depmod) and generate the initial ramdisk (initramfs) 
# which the system relies on during the Linux boot sequence.
VER=$(ls /lib/modules) && \
    akmods --force --kernels $VER --kmod zenergy && \
    akmods --force --kernels $VER --kmod evdi && \
    depmod -a $VER && \
    dracut --kver $VER --force --add ostree --no-hostonly --reproducible /usr/lib/modules/$VER/initramfs.img

# Step 9: Clean up the repository files we added earlier.
# This keeps the final OS image clean and prevents unintended updates directly from these repos.
rm -f /etc/yum.repos.d/{*copr*,*multimedia*,*terra*}.repo
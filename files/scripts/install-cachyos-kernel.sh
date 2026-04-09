#!/usr/bin/env bash
set -oue pipefail

# Install CachyOS kernel packages without running RPM scriptlets in container
# build context, then generate module metadata/initramfs explicitly.
dnf -y install --setopt=install_weak_deps=False --setopt=tsflags=noscripts \
    kernel-cachyos \
    kernel-cachyos-devel

ver="$(ls /usr/lib/modules | sort -V | tail -n 1)"
if [[ -z "${ver}" ]]; then
    echo "ERROR: could not detect installed kernel version under /usr/lib/modules"
    exit 1
fi

depmod -a "${ver}"
dracut --kver "${ver}" --force --add ostree --no-hostonly --reproducible "/usr/lib/modules/${ver}/initramfs.img"


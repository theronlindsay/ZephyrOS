#!/usr/bin/env bash
set -oue pipefail

# Ensure temporary directories are writable for akmods/rpmbuild.
for d in /tmp /var/tmp; do
    mkdir -p "$d"
    chown root:root "$d"
    chmod 1777 "$d"
done
export TMPDIR=/var/tmp

# Install build helpers needed by akmods workflow.
dnf -y install --setopt=install_weak_deps=False \
    dnf-plugins-core \
    dnf5-plugins \
    akmods \
    kmodtool

# Use a single NVIDIA source for both userspace + akmod sources.
dnf -y install \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

dnf -y config-manager setopt rpmfusion-nonfree.enabled=1
dnf -y config-manager setopt rpmfusion-nonfree-updates.enabled=1

# Install complete NVIDIA stack from the same repository family.
dnf -y install --setopt=install_weak_deps=False --enablerepo=rpmfusion-nonfree --enablerepo=rpmfusion-nonfree-updates \
    akmod-nvidia \
    xorg-x11-drv-nvidia \
    xorg-x11-drv-nvidia-libs \
    xorg-x11-drv-nvidia-cuda \
    xorg-x11-drv-nvidia-kmodsrc \
    nvidia-kmod-common \
    nvidia-modprobe \
    nvidia-persistenced

# Build for newest installed kernel (CachyOS kernel comes from cachyos-kernel.sh).
mapfile -t module_dirs < <(find /lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -V)
if [ "${#module_dirs[@]}" -eq 0 ]; then
    echo "ERROR: Could not detect kernel version in /lib/modules"
    ls -l /lib/modules
    exit 1
fi
ver="${module_dirs[$((${#module_dirs[@]} - 1))]}"
echo "Detected kernel version: $ver"

akmods --force --kernels "$ver" --kmod nvidia

# akmods can report success while build failed, so verify explicitly.
if ! modinfo -k "$ver" nvidia >/dev/null 2>&1; then
    failed_log=$(find /var/cache/akmods/nvidia -maxdepth 1 -name "*for-${ver}.failed.log" | head -n 1 || true)
    if [ -n "$failed_log" ] && [ -f "$failed_log" ] && grep -q "runuser: cannot open session: Permission denied" "$failed_log"; then
        if ! command -v setpriv >/dev/null 2>&1; then
            echo "ERROR: setpriv is required for non-PAM akmodsbuild fallback"
            exit 1
        fi

        mkdir -p /tmp/akmods-results
        rm -f /tmp/akmods-results/*.rpm /tmp/akmodsbuild-root.log
        chown -R akmods:akmods /tmp/akmods-results
        touch /tmp/akmodsbuild-root.log
        chown akmods:akmods /tmp/akmodsbuild-root.log

        setpriv --reuid akmods --regid akmods --init-groups \
            env HOME=/tmp USER=akmods LOGNAME=akmods \
            akmodsbuild --kernels "$ver" --outputdir /tmp/akmods-results --logfile /tmp/akmodsbuild-root.log /usr/src/akmods/nvidia-kmod.latest

        mapfile -t built_rpms < <(find /tmp/akmods-results -type f -name '*.rpm' | grep -v debuginfo)
        if [ "${#built_rpms[@]}" -eq 0 ]; then
            echo "ERROR: akmodsbuild fallback produced no RPMs for kernel $ver"
            [ -f /tmp/akmodsbuild-root.log ] && cat /tmp/akmodsbuild-root.log
            exit 1
        fi

        dnf -y install --nogpgcheck --disablerepo='*' "${built_rpms[@]}"
    fi

    if ! modinfo -k "$ver" nvidia >/dev/null 2>&1; then
        echo "ERROR: nvidia module was not built for kernel $ver"
        [ -n "$failed_log" ] && [ -f "$failed_log" ] && cat "$failed_log"
        [ -f /tmp/akmodsbuild-root.log ] && cat /tmp/akmodsbuild-root.log
        exit 1
    fi
fi

depmod -a "$ver"
dracut --kver "$ver" --force --add ostree --no-hostonly --reproducible "/usr/lib/modules/$ver/initramfs.img"

# Keep RPMFusion disabled in resulting image to avoid unplanned future updates.
dnf -y config-manager setopt rpmfusion-nonfree.enabled=0
dnf -y config-manager setopt rpmfusion-nonfree-updates.enabled=0

#!/usr/bin/env bash
set -oue pipefail

# Ensure akmods/rpmbuild can always write temporary build artifacts.
# In some containerized builds these dirs can lose sticky-bit permissions.
for d in /tmp /var/tmp; do
    mkdir -p "$d"
    chown root:root "$d"
    chmod 1777 "$d"
done
export TMPDIR=/var/tmp

# Step 0: Ensure module build tools exist, but do not inject a second NVIDIA stack.
# The base image already provides the NVIDIA userspace set; pulling a different
# akmod stream with --nodeps can cause kmod/user-space skew.
dnf -y install --setopt=install_weak_deps=False akmods kmodtool

# Step 1: Ensure NVIDIA akmod sources are present.
# Avoid RPMFusion NVIDIA packages here because they can conflict with Bazzite's
# nvidia-driver-libs stack. Prefer the ublue-os/akmods COPR.
need_akmod_src=0
if [ ! -e /usr/src/akmods/nvidia-kmod.latest ]; then
    need_akmod_src=1
fi

if [ "$need_akmod_src" -eq 1 ]; then
    echo "NVIDIA akmod sources missing; trying ublue-os/akmods COPR first."
    dnf -y install --setopt=install_weak_deps=False dnf-plugins-core dnf5-plugins || true
    dnf -y copr enable ublue-os/akmods || true
    dnf -y install --setopt=install_weak_deps=False --skip-unavailable \
        akmod-nvidia \
        xorg-x11-drv-nvidia-kmodsrc \
        nvidia-kmod-common || true

    # If COPR packages are unavailable, fall back to RPMFusion source RPMs only.
    # We install only akmod sources with --nodeps/--noscripts to avoid replacing
    # the base image's NVIDIA userspace stack.
    if [ ! -e /usr/src/akmods/nvidia-kmod.latest ]; then
        echo "ublue-os/akmods did not provide nvidia akmod sources; falling back to RPMFusion source RPMs."
        dnf -y install \
            https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
            https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
        dnf -y config-manager setopt rpmfusion-nonfree.enabled=1
        dnf -y config-manager setopt rpmfusion-nonfree-updates.enabled=1

        rm -f /tmp/akmod-nvidia-*.rpm /tmp/xorg-x11-drv-nvidia-kmodsrc-*.rpm /tmp/nvidia-kmod-common-*.rpm
        cd /tmp
        dnf -y download --enablerepo=rpmfusion-nonfree-updates --enablerepo=rpmfusion-nonfree \
            akmod-nvidia xorg-x11-drv-nvidia-kmodsrc nvidia-kmod-common

        shopt -s nullglob
        akmod_rpms=(/tmp/akmod-nvidia-*.rpm)
        kmodsrc_rpms=(/tmp/xorg-x11-drv-nvidia-kmodsrc-*.rpm)
        common_rpms=(/tmp/nvidia-kmod-common-*.rpm)
        if [ "${#akmod_rpms[@]}" -eq 0 ] || [ "${#kmodsrc_rpms[@]}" -eq 0 ]; then
            echo "ERROR: Failed to download required NVIDIA source RPMs from RPMFusion"
            ls -1 /tmp/*nvidia*.rpm 2>/dev/null || true
            exit 1
        fi

        install_rpms=("${kmodsrc_rpms[@]}" "${akmod_rpms[@]}")
        if [ "${#common_rpms[@]}" -gt 0 ]; then
            install_rpms=("${common_rpms[@]}" "${install_rpms[@]}")
        else
            echo "WARNING: nvidia-kmod-common RPM not found in RPMFusion download; continuing with available source RPMs."
        fi

        rpm -Uvh --nodeps --noscripts "${install_rpms[@]}"
        shopt -u nullglob

        dnf -y config-manager setopt rpmfusion-nonfree.enabled=0
        dnf -y config-manager setopt rpmfusion-nonfree-updates.enabled=0
    fi
fi

if [ ! -e /usr/src/akmods/nvidia-kmod.latest ]; then
    echo "ERROR: /usr/src/akmods/nvidia-kmod.latest is missing after install attempt."
    echo "Available packages containing 'akmod' and 'nvidia':"
    dnf -q repoquery '*akmod*nvidia*' || true
    exit 1
fi

# Step 2: Determine the newest installed kernel version from /lib/modules.
mapfile -t module_dirs < <(find /lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -V)
if [ "${#module_dirs[@]}" -gt 0 ]; then
    VER="${module_dirs[$((${#module_dirs[@]} - 1))]}"
else
    VER=""
fi

echo "Detected Kernel Version: $VER"
echo "Building nvidia kmod for kernel $VER..."

# Ensure VER is not empty
if [ -z "$VER" ]; then
    echo "ERROR: Could not detect kernel version in /lib/modules!"
    ls -l /lib/modules
    exit 1
fi

# Step 3: Force akmods to build the NVIDIA kernel module for the detected CachyOS kernel.
akmods --force --kernels "$VER" --kmod nvidia

# akmods can print a failure and still return success, so verify module presence explicitly.
if ! modinfo -k "$VER" nvidia >/dev/null 2>&1; then
    failed_log=$(find /var/cache/akmods/nvidia -maxdepth 1 -name "*for-${VER}.failed.log" | head -n 1 || true)
    # In some container builders akmods fails when runuser cannot open a PAM session.
    # Fall back to direct akmodsbuild as user 'akmods' without PAM session setup.
    if [ -n "$failed_log" ] && [ -f "$failed_log" ] && grep -q "runuser: cannot open session: Permission denied" "$failed_log"; then
        echo "Detected runuser/PAM restriction while building akmods. Falling back to non-PAM akmodsbuild as user akmods."
        if ! command -v setpriv >/dev/null 2>&1; then
            echo "ERROR: setpriv is required for non-PAM akmodsbuild fallback but is not available."
            exit 1
        fi

        mkdir -p /tmp/akmods-results
        rm -f /tmp/akmods-results/*.rpm /tmp/akmodsbuild-root.log
        chown -R akmods:akmods /tmp/akmods-results
        touch /tmp/akmodsbuild-root.log
        chown akmods:akmods /tmp/akmodsbuild-root.log

        # akmodsbuild must run as a non-root user; setpriv avoids PAM/session requirements.
        setpriv --reuid akmods --regid akmods --init-groups \
            env HOME=/tmp USER=akmods LOGNAME=akmods \
            akmodsbuild --kernels "$VER" --outputdir /tmp/akmods-results --logfile /tmp/akmodsbuild-root.log /usr/src/akmods/nvidia-kmod.latest

        mapfile -t built_rpms < <(find /tmp/akmods-results -type f -name '*.rpm' | grep -v debuginfo)
        if [ "${#built_rpms[@]}" -eq 0 ]; then
            echo "ERROR: akmodsbuild fallback produced no RPMs for kernel $VER"
            [ -f /tmp/akmodsbuild-root.log ] && cat /tmp/akmodsbuild-root.log
            exit 1
        fi

        shopt -s nullglob
        fallback_common_rpms=(/tmp/nvidia-kmod-common-*.rpm)
        install_rpms=("${built_rpms[@]}")
        if ! rpm -q nvidia-kmod-common >/dev/null 2>&1 && [ "${#fallback_common_rpms[@]}" -gt 0 ]; then
            install_rpms=("${fallback_common_rpms[@]}" "${install_rpms[@]}")
        fi

        if ! dnf -y install --nogpgcheck --disablerepo='*' "${install_rpms[@]}"; then
            echo "WARNING: DNF could not resolve local kmod dependencies during fallback install."
            echo "Installed NVIDIA package versions:"
            rpm -q akmod-nvidia nvidia-kmod-common xorg-x11-drv-nvidia-kmodsrc || true
            echo "Built RPM requirements:"
            rpm -qpR "${install_rpms[@]}" || true

            # If nvidia-kmod-common cannot be satisfied in this build root,
            # still install the locally built kmod RPMs so the module exists
            # for the target kernel in the immutable image.
            if ! rpm -q nvidia-kmod-common >/dev/null 2>&1; then
                echo "nvidia-kmod-common missing; installing local kmod RPMs with rpm --nodeps"
                rpm -Uvh --nodeps "${built_rpms[@]}"
            else
                exit 1
            fi
        fi
        shopt -u nullglob
    fi

    # Re-check after fallback attempt.
    if modinfo -k "$VER" nvidia >/dev/null 2>&1; then
        echo "NVIDIA module build recovered via akmodsbuild fallback."
    else
        echo "ERROR: nvidia module was not built for kernel $VER"
        if [ -f /tmp/akmodsbuild-root.log ]; then
            echo "----- BEGIN /tmp/akmodsbuild-root.log -----"
            cat /tmp/akmodsbuild-root.log
            echo "----- END /tmp/akmodsbuild-root.log -----"
        fi
        if [ -n "$failed_log" ] && [ -f "$failed_log" ]; then
            echo "----- BEGIN $failed_log -----"
            cat "$failed_log"
            echo "----- END $failed_log -----"
        fi
        exit 1
    fi
fi

# Step 4: Update module dependencies (depmod) to register the newly built NVIDIA module.
# Then, regenerate the initramfs (dracut) to ensure the NVIDIA drivers are loaded early during boot.
depmod -a "$VER"
dracut --kver "$VER" --force --add ostree --no-hostonly --reproducible "/usr/lib/modules/$VER/initramfs.img"

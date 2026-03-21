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

# Step 0: Ensure the base module builder tools are installed.
# Bazzite sometimes removes 'akmods' from the final image, plus RPMfusion's nvidia 
# source needs 'kmodtool' to actually process the compilation.
dnf -y install --setopt=install_weak_deps=False akmods kmodtool

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
dnf -y download --enablerepo=rpmfusion-nonfree-updates --enablerepo=rpmfusion-nonfree nvidia-kmod-common || true

# Step 3: Force install the downloaded akmod RPMs while ignoring dependency checks.
# We also use --noscripts to prevent RPM from running the %post install scriptlet.
# The post-install script tries to background-build the module or hit OSTree hooks
# which fail inside an immutable Podman build container. We will build it manually anyway.
# Bazzite already has nvidia-kmod-common built-in.
shopt -s nullglob
akmod_rpms=(/tmp/akmod-nvidia-*.rpm)
kmodsrc_rpms=(/tmp/xorg-x11-drv-nvidia-kmodsrc-*.rpm)
kmod_common_rpms=(/tmp/nvidia-kmod-common-*.rpm)

if [ "${#akmod_rpms[@]}" -eq 0 ] || [ "${#kmodsrc_rpms[@]}" -eq 0 ]; then
    echo "ERROR: Required NVIDIA source RPMs were not downloaded to /tmp"
    ls -1 /tmp/*nvidia*.rpm 2>/dev/null || true
    exit 1
fi

base_rpms=("${akmod_rpms[@]}" "${kmodsrc_rpms[@]}")
if [ "${#kmod_common_rpms[@]}" -gt 0 ]; then
    base_rpms+=("${kmod_common_rpms[@]}")
else
    echo "WARNING: nvidia-kmod-common RPM was not downloaded; continuing with existing package set"
fi

rpm -Uvh --nodeps --noscripts "${base_rpms[@]}"
shopt -u nullglob

# Ensure nvidia-kmod-common exists for local kmod RPM dependency resolution.
if ! rpm -q nvidia-kmod-common >/dev/null 2>&1; then
    dnf -y install --setopt=install_weak_deps=False --enablerepo=rpmfusion-nonfree-updates --enablerepo=rpmfusion-nonfree nvidia-kmod-common || true
fi

# Step 4: Determine the newest installed kernel version from /lib/modules.
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

# Step 5: Force akmods to build the NVIDIA kernel module for the detected CachyOS kernel.
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
            echo "WARNING: DNF could not resolve local kmod dependencies; retrying with rpm --nodeps"
            rpm -Uvh --nodeps "${install_rpms[@]}"
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

# Step 6: Update module dependencies (depmod) to register the newly built NVIDIA module.
# Then, regenerate the initramfs (dracut) to ensure the NVIDIA drivers are loaded early during boot.
depmod -a "$VER"
dracut --kver "$VER" --force --add ostree --no-hostonly --reproducible "/usr/lib/modules/$VER/initramfs.img"

# Step 7: Clean up RPMs and disable RPMfusion so it doesn't try to auto-update on user systems.
rm -f /tmp/akmod-nvidia-*.rpm /tmp/xorg-x11-drv-nvidia-kmodsrc-*.rpm /tmp/nvidia-kmod-common-*.rpm
dnf -y config-manager setopt rpmfusion-nonfree.enabled=0
dnf -y config-manager setopt rpmfusion-nonfree-updates.enabled=0

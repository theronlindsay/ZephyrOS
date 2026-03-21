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

# Step 3: Force install the downloaded akmod RPMs while ignoring dependency checks.
# We also use --noscripts to prevent RPM from running the %post install scriptlet.
# The post-install script tries to background-build the module or hit OSTree hooks
# which fail inside an immutable Podman build container. We will build it manually anyway.
# Bazzite already has nvidia-kmod-common built-in.
rpm -ivh --nodeps --noscripts akmod-nvidia-*.rpm xorg-x11-drv-nvidia-kmodsrc-*.rpm

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
    # Fall back to direct akmodsbuild as root for image-build environments.
    if [ -n "$failed_log" ] && [ -f "$failed_log" ] && grep -q "runuser: cannot open session: Permission denied" "$failed_log"; then
        echo "Detected runuser/PAM restriction while building akmods. Falling back to root akmodsbuild."
        mkdir -p /tmp/akmods-results
        rm -f /tmp/akmods-results/*.rpm

        akmodsbuild --kernels "$VER" --outputdir /tmp/akmods-results --logfile /tmp/akmodsbuild-root.log /usr/src/akmods/nvidia-kmod.latest

        mapfile -t built_rpms < <(find /tmp/akmods-results -type f -name '*.rpm' | grep -v debuginfo)
        if [ "${#built_rpms[@]}" -eq 0 ]; then
            echo "ERROR: akmodsbuild fallback produced no RPMs for kernel $VER"
            [ -f /tmp/akmodsbuild-root.log ] && cat /tmp/akmodsbuild-root.log
            exit 1
        fi

        dnf -y install --nogpgcheck --disablerepo='*' "${built_rpms[@]}"
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
rm -f /tmp/akmod-nvidia-*.rpm /tmp/xorg-x11-drv-nvidia-kmodsrc-*.rpm
dnf -y config-manager setopt rpmfusion-nonfree.enabled=0
dnf -y config-manager setopt rpmfusion-nonfree-updates.enabled=0

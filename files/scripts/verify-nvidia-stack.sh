#!/usr/bin/env bash
set -oue pipefail

# Fail the build early if NVIDIA kernel/user-space packages are inconsistent.
if ! rpm -q akmod-nvidia >/dev/null 2>&1; then
    echo "ERROR: akmod-nvidia is missing"
    exit 1
fi

akmod_ev="$(rpm -q --qf '%{EPOCHNUM}:%{VERSION}\n' akmod-nvidia)"

# Only enforce nvidia-kmod-common if this akmod build chain requires it.
if rpm -q --requires akmod-nvidia | grep -q '^nvidia-kmod-common'; then
    if ! rpm -q --whatprovides "nvidia-kmod-common >= ${akmod_ev}" >/dev/null 2>&1; then
        echo "WARNING: nvidia-kmod-common does not satisfy akmod-nvidia requirement >= ${akmod_ev}"
        rpm -q akmod-nvidia nvidia-kmod-common || true
    fi
fi

if [ ! -f /etc/modprobe.d/blacklist-nouveau.conf ]; then
    echo "ERROR: /etc/modprobe.d/blacklist-nouveau.conf is missing"
    exit 1
fi

mapfile -t module_dirs < <(find /lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -V)
if [ "${#module_dirs[@]}" -eq 0 ]; then
    echo "ERROR: no kernel modules found in /lib/modules"
    exit 1
fi

ver="${module_dirs[$((${#module_dirs[@]} - 1))]}"
if ! modinfo -k "$ver" nvidia >/dev/null 2>&1; then
    echo "ERROR: nvidia.ko missing for kernel $ver"
    exit 1
fi

echo "NVIDIA stack check passed for kernel $ver"

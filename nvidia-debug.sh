echo "== HW ==" && lspci -nnk | grep -EA4 'VGA|3D|Display|NVIDIA'
echo "== Kernel ==" && uname -r
echo "== SecureBoot ==" && mokutil --sb-state 2>/dev/null || true

echo "== NVIDIA packages ==" 
rpm -qa | grep -Ei 'akmod-nvidia|kmod-nvidia|xorg-x11-drv-nvidia|nvidia-modprobe|nvidia-persistenced|nvidia-kmod-common' | sort

echo "== Module presence for running kernel =="
modinfo -k "$(uname -r)" nvidia >/dev/null && echo "nvidia.ko present" || echo "nvidia.ko MISSING"

echo "== Module load attempt =="
sudo modprobe nvidia && echo "modprobe OK" || echo "modprobe FAILED"

echo "== Loaded modules =="
lsmod | grep -E '^nvidia|nouveau' || true

echo "== Driver/runtime =="
nvidia-smi || true

echo "== Kernel logs (boot) =="
journalctl -k -b | grep -Ei 'nvidia|nouveau|nvrm|module verification|secure boot|taint' | tail -n 200
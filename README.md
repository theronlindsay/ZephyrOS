<p align="center">
  <img src="docs/ZephyrLogo.png" alt="ZephyrOS Logo" width="200"/>
</p>

<h1 align="center">ZephyrOS</h1>

<p align="center">
  <strong>The Breeze of Innovation</strong><br>
  A Fedora Atomic image built for developers, gamers, and everyone in between.
</p>

<p align="center">
  <a href="https://github.com/theronlindsay/zephyros/actions/workflows/build.yml">
    <img src="https://github.com/theronlindsay/zephyros/actions/workflows/build.yml/badge.svg" alt="Build Status"/>
  </a>
  <a href="https://github.com/theronlindsay/ZephyrOS/releases">
    <img src="https://img.shields.io/github/v/release/theronlindsay/ZephyrOS?label=Latest%20Release&color=14b8a6" alt="Latest Release"/>
  </a>
  <a href="https://github.com/theronlindsay/ZephyrOS/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/theronlindsay/ZephyrOS?color=14b8a6" alt="License"/>
  </a>
</p>

<p align="center">
  <a href="https://theronlindsay.github.io/ZephyrOS/">🌐 Website</a> •
  <a href="https://theronlindsay.github.io/ZephyrOS/download.html">⬇️ Download</a> •
  <a href="#-installation">📦 Install</a> •
  <a href="#-features">✨ Features</a>
</p>

---

## ⬇️ Download

Choose the right ISO for your hardware:

| Edition                           | Graphics  | Best For                                     | Download                                                    |
| --------------------------------- | --------- | -------------------------------------------- | ----------------------------------------------------------- |
| **ZephyrOS**                | AMD/Intel | Desktops                                     | [Download](https://github.com/theronlindsay/ZephyrOS/releases) |
| **ZephyrOS Console**        | AMD/Intel | HTPC, handhelds, and console-style gaming with Steam Big Picture | [Download](https://github.com/theronlindsay/ZephyrOS/releases) |
| **ZephyrOS Laptop**         | AMD/Intel | Laptops (sleep/hibernate fixes)              | [Download](https://github.com/theronlindsay/ZephyrOS/releases) |
| **ZephyrOS ASUS**           | AMD/Intel | ASUS ROG/TUF laptops                         | [Download](https://github.com/theronlindsay/ZephyrOS/releases) |
| **ZephyrOS NVIDIA**         | NVIDIA    | Desktops with NVIDIA GPUs                    | [Download](https://github.com/theronlindsay/ZephyrOS/releases) |
| **ZephyrOS NVIDIA Console** | NVIDIA    | HTPC/console-focused NVIDIA systems (experimental) | [Download](https://github.com/theronlindsay/ZephyrOS/releases) |
| **ZephyrOS NVIDIA Laptop**  | NVIDIA    | NVIDIA laptops (GPU switching + sleep fixes) | [Download](https://github.com/theronlindsay/ZephyrOS/releases) |
| **ZephyrOS NVIDIA ASUS**    | NVIDIA    | ASUS ROG/TUF gaming laptops                  | [Download](https://github.com/theronlindsay/ZephyrOS/releases) |

> 💡 **Not sure which to pick?** Use our [interactive download selector](https://theronlindsay.github.io/ZephyrOS/download.html)!
>
> ⚠️ **NVIDIA Console Warning:** `zephyros-nvidia-console` is experimental and currently has known bugs. Use the standard NVIDIA desktop/laptop editions if you need maximum stability.

---

## ✨ Features

### 🎮 Gaming Ready

- **Steam, Lutris, ProtonPlus** pre-installed
- **Console-focused images** include Steam Big Picture support
- **Sunshine** for game streaming
- **NVIDIA drivers** out of the box—no configuration needed

### 💻 Developer Focused

- **VS Code, Git, Brew** ready to go
- **Podman & DistroShelf** for container workflows
- **Godot & Unity Hub** for game development

### 🔧 Hardware Support

- **CachyOS Kernel**: Increased performance and up-to-date asus-armoury drivers
- **Console editions** use CachyOS kernel tuning for gaming responsiveness
- **Hybrid Graphics**: Intel/AMD + NVIDIA laptops just work
- **ASUS ROG/TUF**: Full support with asusctl & ROG Control Center
- **Fan profiles, RGB control, performance modes** out of the box

### 🛡️ Immutable & Reliable

- Built on **Fedora Atomic** (Bazzite base)
- **Automatic updates** with rollback support
- **No telemetry**, privacy-first

## NVIDIA Troubleshooting

### Known Issues: NVIDIA Console Image

`zephyros-nvidia-console` is experimental and may have bugs related to game-mode/TV workflows and NVIDIA-specific behavior. If you hit issues, switch to `zephyros-nvidia` or `zephyros-nvidia-laptop` until fixes land.

If the NVIDIA card is missing from `lspci` on a laptop image, the dGPU is usually power-gated by firmware/MUX mode instead of failing driver load.

1. In BIOS/UEFI or Armoury Crate, switch graphics mode from `iGPU/Eco` to `Hybrid` or `Standard`, then reboot.
2. On ZephyrOS NVIDIA Laptop, run `sudo envycontrol -s hybrid` and reboot.
3. On ZephyrOS NVIDIA ASUS, verify the mode with `asusctl armoury list` and set Hybrid with `sudo asus-gpu-mode hybrid`, then reboot.
4. Re-check with `lspci | grep -Ei 'vga|3d|nvidia'` and `nvidia-smi`.

If `lspci` still does not list NVIDIA after step 1, the device is still disabled at firmware level.

---

## 📦 Installation

### Option 1: Fresh Install (Recommended)

1. [Download the ISO](https://theronlindsay.github.io/ZephyrOS/download.html) for your hardware
2. Flash to USB with [Fedora Media Writer](https://flathub.org/apps/org.fedoraproject.MediaWriter) or [Balena Etcher](https://etcher.balena.io/)
3. Boot and install!

### Option 2: Rebase from Bazzite or Fedora Atomic

Already running Bazzite, Bluefin, Aurora, or another Fedora Atomic distro? You can rebase directly!

> ⚠️ **Warning**: This is an experimental feature. Back up important data first.

**Step 1:** Rebase to the unsigned image (to install signing keys):

```bash
# Replace IMAGE_NAME with your choice:
# zephyros, zephyros-console, zephyros-laptop,
# zephyros-asus, zephyros-nvidia, zephyros-nvidia-console,
# zephyros-nvidia-laptop, zephyros-nvidia-asus

sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/theronlindsay/IMAGE_NAME:latest
```

**Step 2:** Reboot:

```bash
systemctl reboot
```

**Step 3:** Rebase to the signed image:

```bash
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/theronlindsay/IMAGE_NAME:latest
```

**Step 4:** Reboot again:

```bash
systemctl reboot
```

<details>
<summary>📋 <strong>Quick Copy Commands</strong> (click to expand)</summary>

**ZephyrOS (AMD/Intel Desktop)**

```bash
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/theronlindsay/zephyros:latest
# reboot, then:
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/theronlindsay/zephyros:latest
```

**ZephyrOS Laptop (AMD/Intel)**

```bash
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/theronlindsay/zephyros-laptop:latest
# reboot, then:
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/theronlindsay/zephyros-laptop:latest
```

**ZephyrOS Console (AMD/Intel)**

```bash
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/theronlindsay/zephyros-console:latest
# reboot, then:
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/theronlindsay/zephyros-console:latest
```

**ZephyrOS ASUS**

```bash
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/theronlindsay/zephyros-asus:latest
# reboot, then:
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/theronlindsay/zephyros-asus:latest
```

**ZephyrOS NVIDIA (Desktop)**

```bash
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/theronlindsay/zephyros-nvidia:latest
# reboot, then:
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/theronlindsay/zephyros-nvidia:latest
```

**ZephyrOS NVIDIA Laptop**

```bash
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/theronlindsay/zephyros-nvidia-laptop:latest
# reboot, then:
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/theronlindsay/zephyros-nvidia-laptop:latest
```

**ZephyrOS NVIDIA Console (Experimental)**

```bash
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/theronlindsay/zephyros-nvidia-console:latest
# reboot, then:
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/theronlindsay/zephyros-nvidia-console:latest
```

**ZephyrOS NVIDIA ASUS**

```bash
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/theronlindsay/zephyros-nvidia-asus:latest
# reboot, then:
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/theronlindsay/zephyros-nvidia-asus:latest
```

</details>

---

## 🔐 Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). Verify the signature:

```bash
cosign verify --key cosign.pub ghcr.io/theronlindsay/zephyros
```

---

## 🛠️ Building Your Own ISO

Want to customize or build locally?

**Install BlueBuild CLI:**

```bash
bash <(curl -s https://raw.githubusercontent.com/blue-build/cli/main/install.sh)
```

**Generate an ISO:**

```bash
bluebuild generate-iso --iso-name ZephyrOS.iso recipe recipes/zephyros.yml
```

**Generate an ISO from repo:**

```bash
bluebuild generate-iso --iso-name ZephyrOS.iso image ghcr.io/theronlindsay/zephyros
```


See the [BlueBuild docs](https://blue-build.org/how-to/setup/) for more information.

---

## 📄 License

This project is open source under the [Apache 2.0 License](LICENSE).

---

<p align="center">
  Made with ❤️ by Theron Lindsay. <a href="https://theronlindsay.github.io/ZephyrOS/">Visit my website</a> for more info and support!
</p>

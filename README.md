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

| Edition | Graphics | Best For | Download |
|---------|----------|----------|----------|
| **ZephyrOS** | AMD/Intel | Standard desktops & laptops | [Download](https://github.com/theronlindsay/ZephyrOS/releases) |
| **ZephyrOS NVIDIA** | NVIDIA | Desktops with NVIDIA GPUs | [Download](https://github.com/theronlindsay/ZephyrOS/releases) |
| **ZephyrOS NVIDIA Hybrid** | Intel/AMD + NVIDIA | Laptops with hybrid graphics | [Download](https://github.com/theronlindsay/ZephyrOS/releases) |
| **ZephyrOS ASUS** | AMD/Intel | ASUS ROG/TUF laptops | [Download](https://github.com/theronlindsay/ZephyrOS/releases) |
| **ZephyrOS NVIDIA ASUS** | NVIDIA | ASUS ROG/TUF gaming laptops | [Download](https://github.com/theronlindsay/ZephyrOS/releases) |
| **ZephyrOS Console** | AMD/Intel | Steam Big Picture mode | [Download](https://github.com/theronlindsay/ZephyrOS/releases) |
| **ZephyrOS NVIDIA Console** | NVIDIA | Steam Big Picture + NVIDIA | [Download](https://github.com/theronlindsay/ZephyrOS/releases) |

> 💡 **Not sure which to pick?** Use our [interactive download selector](https://theronlindsay.github.io/ZephyrOS/download.html)!

---

## ✨ Features

### 🎮 Gaming Ready
- **Steam, Lutris, ProtonPlus** pre-installed
- **Sunshine** for game streaming
- **NVIDIA drivers** out of the box—no configuration needed
- **Console editions** boot directly into Steam Big Picture

### 💻 Developer Focused
- **VS Code, Git, Brew** ready to go
- **Podman & DistroShelf** for container workflows
- **Godot & Unity Hub** for game development
- **ddterm** drop-down terminal

### 🔧 Hardware Support
- **Hybrid Graphics**: Intel/AMD + NVIDIA laptops just work
- **ASUS ROG/TUF**: Full support with asusctl & ROG Control Center
- **Fan profiles, RGB control, performance modes** out of the box

### 🛡️ Immutable & Reliable
- Built on **Fedora Atomic** (Bazzite base)
- **Automatic updates** with rollback support
- **No telemetry**, privacy-first

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
# zephyros, zephyros-nvidia, zephyros-nvidia-hybrid, 
# zephyros-asus, zephyros-nvidia-asus,
# zephyros-console, zephyros-nvidia-console

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

**ZephyrOS (AMD/Intel)**
```bash
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/theronlindsay/zephyros:latest
# reboot, then:
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/theronlindsay/zephyros:latest
```

**ZephyrOS NVIDIA**
```bash
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/theronlindsay/zephyros-nvidia:latest
# reboot, then:
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/theronlindsay/zephyros-nvidia:latest
```

**ZephyrOS NVIDIA Hybrid**
```bash
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/theronlindsay/zephyros-nvidia-hybrid:latest
# reboot, then:
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/theronlindsay/zephyros-nvidia-hybrid:latest
```

**ZephyrOS ASUS**
```bash
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/theronlindsay/zephyros-asus:latest
# reboot, then:
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/theronlindsay/zephyros-asus:latest
```

**ZephyrOS NVIDIA ASUS**
```bash
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/theronlindsay/zephyros-nvidia-asus:latest
# reboot, then:
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/theronlindsay/zephyros-nvidia-asus:latest
```

**ZephyrOS Console**
```bash
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/theronlindsay/zephyros-console:latest
# reboot, then:
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/theronlindsay/zephyros-console:latest
```

**ZephyrOS NVIDIA Console**
```bash
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/theronlindsay/zephyros-nvidia-console:latest
# reboot, then:
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/theronlindsay/zephyros-nvidia-console:latest
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
sudo bluebuild generate-iso --iso-name ZephyrOS.iso recipes/zephyros.yml
```

See the [BlueBuild docs](https://blue-build.org/how-to/setup/) for more information.

---

## 📄 License

This project is open source under the [Apache 2.0 License](LICENSE).

---

<p align="center">
  Made with ❤️ by the ZephyrOS community
</p>

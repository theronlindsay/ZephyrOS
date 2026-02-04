# ZephyrOS &nbsp; [![bluebuild build badge](https://github.com/theronlindsay/zephyros/actions/workflows/build.yml/badge.svg)](https://github.com/theronlindsay/zephyros/actions/workflows/build.yml)

A Fedora Atomic Image of Bazzite-dx optimized for Asus Laptops with Hybrid Graphics

## Primary Features:

* [ ] Fan control

  * [ ] Asusctl and Rog Control Center preinstalled
* [ ] Hibernation On Lid Close

  * [ ] Saves Idle battery life
  * [ ] Works with Full-Disk Encryption Enabled
  * [ ] Z-Ram Disabled
* [ ] GPU Switching

  * [ ] EnvyControl preinstalled
  * [ ] GPU Profile Switcher inside the Gnome Control Center
* [ ] Dash to Panel Installed by Default for Windows-Like UI ootb
* [ ] Zen-browser as default

## Creating Images:

Download BlueBuild:

`bash <(curl -s https://raw.githubusercontent.com/blue-build/cli/main/install.sh)`

Create an Image:

`sudo bluebuild generate-iso --iso-name ZephyrOS-nvidia-gnome.iso recipe recipes/zephyros-nvidia-gnome.yml`

## Installation (Rebasing another Fedora-Atomic Distro)

> [!WARNING]
> [This is an experimental feature](https://www.fedoraproject.org/wiki/Changes/OstreeNativeContainerStable), try at your own discretion.

To rebase an existing atomic Fedora installation to the latest build:

- First rebase to the unsigned image, to get the proper signing keys and policies installed:

  ```
  sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/theronlindsay/zephyros-nvidia-gnome:latestspan
  ```
- Reboot to complete the rebase:

  ```
  systemctl reboot
  ```
- Then rebase to the signed image, like so:

  ```
  sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/theronlindsay/zephyros-nvidia-gnome:latest
  ```
- Reboot again to complete the installation

  ```
  systemctl reboot
  ```

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/theronlindsay/zephyros
```

See the [BlueBuild docs](https://blue-build.org/how-to/setup/) for quick setup instructions for setting up your own repository based on this template.

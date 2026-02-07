# ZephyrOS Copilot Instructions

## Project Overview

ZephyrOS is a **BlueBuild**-based Fedora Atomic image derived from Bazzite-dx, optimized for Asus laptops with hybrid graphics. It uses an immutable OS model where system changes are defined declaratively in YAML recipes.

## Architecture

### Image Hierarchy (Build Order)
Images build on each other in layers:
```
bazzite-dx-gnome → zephyros → zephyros-asus
bazzite-dx-nvidia-gnome → zephyros-nvidia → zephyros-nvidia-hybrid → zephyros-nvidia-asus
```

### Key Directories
- **[recipes/](recipes/)** - BlueBuild YAML recipes defining image variants
- **[files/system/](files/system/)** - Files copied to `/` in the built image (mirrors filesystem structure)
- **[files/scripts/](files/scripts/)** - Build-time scripts executed during image creation
- **[files/justfile](files/justfile)** - User-facing `just` commands installed to `/usr/share/ublue-os/just/60-custom.just`
- **modules/** - Custom BlueBuild modules (currently empty, uses built-in modules)

## Recipe Structure

Recipes in [recipes/](recipes/) follow BlueBuild schema. Module execution order matters:
1. `files` - Copy system files first
2. `rpm-ostree` / `dnf` - Package management
3. `default-flatpaks` - Flatpak installations (uses custom repo `repo.zephyros.buzz`)
4. `gnome-extensions` - GNOME Shell extensions by name
5. `script` - Build scripts from [files/scripts/](files/scripts/)
6. `signing` - Always last, sets up image signing

### Adding a New Image Variant
1. Create recipe in `recipes/zephyros-<variant>.yml`
2. Set `base-image` to an upstream image or existing ZephyrOS image
3. Add recipe to [.github/workflows/build.yml](.github/workflows/build.yml) matrix

## Build Commands

```bash
# Install BlueBuild CLI
bash <(curl -s https://raw.githubusercontent.com/blue-build/cli/main/install.sh)

# Build ISO from recipe
sudo bluebuild generate-iso --iso-name ZephyrOS-nvidia-gnome.iso recipe recipes/zephyros-nvidia.yml
```

## File Conventions

### System Files (`files/system/`)
Files mirror the target filesystem structure. Example:
- `files/system/etc/systemd/sleep.conf` → `/etc/systemd/sleep.conf`
- `files/system/usr/local/sbin/setupHibernate.sh` → `/usr/local/sbin/setupHibernate.sh`

### Build Scripts (`files/scripts/`)
- Must start with `#!/usr/bin/env bash` and `set -oue pipefail`
- Run as root during build, not at user runtime
- Reference scripts by filename in recipe `script` module

### User Defaults (`files/system/etc/skel/`)
Files placed here become user defaults. GNOME settings use dconf dumps:
- `etc/skel/.config/dconf/extensions.dconf` - Extension settings
- `etc/skel/.config/dconf/shell-settings.dconf` - Shell settings

## Custom Flatpak Repository

ZephyrOS uses a custom Flatpak repo at `https://repo.zephyros.buzz` for apps like `buzz.zephyros.hello`. Add custom apps to this repo, then reference in recipes under `default-flatpaks`.

## Hardware-Specific Features

- **ASUS laptops**: `asusctl` and ROG Control Center via `lukenukem/asus-linux` COPR
- **Hybrid graphics**: `envycontrol` via `sunwire/envycontrol` COPR + GPU Profile Selector extension
- **Hibernation**: Configured via [setupHibernate.sh](files/system/usr/local/sbin/setupHibernate.sh), uses btrfs swapfile with RAM+4GB size

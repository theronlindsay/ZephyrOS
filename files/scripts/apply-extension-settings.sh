#!/usr/bin/env bash

# Apply GNOME extension settings from dconf
dconf load /org/gnome/shell/extensions/ < /etc/skel/.config/dconf/extensions.dconf || true

# Apply GNOME shell settings (includes enabled-extensions list)
dconf load /org/gnome/shell/ < /etc/skel/.config/dconf/shell-settings.dconf || true

# Apply custom keybindings (Alt+Space for Vicinae)
dconf load /org/gnome/settings-daemon/plugins/media-keys/ < /etc/skel/.config/dconf/keybindings.dconf || true

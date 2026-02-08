#!/usr/bin/env bash
set -euo pipefail

# apply-extension-settings.sh
# During image builds there is no X11/DBUS session; `dconf load`/`gsettings`
# will try to autolaunch D-Bus and fail. In non-interactive builds we
# install system dconf overrides under /etc/dconf/db/local.d/ and run
# `dconf update` so the settings are available without a session bus.

SKEL_CONF_DIR=/etc/skel/.config/dconf
LOCAL_DB_DIR=/etc/dconf/db/local.d
mkdir -p "$LOCAL_DB_DIR"

# If running as non-root and we have a session (DISPLAY or DBUS_SESSION_BUS_ADDRESS), use dconf load
# During Blue-build image module execution scripts run as root; prefer non-interactive path.
if [[ "$(id -u)" -ne 0 && ( -n "${DISPLAY-:-}" || -n "${DBUS_SESSION_BUS_ADDRESS-:-}" ) ]]; then
	dconf load /org/gnome/shell/extensions/ < "$SKEL_CONF_DIR/extensions.dconf" || true
	dconf load /org/gnome/shell/ < "$SKEL_CONF_DIR/shell-settings.dconf" || true
	dconf load /org/gnome/settings-daemon/plugins/media-keys/ < "$SKEL_CONF_DIR/keybindings.dconf" || true
	exit 0
fi

# Non-interactive: install system-wide dconf overrides.
# 1) Shell settings (root /) -> map to [org/gnome/shell]
if [[ -f "$SKEL_CONF_DIR/shell-settings.dconf" ]]; then
	grep -E "^(disabled-extensions|enabled-extensions|favorite-apps|last-selected-power-profile)=" "$SKEL_CONF_DIR/shell-settings.dconf" > /tmp/zz-shell-keys || true
	if [[ -s /tmp/zz-shell-keys ]]; then
		{
			echo "[org/gnome/shell]"
			sed -n 's/^[[:space:]]*//;p' /tmp/zz-shell-keys
		} > "$LOCAL_DB_DIR/00-zephyros-shell"
		dconf update || true
		rm -f /tmp/zz-shell-keys
	fi
fi

# 2) Extensions-specific settings: transform section headers to
#    org/gnome/shell/extensions/<section>
if [[ -f "$SKEL_CONF_DIR/extensions.dconf" ]]; then
	awk '/^\[/{gsub(/^\[|\]$/,"",$0); section=$0; print "[org/gnome/shell/extensions/" section "]"; next} {print}' "$SKEL_CONF_DIR/extensions.dconf" > "$LOCAL_DB_DIR/00-zephyros-extensions"
	dconf update || true
fi

# 3) Keybindings: map root header to org/gnome/settings-daemon/plugins/media-keys
if [[ -f "$SKEL_CONF_DIR/keybindings.dconf" ]]; then
	awk '/^\[/{gsub(/^\[|\]$/,"",$0); section=$0; if(section=="/") {print "[org/gnome/settings-daemon/plugins/media-keys]"} else {print "[" section "]"}; next} {print}' "$SKEL_CONF_DIR/keybindings.dconf" > "$LOCAL_DB_DIR/00-zephyros-keys"
	dconf update || true
fi

exit 0

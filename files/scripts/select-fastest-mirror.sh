#!/usr/bin/env bash
set -oue pipefail

# This script updates Fedora mirrors to use the fastest available
# Requires: dnf-plugins-core (for 'dnf config-manager')

log() { echo "[mirror-select] $1"; }

# Install dnf-plugins-core if not present
if ! command -v dnf &>/dev/null; then
  log "dnf not found, skipping mirror selection."
  exit 0
fi
if ! rpm -q dnf-plugins-core &>/dev/null; then
  log "Installing dnf-plugins-core..."
  dnf install -y dnf-plugins-core
fi

log "Enabling fastestmirror in dnf.conf..."
sed -i '/^fastestmirror/d' /etc/dnf/dnf.conf
printf '\nfastestmirror=1\n' >> /etc/dnf/dnf.conf

log "Mirror selection complete."

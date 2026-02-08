#!/usr/bin/env bash
set -oue pipefail
if [ ! -s /etc/machine-id ]; then
  systemd-machine-id-setup
fi

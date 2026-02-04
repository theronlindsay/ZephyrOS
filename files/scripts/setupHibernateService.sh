#!/usr/bin/env bash

# Tell this script to exit if there are any errors.
# You should have this in every custom script, to ensure that your completed
# builds actually ran successfully without any errors!
set -oue pipefail

mkdir -p /etc/systemd/system/multi-user.target.wants
ln -sf /etc/systemd/system/setup-hibernate.service /etc/systemd/system/multi-user.target.wants/setup-hibernate.service
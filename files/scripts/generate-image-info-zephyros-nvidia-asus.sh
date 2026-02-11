#!/usr/bin/env bash
set -euo pipefail

# Wrapper for zephyros-nvidia-asus recipe
IMAGE_NAME=zephyros-nvidia-asus \
IMAGE_VENDOR=theronlindsay \
IMAGE_REF="ostree-image-signed:docker://ghcr.io/theronlindsay/zephyros-nvidia-asus" \
FEDORA_VERSION=43 \
./generate-image-info.sh

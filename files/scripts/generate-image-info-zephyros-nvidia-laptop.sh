#!/usr/bin/env bash
set -euo pipefail

# Wrapper for zephyros-nvidia-laptop recipe
IMAGE_NAME=zephyros-nvidia-laptop \
IMAGE_VENDOR=theronlindsay \
IMAGE_REF="ostree-image-signed:docker://ghcr.io/theronlindsay/zephyros-nvidia-laptop" \
FEDORA_VERSION=43 \
./generate-image-info.sh

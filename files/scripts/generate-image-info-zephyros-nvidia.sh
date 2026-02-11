#!/usr/bin/env bash
set -euo pipefail

# Wrapper for zephyros-nvidia recipe
IMAGE_NAME=zephyros-nvidia \
IMAGE_VENDOR=theronlindsay \
IMAGE_REF="ostree-image-signed:docker://ghcr.io/theronlindsay/zephyros-nvidia" \
FEDORA_VERSION=43 \
./generate-image-info.sh

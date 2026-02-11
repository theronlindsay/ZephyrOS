#!/usr/bin/env bash
set -euo pipefail

# Wrapper for zephyros-nvidia-console recipe
IMAGE_NAME=zephyros-nvidia-console \
IMAGE_VENDOR=theronlindsay \
IMAGE_REF="ostree-image-signed:docker://ghcr.io/theronlindsay/zephyros-nvidia-console" \
FEDORA_VERSION=43 \
./generate-image-info.sh

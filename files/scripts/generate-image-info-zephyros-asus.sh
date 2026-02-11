#!/usr/bin/env bash
set -euo pipefail

# Wrapper for zephyros-asus recipe
IMAGE_NAME=zephyros-asus \
IMAGE_VENDOR=theronlindsay \
IMAGE_REF="ostree-image-signed:docker://ghcr.io/theronlindsay/zephyros-asus" \
FEDORA_VERSION=43 \
./generate-image-info.sh

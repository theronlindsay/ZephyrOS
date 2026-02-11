#!/usr/bin/env bash
set -euo pipefail

# Wrapper for zephyros-laptop recipe
IMAGE_NAME=zephyros-laptop \
IMAGE_VENDOR=theronlindsay \
IMAGE_REF="ostree-image-signed:docker://ghcr.io/theronlindsay/zephyros-laptop" \
FEDORA_VERSION=43 \
./generate-image-info.sh
